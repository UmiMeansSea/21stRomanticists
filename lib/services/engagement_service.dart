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

  Future<void> toggleLike(String userId, String postId, bool currentlyLiked) async {
    final postRef = _db.collection(_submissionsCol).doc(postId);
    final userLikeRef = _db.collection(_usersCol).doc(userId).collection('likes').doc(postId);

    await _db.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);
      if (!postDoc.exists) return;

      final likedBy = List<String>.from(postDoc.data()?['likedBy'] ?? []);
      final isLiked = likedBy.contains(userId);

      if (isLiked) {
        transaction.update(postRef, {
          'likedBy': FieldValue.arrayRemove([userId]),
          'likeCount': FieldValue.increment(-1),
        });
        transaction.delete(userLikeRef);
      } else {
        transaction.update(postRef, {
          'likedBy': FieldValue.arrayUnion([userId]),
          'likeCount': FieldValue.increment(1),
        });
        transaction.set(userLikeRef, {
          'postId': postId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
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

  Future<void> toggleRepost(String userId, String postId) async {
    final postRef = _db.collection(_submissionsCol).doc(postId);
    final userRestackRef = _db.collection(_usersCol).doc(userId).collection('restacks').doc(postId);

    await _db.runTransaction((transaction) async {
      final postDoc = await transaction.get(postRef);
      if (!postDoc.exists) return;

      final repostedBy = List<String>.from(postDoc.data()?['repostedBy'] ?? []);
      final isReposted = repostedBy.contains(userId);

      if (isReposted) {
        transaction.update(postRef, {
          'repostedBy': FieldValue.arrayRemove([userId]),
          'reshareCount': FieldValue.increment(-1),
        });
        transaction.delete(userRestackRef);
      } else {
        transaction.update(postRef, {
          'repostedBy': FieldValue.arrayUnion([userId]),
          'reshareCount': FieldValue.increment(1),
        });
        transaction.set(userRestackRef, {
          'postId': postId,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    });
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
