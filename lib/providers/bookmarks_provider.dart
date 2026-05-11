import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:romanticists_app/models/feed_item.dart';
import 'package:romanticists_app/providers/auth_provider.dart';
import 'package:romanticists_app/services/firebase_service.dart';

enum BookmarksStatus { initial, loading, loaded, failure }

/// Manages the user's saved posts.
///
/// Call [load] once the user signs in, [clear] on sign-out.
/// [toggle] provides optimistic UI — it flips state immediately and
/// reverts silently if the Firestore write fails.
class BookmarksProvider extends ChangeNotifier {
  BookmarksProvider(this._auth) {
    _auth.addListener(_onAuthChanged);
    // FIX 6: Handle the case where the user is already logged in
    _onAuthChanged();
  }

  final AuthProvider _auth;

  Set<String> _ids = {};
  List<FeedItem> _items = [];
  BookmarksStatus _status = BookmarksStatus.initial;
  String? _errorMessage;

  Set<String> get bookmarkedIds => Set.unmodifiable(_ids);
  List<FeedItem> get items => List.unmodifiable(_items);
  BookmarksStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool isBookmarked(String postId) => _ids.contains(postId);

  // ─── Auth listener ─────────────────────────────────────────────────────────

  void _onAuthChanged() {
    final uid = _auth.user?.uid;
    if (uid != null) {
      load(uid);
    } else {
      clear();
    }
  }

  // ─── Load ──────────────────────────────────────────────────────────────────

  static const String _cachePrefix = 'bookmarks_cache_';

  Future<void> load(String uid) async {
    final cacheKey = '$_cachePrefix$uid';
    
    // ── STEP 1: Load from local cache immediately ──
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson != null) {
        final List<dynamic> list = jsonDecode(cachedJson);
        _items = list.map((item) => FeedItem.fromJson(item as Map<String, dynamic>)).toList();
        _ids = _items.map((i) => i.uniqueId).toSet();
        _status = BookmarksStatus.loaded;
        notifyListeners(); // Render UI instantly
      } else if (_items.isEmpty) {
        _status = BookmarksStatus.loading;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Bookmarks cache error: $e');
    }

    // ── STEP 2: Silently fetch fresh data from Firebase ──
    try {
      final results = await FirebaseService.instance.getBookmarkedFeedItems(uid);
      
      // Update state only if data has changed or was empty
      _items = results;
      _ids = results.map((i) => i.uniqueId).toSet();
      _status = BookmarksStatus.loaded;
      _errorMessage = null;

      // Update local cache for next time
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_items.map((i) => i.toJson()).toList());
      await prefs.setString(cacheKey, encoded);

    } on FirebaseServiceException catch (e) {
      if (_items.isEmpty) {
        _status = BookmarksStatus.failure;
        _errorMessage = e.message;
      }
    } catch (e) {
      if (_items.isEmpty) {
        _status = BookmarksStatus.failure;
        _errorMessage = 'Could not load bookmarks.';
      }
    } finally {
      notifyListeners();
    }
  }

  // ─── Toggle (optimistic) ───────────────────────────────────────────────────

  Future<void> toggle({
    required String id,
    required String title,
    required String excerpt,
    required String? imageUrl,
    required String author,
    String authorFirebaseId = '',
    required DateTime publishedAt,
    List<int> categories = const [],
    String slug = '',
    String link = '',
  }) async {
    final uid = _auth.user?.uid;
    if (uid == null) return; // must be signed in

    final wasBookmarked = _ids.contains(id);

    // ── Optimistic update ──
    if (wasBookmarked) {
      _ids.remove(id);
      _items.removeWhere((i) => i.uniqueId == id);
    } else {
      _ids.add(id);
      // We could add a skeleton FeedItem here if we wanted to be truly optimistic
    }
    notifyListeners();

    // ── Firestore write ──
    try {
      await FirebaseService.instance.toggleBookmark(
        uid,
        id: id,
        title: title,
        excerpt: excerpt,
        imageUrl: imageUrl,
        author: author,
        authorFirebaseId: authorFirebaseId,
        publishedAt: publishedAt,
        categories: categories,
        slug: slug,
        link: link,
      );
    } catch (_) {
      // Revert on failure
      if (wasBookmarked) {
        _ids.add(id);
      } else {
        _ids.remove(id);
        _items.removeWhere((i) => i.uniqueId == id);
      }
      notifyListeners();
    }
  }

  // ─── Clear (on sign-out) ───────────────────────────────────────────────────

  void clear() {
    _ids = {};
    _items = [];
    _status = BookmarksStatus.initial;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
