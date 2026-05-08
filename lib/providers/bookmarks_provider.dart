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

  Set<int> _ids = {};
  List<Post> _posts = [];
  BookmarksStatus _status = BookmarksStatus.initial;
  String? _errorMessage;

  Set<int> get bookmarkedIds => Set.unmodifiable(_ids);
  List<Post> get posts => List.unmodifiable(_posts);
  BookmarksStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool isBookmarked(int postId) => _ids.contains(postId);

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
      final result = await FirebaseService.instance.getBookmarkedPosts(uid);
      _posts = result;
      _ids = result.map((p) => p.id).toSet();
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

  Future<void> toggle(Post post) async {
    final uid = _auth.user?.uid;
    if (uid == null) return; // must be signed in

    final wasBookmarked = _ids.contains(post.id);

    // ── Optimistic update ──
    if (wasBookmarked) {
      _ids.remove(post.id);
      _posts.removeWhere((p) => p.id == post.id);
    } else {
      _ids.add(post.id);
      _posts.insert(0, post);
    }
    notifyListeners();

    // ── Firestore write ──
    try {
      await FirebaseService.instance.toggleBookmark(uid, post);
    } catch (_) {
      // Revert on failure
      if (wasBookmarked) {
        _ids.add(post.id);
        _posts.insert(0, post);
      } else {
        _ids.remove(post.id);
        _posts.removeWhere((p) => p.id == post.id);
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
