import 'package:flutter/foundation.dart';
import 'package:romanticists_app/models/post.dart';
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
    // Auto-load when auth state resolves.
    _auth.addListener(_onAuthChanged);
  }

  final AuthProvider _auth;

  Set<String> _ids = {};
  List<Post> _posts = []; // TODO: Unify with Submissions
  BookmarksStatus _status = BookmarksStatus.initial;
  String? _errorMessage;

  Set<String> get bookmarkedIds => Set.unmodifiable(_ids);
  List<Post> get posts => List.unmodifiable(_posts);
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

  Future<void> load(String uid) async {
    _status = BookmarksStatus.loading;
    notifyListeners();
    try {
      // For now, only loads WP bookmarks. Community bookmarks are handled by ID.
      final result = await FirebaseService.instance.getBookmarkedPosts(uid);
      _posts = result;
      _ids = result.map((p) => p.id.toString()).toSet();
      
      // Also fetch any other community bookmark IDs
      final bookmarks = await FirebaseService.instance.getBookmarks(uid);
      for (var b in bookmarks) {
        final id = b['postId']?.toString();
        if (id != null) _ids.add(id);
      }

      _status = BookmarksStatus.loaded;
      _errorMessage = null;
    } on FirebaseServiceException catch (e) {
      _status = BookmarksStatus.failure;
      _errorMessage = e.message;
    } catch (e) {
      _status = BookmarksStatus.failure;
      _errorMessage = 'Could not load bookmarks.';
    }
    notifyListeners();
  }

  // ─── Toggle (optimistic) ───────────────────────────────────────────────────

  Future<void> toggle({
    required String id,
    required String title,
    required String excerpt,
    required String? imageUrl,
    required String author,
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
      _posts.removeWhere((p) => p.id.toString() == id);
    } else {
      _ids.add(id);
      // We don't add to _posts here because _posts is specifically List<Post>
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
        _posts.removeWhere((p) => p.id.toString() == id);
      }
      notifyListeners();
    }
  }

  // ─── Clear (on sign-out) ───────────────────────────────────────────────────

  void clear() {
    _ids = {};
    _posts = [];
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
