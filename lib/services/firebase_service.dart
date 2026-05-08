import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:romanticists_app/models/post.dart';
import 'package:romanticists_app/models/submission.dart';
import 'package:romanticists_app/services/cloudinary_service.dart';

// ─── Typed exception ──────────────────────────────────────────────────────────

/// Typed exception thrown by [FirebaseService] methods.
class FirebaseServiceException implements Exception {
  final String message;
  final String? code;

  const FirebaseServiceException(this.message, {this.code});

  @override
  String toString() => 'FirebaseServiceException[$code]: $message';
}

// ─── Service ──────────────────────────────────────────────────────────────────

/// Singleton service wrapping Cloud Firestore operations.
class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  static const String _submissionsCol = 'submissions';
  static const String _usersCol = 'users';
  static const String _bookmarksSub = 'bookmarks';
  static const String _followingSub = 'following';
  static const String _followersSub = 'followers';

  // ─── Subscriptions ──────────────────────────────────────────────────────────

  /// Follows an author (could be a WP author ID or Firebase UID).
  Future<void> subscribe(String followerUid, String targetId, {required String targetName}) async {
    try {
      final batch = _db.batch();

      // Add to follower's following list
      final followingRef = _db
          .collection(_usersCol)
          .doc(followerUid)
          .collection(_followingSub)
          .doc(targetId);
      
      batch.set(followingRef, {
        'targetId': targetId,
        'targetName': targetName,
        'subscribedAt': FieldValue.serverTimestamp(),
      });

      // Add to target's followers list
      final followersRef = _db
          .collection(_usersCol)
          .doc(targetId)
          .collection(_followersSub)
          .doc(followerUid);
      
      batch.set(followersRef, {
        'followerUid': followerUid,
        'subscribedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      // Notify the target that someone subscribed
      final followerInfo = await _db.collection(_usersCol).doc(followerUid).get();
      final followerName = followerInfo.data()?['displayName'] as String? ?? 'A reader';
      await sendNotification(
        targetUid: targetId,
        type: 'subscribe',
        actorName: followerName,
      );
    } catch (e) {
      throw FirebaseServiceException('Failed to subscribe: $e');
    }
  }

  /// Unfollows an author.
  Future<void> unsubscribe(String followerUid, String targetId) async {
    try {
      final batch = _db.batch();

      final followingRef = _db
          .collection(_usersCol)
          .doc(followerUid)
          .collection(_followingSub)
          .doc(targetId);
      batch.delete(followingRef);

      final followersRef = _db
          .collection(_usersCol)
          .doc(targetId)
          .collection(_followersSub)
          .doc(followerUid);
      batch.delete(followersRef);

      await batch.commit();
    } catch (e) {
      throw FirebaseServiceException('Failed to unsubscribe: $e');
    }
  }

  /// Checks if [followerUid] is subscribed to [targetId].
  Future<bool> isSubscribed(String followerUid, String targetId) async {
    try {
      final doc = await _db
          .collection(_usersCol)
          .doc(followerUid)
          .collection(_followingSub)
          .doc(targetId)
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  /// Returns the list of IDs this user is following.
  Future<List<String>> getFollowingIds(String uid) async {
    try {
      final snapshot = await _db
          .collection(_usersCol)
          .doc(uid)
          .collection(_followingSub)
          .get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      return [];
    }
  }

  // ─── Submissions ──────────────────────────────────────────────────────────

  /// Saves a [Submission] to the Firestore "submissions" collection.
  /// Posts are published immediately with status = approved.
  Future<void> submitWork(Submission submission) async {
    try {
      // Always publish instantly — no review queue
      final published = submission.copyWith(status: SubmissionStatus.approved);
      await _db.collection(_submissionsCol).add(published.toJson());
    } on FirebaseException catch (e) {
      throw FirebaseServiceException(
        e.message ?? 'Failed to submit work.',
        code: e.code,
      );
    } catch (e) {
      throw FirebaseServiceException('Unexpected error: $e');
    }
  }

  /// Uploads a cover image for a submission via Cloudinary and returns the URL.
  Future<String> uploadSubmissionImage(String uid, File file) async {
    try {
      return await CloudinaryService.instance.uploadSubmissionImage(uid, file);
    } catch (e) {
      throw FirebaseServiceException('Failed to upload image: $e');
    }
  }

  /// Returns all submissions belonging to [userId], ordered newest-first.
  Future<List<Submission>> getUserSubmissions(String userId) async {
    try {
      final snapshot = await _db
          .collection(_submissionsCol)
          .where('userId', isEqualTo: userId)
          .get();

      final list = snapshot.docs
          .map((doc) => Submission.fromJson(doc.data(), id: doc.id))
          .toList();

      list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      return list;
    } on FirebaseException catch (e) {
      throw FirebaseServiceException(
        e.message ?? 'Failed to fetch submissions.',
        code: e.code,
      );
    } catch (e) {
      throw FirebaseServiceException('Unexpected error: $e');
    }
  }

  /// Returns public info for a user (displayName, photoURL, etc).
  Future<Map<String, dynamic>?> getUserPublicInfo(String uid) async {
    try {
      final doc = await _db.collection(_usersCol).doc(uid).get();
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  Future<int> getFollowerCount(String uid) async {
    final snap = await _db.collection(_usersCol).doc(uid).collection(_followersSub).count().get();
    return snap.count ?? 0;
  }

  Future<int> getFollowingCount(String uid) async {
    final snap = await _db.collection(_usersCol).doc(uid).collection(_followingSub).count().get();
    return snap.count ?? 0;
  }

  /// Searches users by username or displayName prefix.
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().isEmpty) return [];
    final q = query.trim().toLowerCase();
    try {
      // Query by username prefix
      final byUsername = await _db
          .collection(_usersCol)
          .where('username', isGreaterThanOrEqualTo: q)
          .where('username', isLessThanOrEqualTo: '$q\uf8ff')
          .limit(10)
          .get();

      // Query by displayName prefix (case-insensitive via lowercase field)
      final byName = await _db
          .collection(_usersCol)
          .where('displayNameLower', isGreaterThanOrEqualTo: q)
          .where('displayNameLower', isLessThanOrEqualTo: '$q\uf8ff')
          .limit(10)
          .get();

      final merged = <String, Map<String, dynamic>>{};
      for (final doc in [...byUsername.docs, ...byName.docs]) {
        merged[doc.id] = {'uid': doc.id, ...doc.data()};
      }
      return merged.values.toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Profile Updates ────────────────────────────────────────────────────────

  /// Uploads a profile picture via Cloudinary and returns the URL.
  Future<String> uploadProfilePicture(String uid, File file) async {
    try {
      return await CloudinaryService.instance.uploadProfilePicture(uid, file);
    } catch (e) {
      throw FirebaseServiceException('Failed to upload image: $e');
    }
  }

  /// Updates the user's Firestore document with new profile data.
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      final dn = data['displayName'] as String?;
      await _db.collection(_usersCol).doc(uid).set(
        {
          ...data,
          if (dn != null) 'displayNameLower': dn.toLowerCase(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      throw FirebaseServiceException('Failed to update profile: $e');
    }
  }

  /// Checks if a username is already taken by someone else.
  Future<bool> isUsernameAvailable(String username, String currentUid) async {
    try {
      final snapshot = await _db
          .collection(_usersCol)
          .where('username', isEqualTo: username.trim().toLowerCase())
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) return true;
      // It's available if the only user found is the current one
      return snapshot.docs.first.id == currentUid;
    } catch (_) {
      return false;
    }
  }

  // ─── Notifications ────────────────────────────────────────────────────────

  static const _notificationsSub = 'notifications';

  /// Writes a notification document to a target user's notifications subcollection.
  Future<void> sendNotification({
    required String targetUid,
    required String type,       // 'subscribe' | 'like' | 'new_post'
    required String actorName,
    String? postTitle,
  }) async {
    try {
      await _db
          .collection(_usersCol)
          .doc(targetUid)
          .collection(_notificationsSub)
          .add({
        'type': type,
        'actorName': actorName,
        if (postTitle != null) 'postTitle': postTitle,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (_) {
      // Notifications are best-effort — never block the main action
    }
  }

  // ─── Bookmarks ────────────────────────────────────────────────────────────

  /// Returns bookmarked [Post] objects for [uid], newest-saved first.
  Future<List<Post>> getBookmarkedPosts(String uid) async {
    try {
      final snapshot = await _db
          .collection(_usersCol)
          .doc(uid)
          .collection(_bookmarksSub)
          .orderBy('savedAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final d = doc.data();
        return Post(
          id: d['postId'] as int,
          authorId: d['authorId'] as int? ?? 0,
          title: d['title'] as String? ?? '',
          content: '',
          excerpt: d['excerpt'] as String? ?? '',
          author: d['author'] as String? ?? '',
          imageUrl: d['imageUrl'] as String? ?? '',
          publishedAt: d['publishedAt'] is Timestamp
              ? (d['publishedAt'] as Timestamp).toDate()
              : DateTime.now(),
          categories:
              ((d['categories'] as List<dynamic>?) ?? []).cast<int>(),
          slug: d['slug'] as String? ?? '',
          link: d['link'] as String? ?? '',
        );
      }).toList();
    } on FirebaseException catch (e) {
      throw FirebaseServiceException(
        e.message ?? 'Failed to fetch bookmarks.',
        code: e.code,
      );
    } catch (e) {
      throw FirebaseServiceException('Unexpected error: $e');
    }
  }

  /// Toggles a bookmark for [uid] using [post] data.
  /// Adds if not present, removes if already saved.
  Future<void> toggleBookmark(String uid, Post post) async {
    try {
      final ref = _db
          .collection(_usersCol)
          .doc(uid)
          .collection(_bookmarksSub)
          .doc(post.id.toString());

      final snapshot = await ref.get();
      if (snapshot.exists) {
        await ref.delete();
      } else {
        await ref.set({
          'postId': post.id,
          'savedAt': FieldValue.serverTimestamp(),
          'title': post.title,
          'excerpt': post.excerpt,
          'imageUrl': post.imageUrl,
          'author': post.author,
          'publishedAt': Timestamp.fromDate(post.publishedAt),
          'categories': post.categories,
          'slug': post.slug,
          'link': post.link,
        });
      }
    } on FirebaseException catch (e) {
      throw FirebaseServiceException(
        e.message ?? 'Failed to toggle bookmark.',
        code: e.code,
      );
    } catch (e) {
      throw FirebaseServiceException('Unexpected error: $e');
    }
  }
}
