import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:romanticists_app/models/submission.dart';
import 'package:romanticists_app/services/firebase_service.dart';

enum ActivityStatus { initial, loading, success, failure }

class ActivityProvider extends ChangeNotifier {
  List<Submission> subscribedPosts = [];
  List<Map<String, dynamic>> notifications = [];
  
  bool isLoadingSubscribed = false;
  bool isLoadingNotifications = false;
  
  bool hasMoreSubscribed = true;
  bool hasMoreNotifications = true;
  
  DocumentSnapshot? lastSubscribedDoc;
  DocumentSnapshot? lastNotificationDoc;

  static const String _subscribedCacheKey = 'activity_subscribed_cache_';
  static const String _notificationsCacheKey = 'activity_notifications_cache_';

  // ─── Phase 1: Stale-While-Revalidate Caching ────────────────────────────────

  Future<void> init(String uid) async {
    await Future.wait([
      _loadSubscribedSWR(uid),
      _loadNotificationsSWR(uid),
    ]);
  }

  /// Loads Subscribed feed using SWR
  Future<void> _loadSubscribedSWR(String uid) async {
    // 1. Instant Render from Cache
    await _loadFromCache(uid, _subscribedCacheKey, (data) {
      subscribedPosts = data.map((m) => Submission.fromJson(m, id: m['id'])).toList();
      notifyListeners();
    });

    // 2. Background Revalidate
    await refreshSubscribed(uid);
  }

  /// Loads Notifications using SWR
  Future<void> _loadNotificationsSWR(String uid) async {
    // 1. Instant Render from Cache
    await _loadFromCache(uid, _notificationsCacheKey, (data) {
      notifications = data.cast<Map<String, dynamic>>();
      notifyListeners();
    });

    // 2. Background Revalidate
    await refreshNotifications(uid);
  }

  Future<void> _loadFromCache(String uid, String key, Function(List<dynamic>) onData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$key$uid');
      if (raw != null) {
        final List<dynamic> data = jsonDecode(raw);
        onData(data);
      }
    } catch (e) {
      debugPrint('[ActivityProvider] Cache read error: $e');
    }
  }

  Future<void> _saveToCache(String uid, String key, List<dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$key$uid', jsonEncode(data));
    } catch (e) {
      debugPrint('[ActivityProvider] Cache write error: $e');
    }
  }

  // ─── Phase 3: Pagination & Query Limits (limit 20) ──────────────────────────

  Future<void> refreshSubscribed(String uid) async {
    isLoadingSubscribed = true;
    notifyListeners();

    try {
      final followingIds = await FirebaseService.instance.getFollowingIds(uid);
      if (followingIds.isEmpty) {
        subscribedPosts = [];
        hasMoreSubscribed = false;
        isLoadingSubscribed = false;
        notifyListeners();
        return;
      }

      // Query optimized: limit 20
      final snapshot = await FirebaseFirestore.instance
          .collection('submissions')
          .where('userId', whereIn: followingIds.take(10).toList()) // Firestore limit
          .where('status', isEqualTo: 'approved')
          .orderBy('submittedAt', descending: true)
          .limit(20)
          .get();

      subscribedPosts = snapshot.docs.map((doc) => Submission.fromJson(doc.data(), id: doc.id)).toList();
      lastSubscribedDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      hasMoreSubscribed = subscribedPosts.length == 20;

      // Update Cache
      _saveToCache(uid, _subscribedCacheKey, subscribedPosts.map((s) => s.toJson()..['id'] = s.id).toList());
    } catch (e) {
      debugPrint('[ActivityProvider] Error loading subscribed: $e');
    } finally {
      isLoadingSubscribed = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreSubscribed(String uid) async {
    if (!hasMoreSubscribed || isLoadingSubscribed || lastSubscribedDoc == null) return;
    
    isLoadingSubscribed = true;
    notifyListeners();

    try {
      final followingIds = await FirebaseService.instance.getFollowingIds(uid);
      final snapshot = await FirebaseFirestore.instance
          .collection('submissions')
          .where('userId', whereIn: followingIds.take(10).toList())
          .where('status', isEqualTo: 'approved')
          .orderBy('submittedAt', descending: true)
          .startAfterDocument(lastSubscribedDoc!)
          .limit(20)
          .get();

      final more = snapshot.docs.map((doc) => Submission.fromJson(doc.data(), id: doc.id)).toList();
      subscribedPosts.addAll(more);
      lastSubscribedDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      hasMoreSubscribed = more.length == 20;
    } catch (e) {
      debugPrint('[ActivityProvider] Error loading more subscribed: $e');
    } finally {
      isLoadingSubscribed = false;
      notifyListeners();
    }
  }

  Future<void> refreshNotifications(String uid) async {
    isLoadingNotifications = true;
    notifyListeners();

    try {
      // Query optimized: limit 20
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      notifications = snapshot.docs.map((d) => {
        ...d.data(),
        'id': d.id,
      }).toList();
      
      lastNotificationDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      hasMoreNotifications = notifications.length == 20;

      // Update Cache
      _saveToCache(uid, _notificationsCacheKey, notifications);
    } catch (e) {
      debugPrint('[ActivityProvider] Error loading notifications: $e');
    } finally {
      isLoadingNotifications = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreNotifications(String uid) async {
    if (!hasMoreNotifications || isLoadingNotifications || lastNotificationDoc == null) return;

    isLoadingNotifications = true;
    notifyListeners();

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .startAfterDocument(lastNotificationDoc!)
          .limit(20)
          .get();

      final more = snapshot.docs.map((d) => {
        ...d.data(),
        'id': d.id,
      }).toList();

      notifications.addAll(more);
      lastNotificationDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      hasMoreNotifications = more.length == 20;
    } catch (e) {
      debugPrint('[ActivityProvider] Error loading more notifications: $e');
    } finally {
      isLoadingNotifications = false;
      notifyListeners();
    }
  }
}
