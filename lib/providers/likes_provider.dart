import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:romanticists_app/providers/auth_provider.dart';
import 'package:romanticists_app/services/engagement_service.dart';

enum LikesStatus { initial, loading, loaded, failure }

/// Manages the user's liked post IDs.
class LikesProvider extends ChangeNotifier {
  LikesProvider(this._auth) {
    _auth.addListener(_onAuthChanged);
    _onAuthChanged();
  }

  final AuthProvider _auth;
  Set<String> _ids = {};
  LikesStatus _status = LikesStatus.initial;

  Set<String> get likedIds => Set.unmodifiable(_ids);
  LikesStatus get status => _status;
  bool isLiked(String postId) => _ids.contains(postId);

  void _onAuthChanged() {
    final uid = _auth.user?.uid;
    if (uid != null) {
      load(uid);
    } else {
      _ids = {};
      _status = LikesStatus.initial;
      notifyListeners();
    }
  }

  static const String _cacheKey = 'liked_post_ids_cache';

  Future<void> load(String uid) async {
    // 1. Load from local cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList('${_cacheKey}_$uid');
      if (cached != null) {
        _ids = cached.toSet();
        _status = LikesStatus.loaded;
        notifyListeners();
      }
    } catch (_) {}

    // 2. Fetch fresh from Firestore
    try {
      final fresh = await EngagementService.instance.getLikedPostIds(uid);
      _ids = fresh;
      _status = LikesStatus.loaded;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('${_cacheKey}_$uid', _ids.toList());
    } catch (e) {
      debugPrint('Error loading likes: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> toggleLike({
    required String postId,
    String? authorUid,
    required bool currentLikedState,
  }) async {
    final uid = _auth.user?.uid;
    if (uid == null) return;

    final wasLiked = _ids.contains(postId);
    
    // Optimistic update
    if (wasLiked) {
      _ids.remove(postId);
    } else {
      _ids.add(postId);
    }
    notifyListeners();

    try {
      if (wasLiked) {
        await EngagementService.instance.unlikePost(uid, postId);
      } else {
        await EngagementService.instance.likePost(uid, postId, authorUid);
      }
      
      // Update cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('${_cacheKey}_$uid', _ids.toList());
    } catch (e) {
      // Revert on error
      if (wasLiked) {
        _ids.add(postId);
      } else {
        _ids.remove(postId);
      }
      notifyListeners();
    }
  }
}
