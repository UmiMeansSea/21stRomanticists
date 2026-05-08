import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:romanticists_app/models/submission.dart';

// ─── Typed exception ──────────────────────────────────────────────────────────

/// Typed exception thrown by [FirebaseService] methods.
class FirebaseServiceException implements Exception {
  final String message;
  final String? code;

  const FirebaseServiceException(this.message, {this.code});

  @override
  String toString() =>
      'FirebaseServiceException[$code]: $message';
}

// ─── Service ──────────────────────────────────────────────────────────────────

/// Singleton service wrapping Cloud Firestore operations.
///
/// Firebase is NOT yet initialised — call [FirebaseService.instance] only
/// after `Firebase.initializeApp()` has completed in main().
/// All public methods have try/catch and throw [FirebaseServiceException].
class FirebaseService {
  FirebaseService._();

  static final FirebaseService instance = FirebaseService._();

  // Lazily resolved so the app doesn't crash before Firebase.initializeApp().
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  static const String _submissionsCol = 'submissions';
  static const String _usersCol = 'users';
  static const String _bookmarksSub = 'bookmarks';

  // ─── Submissions ──────────────────────────────────────────────────────────

  /// Saves a [Submission] to the Firestore "submissions" collection.
  Future<void> submitWork(Submission submission) async {
    try {
      await _db.collection(_submissionsCol).add(submission.toJson());
    } on FirebaseException catch (e) {
      throw FirebaseServiceException(
        e.message ?? 'Failed to submit work.',
        code: e.code,
      );
    } catch (e) {
      throw FirebaseServiceException('Unexpected error: $e');
    }
  }

  /// Returns all submissions belonging to [userId], ordered newest-first.
  Future<List<Submission>> getUserSubmissions(String userId) async {
    try {
      final snapshot = await _db
          .collection(_submissionsCol)
          .where('userId', isEqualTo: userId)
          .orderBy('submittedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => Submission.fromJson(doc.data(), id: doc.id))
          .toList();
    } on FirebaseException catch (e) {
      throw FirebaseServiceException(
        e.message ?? 'Failed to fetch submissions.',
        code: e.code,
      );
    } catch (e) {
      throw FirebaseServiceException('Unexpected error: $e');
    }
  }

  // ─── Bookmarks ────────────────────────────────────────────────────────────

  /// Returns the list of bookmarked post IDs (as strings) for [uid].
  Future<List<String>> getBookmarks(String uid) async {
    try {
      final snapshot = await _db
          .collection(_usersCol)
          .doc(uid)
          .collection(_bookmarksSub)
          .get();

      return snapshot.docs.map((doc) => doc.id).toList();
    } on FirebaseException catch (e) {
      throw FirebaseServiceException(
        e.message ?? 'Failed to fetch bookmarks.',
        code: e.code,
      );
    } catch (e) {
      throw FirebaseServiceException('Unexpected error: $e');
    }
  }

  /// Adds or removes [postId] from the bookmarks sub-collection for [uid].
  ///
  /// If the bookmark already exists it is removed (toggle off);
  /// if it does not exist it is added (toggle on).
  Future<void> toggleBookmark(String uid, int postId) async {
    try {
      final ref = _db
          .collection(_usersCol)
          .doc(uid)
          .collection(_bookmarksSub)
          .doc(postId.toString());

      final snapshot = await ref.get();
      if (snapshot.exists) {
        await ref.delete();
      } else {
        await ref.set({
          'postId': postId,
          'savedAt': FieldValue.serverTimestamp(),
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
