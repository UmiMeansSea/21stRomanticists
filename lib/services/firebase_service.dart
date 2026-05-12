import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:romanticists_app/models/post.dart';
import 'package:romanticists_app/models/submission.dart';
import 'package:romanticists_app/models/feed_item.dart';

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

// ─── Background Parsing Functions ────────────────────────────────────────────

List<Submission> _parseSubmissions(List<Map<String, dynamic>> list) {
  return list.map((data) => Submission.fromJson(data, id: data['id'])).toList();
}

List<FeedItem> _parseFeedItems(List<Map<String, dynamic>> list) {
  return list.map((d) {
    final id = d['postId']?.toString() ?? '';
    final isSubmission = id.startsWith('sub_');
    final isWp = id.startsWith('wp_');
    
    int wpId = 0;
    if (isWp) {
      wpId = int.tryParse(id.replaceFirst('wp_', '')) ?? 0;
    } else if (!isSubmission) {
      wpId = int.tryParse(id) ?? 0;
    }

    return FeedItem(
      uniqueId: id,
      authorFirebaseId: d['authorFirebaseId'] as String? ?? '',
      authorName: d['author'] as String? ?? 'Anonymous',
      title: d['title'] as String? ?? '',
      excerpt: d['excerpt'] as String? ?? '',
      imageUrl: d['imageUrl'] as String?,
      publishedAt: d['publishedAt'] is DateTime 
          ? d['publishedAt'] as DateTime 
          : DateTime.now(),
      isSubmission: isSubmission,
      categoryLabel: d['categoryLabel'] as String? ?? '',
      tags: ((d['tags'] as List<dynamic>?) ?? []).cast<String>(),
      wpPost: (isSubmission) ? null : Post(
        id: wpId,
        authorId: 0,
        title: d['title'] as String? ?? '',
        content: '',
        excerpt: d['excerpt'] as String? ?? '',
        author: d['author'] as String? ?? '',
        imageUrl: d['imageUrl'] as String? ?? '',
        publishedAt: DateTime.now(),
        categories: [],
        tagNames: [],
        slug: d['slug'] as String? ?? '',
        link: d['link'] as String? ?? '',
      ),
    );
  }).toList();
}

// ─── Service ──────────────────────────────────────────────────────────────────

