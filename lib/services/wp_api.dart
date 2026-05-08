import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:romanticists_app/models/post.dart';
import 'package:romanticists_app/models/category.dart';

/// Custom exception for WordPress API errors.
class WpApiException implements Exception {
  final String message;
  final int? statusCode;

  const WpApiException(this.message, {this.statusCode});

  @override
  String toString() => 'WpApiException: $message (status: $statusCode)';
}

/// Service layer for the WordPress REST API.
/// All methods are stateless and return typed results.
class WpApiService {
  WpApiService._();

  static final WpApiService instance = WpApiService._();

  // WordPress.com hosted blogs use the public REST API, not /wp-json/wp/v2
  static const String _baseUrl =
      'https://public-api.wordpress.com/wp/v2/sites/21stromanticists.wordpress.com';

  static const Duration _timeout = Duration(seconds: 15);

  static const Map<String, String> _headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  // ─── Internal Helpers ──────────────────────────────────────────────────────

  Future<dynamic> _get(String endpoint) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        throw WpApiException('Resource not found', statusCode: 404);
      } else {
        throw WpApiException(
          'Server error: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on WpApiException {
      rethrow;
    } catch (e) {
      throw WpApiException('Network error: $e');
    }
  }

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Fetches a paginated list of posts.
  ///
  /// [page] is 1-indexed.  Returns an empty list if there are no more pages.
  Future<List<Post>> fetchPosts({
    int page = 1,
    int perPage = 10,
    int? categoryId,
  }) async {
    final queryParams = StringBuffer('?per_page=$perPage&page=$page&_embed=true');
    if (categoryId != null && categoryId != 0) {
      queryParams.write('&categories=$categoryId');
    }

    final raw = await _get('/posts$queryParams');
    if (raw is! List) return [];

    return raw
        .map((item) {
          try {
            return Post.fromJson(item as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<Post>()
        .toList();
  }

  /// Fetches a single post by ID.
  Future<Post> fetchPost(int id) async {
    final raw = await _get('/posts/$id?_embed=true');
    return Post.fromJson(raw as Map<String, dynamic>);
  }

  /// Searches posts by a query string.
  Future<List<Post>> searchPosts(String query, {int page = 1, int perPage = 10}) async {
    if (query.trim().isEmpty) return [];
    final encoded = Uri.encodeComponent(query.trim());
    final raw = await _get(
      '/posts?search=$encoded&per_page=$perPage&page=$page&_embed=true',
    );
    if (raw is! List) return [];

    return raw
        .map((item) {
          try {
            return Post.fromJson(item as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<Post>()
        .toList();
  }

  /// Fetches all categories from the site.
  Future<List<Category>> fetchCategories() async {
    final raw = await _get('/categories?per_page=100');
    if (raw is! List) return [];

    return raw
        .map((item) {
          try {
            return Category.fromJson(item as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<Category>()
        .toList();
  }

  /// Returns the total number of pages for a given category / search.
  /// Parses `X-WP-TotalPages` header from a HEAD request.
  Future<int> fetchTotalPages({
    int perPage = 10,
    int? categoryId,
    String? search,
  }) async {
    final queryParams = StringBuffer('?per_page=$perPage');
    if (categoryId != null && categoryId != 0) {
      queryParams.write('&categories=$categoryId');
    }
    if (search != null && search.isNotEmpty) {
      queryParams.write('&search=${Uri.encodeComponent(search)}');
    }

    final uri = Uri.parse('$_baseUrl/posts$queryParams');
    try {
      final response = await http
          .head(uri, headers: _headers)
          .timeout(_timeout);
      final totalPages = int.tryParse(
            response.headers['x-wp-totalpages'] ?? '1',
          ) ??
          1;
      return totalPages;
    } catch (_) {
      return 1;
    }
  }
}
