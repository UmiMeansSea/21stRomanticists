import 'package:romanticists_app/models/feed_item.dart';

abstract class IPostRepository {
  Future<List<FeedItem>> fetchPosts({int page = 1, int? categoryId, String? search, String? tagName});
  Future<int> fetchTotalPages({int? categoryId, String? search, String? tagName});
  Future<List<FeedItem>> getCachedPosts();
  Future<void> cachePosts(List<FeedItem> posts);
  Future<List<String>> fetchTags();
  Future<List<dynamic>> fetchCategories();
  
  // Mutations (may throw UnsupportedError if read-only)
  Future<String> createPost(FeedItem post);
  Future<void> updatePost(String id, FeedItem post);
  Future<void> deletePost(String id);
  
  // Engagement / Migration
  Future<List<String>> getRestacksFromFollowedUsers(List<String> followingIds);
  Future<void> migrateWordPressPost(dynamic post);
}
