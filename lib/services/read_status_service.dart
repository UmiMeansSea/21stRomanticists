import 'package:cloud_firestore/cloud_firestore.dart';

class ReadStatusService {
  ReadStatusService._();
  static final ReadStatusService instance = ReadStatusService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _usersCol = 'users';
  static const String _readPostsSub = 'read_posts';

  /// Marks a post as read for the given user.
  Future<void> markAsRead(String uid, String postId) async {
    try {
      await _db
          .collection(_usersCol)
          .doc(uid)
          .collection(_readPostsSub)
          .doc(postId)
          .set({
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Best effort
    }
  }

  /// Fetches the IDs of all posts read by the user.
  Future<Set<String>> getReadPostIds(String uid) async {
    try {
      final snapshot = await _db
          .collection(_usersCol)
          .doc(uid)
          .collection(_readPostsSub)
          .get();
      return snapshot.docs.map((doc) => doc.id).toSet();
    } catch (_) {
      return {};
    }
  }
}
