import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:romanticists_app/models/post.dart';
import 'package:romanticists_app/services/firebase_service.dart';

/// Data class representing a user-created collection of saved posts.
class PostCollection {
  final String id;
  final String name;
  final DateTime createdAt;
  final int postCount;
  final String? coverImageUrl; // first post image

  const PostCollection({
    required this.id,
    required this.name,
    required this.createdAt,
    this.postCount = 0,
    this.coverImageUrl,
  });

  factory PostCollection.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final ts = d['createdAt'];
    return PostCollection(
      id: doc.id,
      name: d['name'] as String? ?? 'Untitled',
      createdAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      postCount: d['postCount'] as int? ?? 0,
      coverImageUrl: d['coverImageUrl'] as String?,
    );
  }
}

/// Manages user post collections in Firestore.
///
/// Schema:
///   users/{uid}/collections/{colId}  — collection doc
///   users/{uid}/collections/{colId}/posts/{postId}  — post refs
class CollectionsService {
  CollectionsService._();
  static final instance = CollectionsService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference _colRef(String uid) =>
      _db.collection('users').doc(uid).collection('collections');

  CollectionReference _postsRef(String uid, String colId) =>
      _colRef(uid).doc(colId).collection('posts');

  // ─── Collections CRUD ────────────────────────────────────────────────────

  /// Returns all collections for a user, newest first.
  Future<List<PostCollection>> getCollections(String uid) async {
    try {
      final snap = await _colRef(uid)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map(PostCollection.fromDoc).toList();
    } catch (_) {
      return [];
    }
  }

  /// Creates a new empty collection and returns its ID.
  Future<String> createCollection(String uid, String name) async {
    final doc = await _colRef(uid).add({
      'name': name.trim(),
      'postCount': 0,
      'coverImageUrl': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  /// Deletes a collection and all its post references.
  Future<void> deleteCollection(String uid, String colId) async {
    // Delete all post sub-docs first
    final posts = await _postsRef(uid, colId).get();
    final batch = _db.batch();
    for (final d in posts.docs) batch.delete(d.reference);
    batch.delete(_colRef(uid).doc(colId));
    await batch.commit();
  }

  // ─── Posts within a collection ────────────────────────────────────────────

  /// Adds [post] to the given collection. No-op if already present.
  Future<void> addPostToCollection(
      String uid, String colId, Post post) async {
    final postRef = _postsRef(uid, colId).doc(post.id.toString());
    final colRef = _colRef(uid).doc(colId);

    await _db.runTransaction((tx) async {
      final existing = await tx.get(postRef);
      if (existing.exists) return; // already in collection

      tx.set(postRef, {
        'postId': post.id,
        'title': post.cleanTitle,
        'imageUrl': post.imageUrl,
        'author': post.author,
        'publishedAt': Timestamp.fromDate(post.publishedAt),
        'addedAt': FieldValue.serverTimestamp(),
      });

      // Update count and cover image
      final colSnap = await tx.get(colRef);
      final currentCount = (colSnap.data() as Map?)?['postCount'] as int? ?? 0;
      final hasCover = (colSnap.data() as Map?)?['coverImageUrl'] != null;
      tx.update(colRef, {
        'postCount': currentCount + 1,
        if (!hasCover && post.imageUrl.isNotEmpty)
          'coverImageUrl': post.imageUrl,
      });
    });
  }

  /// Removes [post] from the given collection.
  Future<void> removePostFromCollection(
      String uid, String colId, int postId) async {
    final postRef = _postsRef(uid, colId).doc(postId.toString());
    final colRef = _colRef(uid).doc(colId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(postRef);
      if (!snap.exists) return;
      tx.delete(postRef);
      final colSnap = await tx.get(colRef);
      final currentCount = (colSnap.data() as Map?)?['postCount'] as int? ?? 1;
      tx.update(colRef, {'postCount': (currentCount - 1).clamp(0, 999999)});
    });
  }

  /// Returns the IDs of all collections this post belongs to.
  Future<Set<String>> getCollectionIdsForPost(String uid, int postId) async {
    try {
      final ids = <String>{};
      final cols = await getCollections(uid);
      for (final col in cols) {
        final doc =
            await _postsRef(uid, col.id).doc(postId.toString()).get();
        if (doc.exists) ids.add(col.id);
      }
      return ids;
    } catch (_) {
      return {};
    }
  }

  /// Returns all post IDs in a collection (as a snapshot map for offline use).
  Future<List<Map<String, dynamic>>> getPostsInCollection(
      String uid, String colId) async {
    try {
      final snap = await _postsRef(uid, colId)
          .orderBy('addedAt', descending: true)
          .get();
      return snap.docs
          .map((d) => d.data() as Map<String, dynamic>)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
