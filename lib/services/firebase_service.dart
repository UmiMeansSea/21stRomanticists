import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:romanticists_app/models/post.dart';
import 'package:romanticists_app/models/submission.dart';

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
      // Remove orderBy here to avoid "index required" error
      final snapshot = await _db
          .collection(_submissionsCol)
          .where('userId', isEqualTo: userId)
          .get();

      final list = snapshot.docs
          .map((doc) => Submission.fromJson(doc.data(), id: doc.id))
          .toList();

      // Sort in-memory (newest first)
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
