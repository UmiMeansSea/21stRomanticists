import 'package:romanticists_app/models/feed_item.dart';
import 'package:romanticists_app/models/submission.dart';
import 'package:romanticists_app/repositories/post_repository.dart';
import 'package:romanticists_app/services/firebase_service.dart';

class FirebasePostRepository implements IPostRepository {
  final FirebaseService _service = FirebaseService.instance;

  @override
  Future<List<FeedItem>> fetchPosts({int page = 1, int? categoryId, String? search, String? tagName}) async {
    final submissions = await _service.getPublishedSubmissions();
    return submissions.map((s) => FeedItem.fromSubmission(s)).toList();
  }

  @override
  Future<int> fetchTotalPages({int? categoryId, String? search, String? tagName}) async => 1;

  @override
  Future<List<FeedItem>> getCachedPosts() async => [];

  @override
  Future<void> cachePosts(List<FeedItem> posts) async {}

  @override
  Future<List<String>> fetchTags() async => [];

  @override
  Future<List<dynamic>> fetchCategories() async => [];

  @override
  Future<String> createPost(FeedItem post) async {
    if (post.submission != null) {
      return await _service.submitWork(post.submission!);
    }
    throw ArgumentError('Expected FeedItem with Submission');
  }

  @override
  Future<void> updatePost(String id, FeedItem post) async {
    if (post.submission != null) {
      await _service.updateSubmission(id, post.submission!);
    } else {
      throw ArgumentError('Expected FeedItem with Submission');
    }
  }

  @override
  Future<void> deletePost(String id) async {
    await _service.deleteSubmission(id);
  }

  @override
  Future<List<String>> getRestacksFromFollowedUsers(List<String> followingIds) async {
    return await _service.getRestacksFromFollowedUsers(followingIds);
  }

  @override
  Future<void> migrateWordPressPost(dynamic post) async {
    await _service.migrateWordPressPost(post);
  }
}
