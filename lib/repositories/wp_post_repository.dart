import 'package:romanticists_app/models/feed_item.dart';
import 'package:romanticists_app/models/post.dart';
import 'package:romanticists_app/repositories/post_repository.dart';
import 'package:romanticists_app/services/wp_api.dart';

class WpPostRepository implements IPostRepository {
  final WpApiService _api = WpApiService.instance;

  @override
  Future<List<FeedItem>> fetchPosts({int page = 1, int? categoryId, String? search, String? tagName}) async {
    final List<Post> posts;
    if (search != null && search.isNotEmpty) {
      posts = await _api.searchPosts(search, page: page);
    } else {
      posts = await _api.fetchPosts(page: page, categoryId: categoryId, tagName: tagName);
    }
    return posts.map((p) => FeedItem.fromPost(p)).toList();
  }

  @override
  Future<int> fetchTotalPages({int? categoryId, String? search, String? tagName}) {
    return _api.fetchTotalPages(categoryId: categoryId, search: search, tagName: tagName);
  }

  @override
  Future<List<FeedItem>> getCachedPosts() async {
    final posts = await _api.readCachedPosts();
    return posts.map((p) => FeedItem.fromPost(p)).toList();
  }

  @override
  Future<void> cachePosts(List<FeedItem> posts) async {
    final wpPosts = posts.map((e) => e.wpPost).whereType<Post>().toList();
    await _api.writeCachedPosts(wpPosts);
  }

  @override
  Future<List<String>> fetchTags() async => await _api.fetchTags();

  @override
  Future<List<dynamic>> fetchCategories() async => await _api.fetchCategories();

  @override
  Future<String> createPost(FeedItem post) => throw UnsupportedError('WP API is read-only');

  @override
  Future<void> updatePost(String id, FeedItem post) => throw UnsupportedError('WP API is read-only');

  @override
  Future<void> deletePost(String id) => throw UnsupportedError('WP API is read-only');

  @override
  Future<List<String>> getRestacksFromFollowedUsers(List<String> followingIds) async => [];

  @override
  Future<void> migrateWordPressPost(dynamic post) => throw UnsupportedError('WP API does not support migration');
}