/// Singleton service wrapping Cloud Firestore operations.
class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  final Map<String, Map<String, dynamic>> _userCache = {};

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

  static const String _followingCachePrefix = 'following_ids_cache_';

  /// Returns the list of IDs this user is following.
  Future<List<String>> getFollowingIds(String uid) async {
    final cacheKey = '$_followingCachePrefix$uid';
    
    // Cache read
    List<String> cached = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw != null) cached = List<String>.from(jsonDecode(raw));
    } catch (_) {}

    try {
      final snapshot = await _db
          .collection(_usersCol)
          .doc(uid)
          .collection(_followingSub)
          .get();
      final fresh = snapshot.docs.map((doc) => doc.id).toList();
      
      // Cache write
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(fresh));
      
      return fresh;
    } catch (e) {
      return cached;
    }
  }

  // ─── Submissions ──────────────────────────────────────────────────────────

  /// Saves a [Submission] to the Firestore "submissions" collection and returns the document ID.
  Future<String> submitWork(Submission submission) async {
    try {
      final docRef = await _db.collection(_submissionsCol).add(submission.toJson());
      return docRef.id;
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

  /// Updates an existing submission in Firestore.
  Future<void> updateSubmission(String docId, Submission submission) async {
    try {
      await _db.collection(_submissionsCol).doc(docId).update(submission.toJson());
    } catch (e) {
      throw FirebaseServiceException('Failed to update submission: $e');
    }
  }

  /// Permanently deletes a submission from Firestore.
  Future<void> deleteSubmission(String docId) async {
    try {
      await _db.collection(_submissionsCol).doc(docId).delete();
    } catch (e) {
      throw FirebaseServiceException('Failed to delete submission: $e');
    }
  }

  /// Global alias for post deletion
  Future<void> deletePost(String postId) => deleteSubmission(postId);

  static const String _userSubmissionsCachePrefix = 'user_subs_cache_';

  /// Instantly returns locally cached submissions for immediate UI rendering.
  Future<List<Submission>> getCachedUserSubmissions(String userId, {SubmissionStatus? status}) async {
    final cacheKey = '$_userSubmissionsCachePrefix${userId}_all';
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw != null) {
        final List<dynamic> list = jsonDecode(raw);
        var parsed = list.map((m) => Submission.fromJson(m as Map<String, dynamic>, id: m['id'])).toList();
        if (status != null) {
          parsed = parsed.where((s) => s.status == status).toList();
        }
        return parsed;
      }
    } catch (_) {}
    return [];
  }

  /// Returns submissions belonging to [userId], optionally filtered by [status].
  /// [FIXED] Fetches ALL submissions where userId matches — including anonymous
  /// ones — since the profile belongs to the authenticated user.
  /// Anonymous posts still store userId in Firestore via toJson(); the
  /// authorName is just replaced with 'Anonymous' for public display.
  Future<List<Submission>> getUserSubmissions(String userId, {SubmissionStatus? status}) async {
    final cacheKey = '$_userSubmissionsCachePrefix${userId}_all';
    
    try {
      // [FIX] Single query on userId — no status filter at DB level.
      // This ensures anonymous posts (isAnonymous=true) are still fetched
      // because they store userId. Status filtering is done client-side so
      // we can cache everything in one round-trip.
      final snapshot = await _db
          .collection(_submissionsCol)
          .where('userId', isEqualTo: userId)
          .get();

      // [Technique: Isolate Parsing] Offload model mapping to background thread
      final rawData = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      var list = await compute(_parseSubmissions, rawData);

      // [PERF FIX] Manually prepare for JSON storage since jsonEncode doesn't handle Timestamps
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> cacheData = list.map((s) {
        final map = s.toJson();
        map['id'] = s.id;
        // Convert Timestamp to ISO String for local storage
        if (map['submittedAt'] is Timestamp) {
          map['submittedAt'] = (map['submittedAt'] as Timestamp).toDate().toIso8601String();
        }
        return map;
      }).toList();
      
      await prefs.setString(cacheKey, jsonEncode(cacheData));

      // Client-side status filter
      if (status != null) {
        list = list.where((s) => s.status == status).toList();
      }

      list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      return list;
    } on FirebaseException catch (e) {
      final cached = await getCachedUserSubmissions(userId, status: status);
      if (cached.isNotEmpty) return cached;
      throw FirebaseServiceException(
        e.message ?? 'Failed to fetch submissions.',
        code: e.code,
      );
    } catch (e) {
      return await getCachedUserSubmissions(userId, status: status);
    }
  }

  /// Returns approved community submissions for the home feed, newest first.
  /// Uses client-side sort to avoid requiring a composite Firestore index.
  Future<List<Submission>> getPublishedSubmissions({int limit = 100}) async {
    try {
      final snapshot = await _db
          .collection(_submissionsCol)
          .where('status', isEqualTo: 'approved')
          .limit(100)
          .get();

      // [Technique: Isolate Parsing] Offload model mapping to background thread
      final rawData = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
      final list = await compute(_parseSubmissions, rawData);

      list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      return list.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches a single submission by its ID.
  Future<Submission?> getSubmissionById(String id) async {
    try {
      final doc = await _db.collection(_submissionsCol).doc(id).get();
      if (!doc.exists) return null;
      return Submission.fromJson(doc.data()!, id: doc.id);
    } catch (e) {
      debugPrint('Error fetching submission by ID: $e');
      return null;
    }
  }

  /// Instantly returns locally cached public info for immediate UI rendering.
  Future<Map<String, dynamic>?> getCachedUserPublicInfo(String uid) async {
    if (_userCache.containsKey(uid)) return _userCache[uid];
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('user_info_cache_$uid');
      if (raw != null) return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {}
    return null;
  }

  /// Returns public info for a user (displayName, photoURL, etc).
  /// Results are cached in-memory and persistently for the duration of the session.
  Future<Map<String, dynamic>?> getUserPublicInfo(String uid) async {
    if (_userCache.containsKey(uid)) return _userCache[uid];
    try {
      final doc = await _db.collection(_usersCol).doc(uid).get();
      final data = doc.data();
      if (data != null) {
        // Standardize keys
        final standardized = Map<String, dynamic>.from(data);
        standardized['displayName'] ??= data['username'] ?? data['name'];
        standardized['photoURL'] ??= data['profilePicture'] ?? data['avatarUrl'];
        _userCache[uid] = standardized;
        
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_info_cache_$uid', jsonEncode(standardized));
        } catch (_) {}
        
        return standardized;
      }
      return null;
    } catch (_) {
      return await getCachedUserPublicInfo(uid);
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
  static const String _notificationsCachePrefix = 'notifications_cache_';

  /// Returns locally cached notifications for instant UI rendering.
  Future<List<Map<String, dynamic>>> getCachedNotifications(String uid) async {
    final cacheKey = '$_notificationsCachePrefix$uid';
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(cacheKey);
      if (raw != null) {
        final List<dynamic> list = jsonDecode(raw);
        return list.map((m) => Map<String, dynamic>.from(m)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Fetches notifications from Firestore with pagination and SWR caching.
  Future<List<Map<String, dynamic>>> getNotifications(
    String uid, {
    int limit = 20,
    DocumentSnapshot? lastDoc,
  }) async {
    final cacheKey = '$_notificationsCachePrefix$uid';

    try {
      var query = _db
          .collection(_usersCol)
          .doc(uid)
          .collection(_notificationsSub)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snap = await query.get();

      final fresh = snap.docs.map((d) {
        final data = d.data();
        return {
          ...data,
          'id': d.id,
          // Convert Timestamp to ISO string for JSON storage
          'createdAt': (data['createdAt'] as Timestamp?)?.toDate().toIso8601String(),
        };
      }).toList();

      // Only overwrite cache on the first page load
      if (lastDoc == null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, jsonEncode(fresh));
      }

      return fresh;
    } catch (e) {
      debugPrint('[FirebaseService] Error fetching notifications: $e');
      return [];
    }
  }

  /// Writes a notification document to a target user's notifications subcollection.
  Future<void> sendNotification({
    required String targetUid,
    required String type, // 'subscribe' | 'like' | 'new_post'
    required String actorName,
    String? actorImageUrl, // Added for UI optimization
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
        if (actorImageUrl != null) 'actorImageUrl': actorImageUrl,
        if (postTitle != null) 'postTitle': postTitle,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (_) {}
  }

  // ─── Bookmarks ────────────────────────────────────────────────────────────

  /// Returns raw bookmark metadata for [uid].
  Future<List<Map<String, dynamic>>> getBookmarks(String uid) async {
    try {
      final snap = await _db
          .collection(_usersCol)
          .doc(uid)
          .collection(_bookmarksSub)
          .get();
      return snap.docs.map((doc) => doc.data()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns bookmarked feed items for [uid], newest-saved first.
  /// Handles both WP posts and community submissions.
  Future<List<FeedItem>> getBookmarkedFeedItems(String uid) async {
    try {
      final snapshot = await _db
          .collection(_usersCol)
          .doc(uid)
          .collection(_bookmarksSub)
          .orderBy('savedAt', descending: true)
          .get();

      // [Technique: Isolate Parsing] Offload mapping logic to background isolate
      final rawData = snapshot.docs.map((doc) {
        final d = doc.data();
        return {
          ...d,
          // Convert Timestamp to DateTime before passing to Isolate (Isolates can't handle Timestamp easily)
          'publishedAt': (d['publishedAt'] as Timestamp?)?.toDate(),
        };
      }).toList();

      return await compute(_parseFeedItems, rawData);

    } on FirebaseException catch (e) {
      throw FirebaseServiceException(
        e.message ?? 'Failed to fetch bookmarks.',
        code: e.code,
      );
    } catch (e) {
      throw FirebaseServiceException('Unexpected error: $e');
    }
  }

  /// Toggles a bookmark for [uid]. Adds if not present, removes if already saved.
  Future<void> toggleBookmark(String uid, {
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
    try {
      final ref = _db
          .collection(_usersCol)
          .doc(uid)
          .collection(_bookmarksSub)
          .doc(id);

      final snapshot = await ref.get();
      if (snapshot.exists) {
        await ref.delete();
      } else {
        await ref.set({
          'postId': id,
          'savedAt': FieldValue.serverTimestamp(),
          'title': title,
          'excerpt': excerpt,
          'imageUrl': imageUrl,
          'author': author,
          'authorFirebaseId': authorFirebaseId,
          'publishedAt': Timestamp.fromDate(publishedAt),
          'categories': categories,
          'slug': slug,
          'link': link,
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

  // ─── WordPress Migration ───────────────────────────────────────────────────

  /// Migrates a WordPress post to Firestore if it doesn't already exist.
  Future<void> migrateWordPressPost(Post post) async {
    try {
      final query = await _db
          .collection(_submissionsCol)
          .where('wpId', isEqualTo: post.id)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) return; // Already migrated

      // Create a submission-like object from the WP post
      final data = {
        'wpId': post.id,
        'userId': 'legacy_${post.authorId}',
        'authorName': post.author,
        'title': post.title,
        'content': post.content,
        'excerpt': post.excerpt,
        'imageUrl': post.imageUrl,
        'submittedAt': Timestamp.fromDate(post.publishedAt),
        'status': 'approved',
        'category': 'prose', // Map WP articles to prose by default
        'tags': [],
        'isAnonymous': false,
        'wpLink': post.link,
      };

      await _db.collection(_submissionsCol).add(data);
      
      // Also ensure a user record exists for this legacy author
      await createLegacyUser(post.author, post.authorId);
    } catch (e) {
      // Fail silently to not disrupt the feed load
    }
  }

  /// Creates a Firestore user document for a WordPress author if it doesn't exist.
  Future<void> createLegacyUser(String name, int wpId) async {
    try {
      final uid = 'legacy_$wpId';
      final doc = await _db.collection(_usersCol).doc(uid).get();
      if (doc.exists) return;

      await _db.collection(_usersCol).doc(uid).set({
        'displayName': name,
        'displayNameLower': name.toLowerCase(),
        'username': 'legacy_$wpId',
        'isLegacy': true,
        'wpId': wpId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // ─── Engagement Helpers ───────────────────────────────────────────────────

  /// Fetches IDs of posts restacked by a list of followed users.
  Future<List<String>> getRestacksFromFollowedUsers(List<String> followedUids) async {
    if (followedUids.isEmpty) return [];
    
    // Firestore limit for 'in' queries is 30. For simplicity, we use the first 30.
    final limitedUids = followedUids.length > 30 ? followedUids.sublist(0, 30) : followedUids;
    
    try {
      // This is a bit heavy, in a real app we might use a combined 'following_feed' collection
      // For now, we query 'restacks' across followed users if possible, or per user.
      List<String> postIds = [];
      
      for (final uid in limitedUids) {
        final snap = await _db.collection(_usersCol)
            .doc(uid)
            .collection('restacks')
            .orderBy('createdAt', descending: true)
            .limit(10)
            .get();
        
        for (final doc in snap.docs) {
          postIds.add(doc.get('postId') as String);
        }
      }
      
      return postIds.toSet().toList(); // Unique IDs
    } catch (e) {
      debugPrint('Error fetching followed restacks: $e');
      return [];
    }
  }
}

