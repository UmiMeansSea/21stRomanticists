import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:romanticists_app/models/comment.dart';
import 'package:romanticists_app/services/firebase_service.dart';

class EngagementService {
  EngagementService._();
  static final EngagementService instance = EngagementService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  static const String _submissionsCol = 'submissions';
  static const String _usersCol = 'users';

  // ─── Likes ──────────────────────────────────────────────────────────────────

  Future<void> likePost(String userId, String postId, String? authorUid) async {
    final postRef = _db.collection(_submissionsCol).doc(postId);
    final likeRef = postRef.collection('likes').doc(userId);
    final userLikeRef = _db.collection(_usersCol).doc(userId).collection('likes').doc(postId);

    await _db.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);
      if (!postDoc.exists) return;

      final likeDoc = await transaction.get(likeRef);
      if (likeDoc.exists) return;

      // 1. Post-side subcollection (public)
      transaction.set(likeRef, {
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. User-side collection (private, for feed state)
      transaction.set(userLikeRef, {
        'postId': postId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Increment counter
      transaction.update(postRef, {
        'likeCount': FieldValue.increment(1),
      });
    });

    if (authorUid != null && authorUid != userId) {
      await FirebaseService.instance.sendNotification(
        targetUid: authorUid,
        type: 'like',
        actorName: 'A reader', // We could fetch actual name if needed
      );
    }
  }

  Future<void> unlikePost(String userId, String postId) async {
    final postRef = _db.collection(_submissionsCol).doc(postId);
    final likeRef = postRef.collection('likes').doc(userId);
    final userLikeRef = _db.collection(_usersCol).doc(userId).collection('likes').doc(postId);

    await _db.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);
      if (!postDoc.exists) return;

      final likeDoc = await transaction.get(likeRef);
      if (!likeDoc.exists) return;

      transaction.delete(likeRef);
      transaction.delete(userLikeRef);
      
      transaction.update(postRef, {
        'likeCount': FieldValue.increment(-1),
      });
    });
  }

  // ─── Queries ───────────────────────────────────────────────────────────────

  /// Fetches the IDs of all posts liked by the user.
  Future<Set<String>> getLikedPostIds(String userId) async {
    try {
      final snap = await _db.collection(_usersCol).doc(userId).collection('likes').get();
      return snap.docs.map((doc) => doc.id).toSet();
    } catch (e) {
      debugPrint('Error fetching liked post IDs: $e');
      return {};
    }
  }

  // ─── Reshares (Restacks) ────────────────────────────────────────────────────

  Future<void> restackPost(String userId, String postId, {String? authorUid, String? postTitle}) async {
    final postRef = _db.collection(_submissionsCol).doc(postId);
    final reshareRef = postRef.collection('reshares').doc(userId);
    final userRestackRef = _db.collection(_usersCol).doc(userId).collection('restacks').doc(postId);

    await _db.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);
      if (!postDoc.exists) return;

      final reshareDoc = await transaction.get(reshareRef);
      if (reshareDoc.exists) return;

      transaction.set(reshareRef, {
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.set(userRestackRef, {
        'postId': postId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.update(postRef, {
        'reshareCount': FieldValue.increment(1),
      });
    });

    if (authorUid != null && authorUid != userId) {
      await FirebaseService.instance.sendNotification(
        targetUid: authorUid,
        type: 'restack',
        actorName: 'A reader',
        postTitle: postTitle,
      );
    }
  }

  // ─── View Tracking ────────────────────────────────────────────────────────

  /// Increment view count atomically.
  Future<void> incrementViewCount(String postId) async {
    try {
      await _db.collection('submissions').doc(postId).update({
        'viewCount': FieldValue.increment(1),
      });
    } catch (e) {
      debugPrint('Error incrementing view count: $e');
    }
  }

  // ─── Comments ──────────────────────────────────────────────────────────────

  /// Add a comment to a post.
  Future<void> addComment(String postId, String userId, String authorName, String content, {String? authorUid}) async {
    final comment = {
      'userId': userId,
      'authorName': authorName,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await _db.runTransaction((transaction) async {
        final postRef = _db.collection('submissions').doc(postId);
        final commentRef = postRef.collection('comments').doc();

        transaction.set(commentRef, comment);
        transaction.update(postRef, {
          'commentCount': FieldValue.increment(1),
        });
      });

      if (authorUid != null && authorUid != userId) {
        await FirebaseService.instance.sendNotification(
          targetUid: authorUid,
          type: 'comment',
          actorName: authorName,
        );
      }
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }

  /// Fetch comments for a post.
  Stream<List<Comment>> getComments(String postId) {
    return _db
        .collection('submissions')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Comment.fromFirestore(doc)).toList());
  }
}
