import 'dart:convert';
import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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

// ─── Background Parsing Functions ────────────────────────────────────────────

/// Parsing logic for a list of posts, intended for background Isolate via compute().
List<Post> _parsePosts(String body) {
  final List<dynamic> list = jsonDecode(body);
  return list
      .map((item) {
        try {
          return Post.fromJson(item as Map<String, dynamic>);
        } catch (e, stack) {
          debugPrint('WP Parsing Error for item ID ${item is Map ? item['id'] : 'unknown'}: $e');
          debugPrint('Stacktrace: $stack');
          return null;
        }
      })
      .whereType<Post>()
      .toList();
}

/// Parsing logic for a single post.
Post _parseSinglePost(String body) {
  return Post.fromJson(jsonDecode(body) as Map<String, dynamic>);
}

/// Parsing logic for categories.
List<Category> _parseCategories(String body) {
  final List<dynamic> list = jsonDecode(body);
  return list
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

/// Service layer for the WordPress REST API.
/// All methods are stateless and return typed results.
class WpApiService {
  WpApiService._();

  static final WpApiService instance = WpApiService._();

  // WordPress.com hosted blogs use the public REST API, not /wp-json/wp/v2
  // static const String _baseUrl =
  //     'https://public-api.wordpress.com/wp/v2/sites/21stromanticists.wordpress.com';

  // NEW: Querying your scalable live BFF on Vercel
  static const String _baseUrl = 'https://21st-romanticists.vercel.app/api/wp';

  static const Duration _timeout = Duration(seconds: 15);

  static const Map<String, String> _headers = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  // ─── Local Cache Helpers (Stale-While-Revalidate) ─────────────────────────

  static const String _cacheKey = 'wp_posts_cache_v1';

  /// Reads the cached page-1 posts from SharedPreferences.
  /// Returns an empty list on cache miss or parse failure.
  Future<List<Post>> readCachedPosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return [];
      
      // [Technique: Isolate Parsing] Offload cache parsing to background isolate
      return await compute(_parsePosts, raw);
    } catch (e) {
      debugPrint('Cache read failed: $e');
      return [];
    }
  }

  /// Serializes [posts] to SharedPreferences, overwriting any prior cache.
  Future<void> writeCachedPosts(List<Post> posts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(posts.map((p) => p.toJson()).toList());
      await prefs.setString(_cacheKey, encoded);
    } catch (e) {
      debugPrint('Cache write failed: $e');
    }
  }

  // ─── Internal Helpers ──────────────────────────────────────────────────────

  /// Performs a GET request and returns the RAW body string.
  /// Parsing is handled by the calling method via compute().
  Future<String> _getRaw(String endpoint) async {
    final uri = Uri.parse('$_baseUrl$endpoint');
    try {
      final response = await http
          .get(uri, headers: _headers)
          .timeout(_timeout);

      if (response.statusCode == 200) {
        return response.body;
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
    int? tagId,
    String? tagName,
  }) async {
    final queryParams = StringBuffer('?per_page=$perPage&page=$page&_embed=true');
    if (categoryId != null && categoryId != 0) {
      queryParams.write('&categories=$categoryId');
    }
    if (tagId != null) {
      queryParams.write('&tags=$tagId');
    }
    if (tagName != null && tagName.isNotEmpty) {
      final tid = await fetchTagIdByName(tagName);
      if (tid != null) {
        queryParams.write('&tags=$tid');
      } else {
        queryParams.write('&tags=0'); 
      }
    }

    final rawBody = await _getRaw('/posts$queryParams');
    
    // [Technique: Isolate Parsing] Use compute() to map results in a background thread
    return await compute(_parsePosts, rawBody);
  }

  /// Fetches a single post by ID.
  Future<Post> fetchPost(int id) async {
    final rawBody = await _getRaw('/posts/$id?_embed=true');
    return await compute(_parseSinglePost, rawBody);
  }

  /// Searches posts by a query string.
  Future<List<Post>> searchPosts(String query, {int page = 1, int perPage = 10}) async {
    if (query.trim().isEmpty) return [];
    final encoded = Uri.encodeComponent(query.trim());
    final rawBody = await _getRaw(
      '/posts?search=$encoded&per_page=$perPage&page=$page&_embed=true',
    );
    
    // [Technique: Isolate Parsing] Background thread parsing for search results
    return await compute(_parsePosts, rawBody);
  }

  /// Fetches all categories from the site.
  Future<List<Category>> fetchCategories() async {
    final rawBody = await _getRaw('/categories?per_page=100');
    return await compute(_parseCategories, rawBody);
  }

  /// Fetches all tags from the site.
  Future<List<String>> fetchTags() async {
    try {
      final rawBody = await _getRaw('/tags?per_page=100&orderby=count&order=desc');
      
      // Simple parsing can stay on main thread for small lists, but for consistency:
      return await compute((String body) {
        final List<dynamic> list = jsonDecode(body);
        return list.map((item) => (item as Map<String, dynamic>)['name'] as String).toList();
      }, rawBody);
    } catch (_) {
      return [];
    }
  }

  Future<int?> fetchTagIdByName(String name) async {
    try {
      final encoded = Uri.encodeComponent(name.trim());
      final rawBody = await _getRaw('/tags?search=$encoded');
      
      return await compute((String body) {
        final List<dynamic> raw = jsonDecode(body);
        if (raw.isNotEmpty) {
          for (var item in raw) {
            if ((item['name'] as String).toLowerCase() == name.trim().toLowerCase()) {
              return item['id'] as int;
            }
          }
        }
        return null;
      }, rawBody);
    } catch (_) {
      return null;
    }
  }

  /// Returns the total number of pages for a given category / search.
  /// Parses `X-WP-TotalPages` header from a HEAD request.
  Future<int> fetchTotalPages({
    int perPage = 10,
    int? categoryId,
    String? search,
    String? tagName,
  }) async {
    final queryParams = StringBuffer('?per_page=$perPage');
    if (categoryId != null && categoryId != 0) {
      queryParams.write('&categories=$categoryId');
    }
    if (search != null && search.isNotEmpty) {
      queryParams.write('&search=${Uri.encodeComponent(search)}');
    }
    if (tagName != null && tagName.isNotEmpty) {
      final tid = await fetchTagIdByName(tagName);
      if (tid != null) {
        queryParams.write('&tags=$tid');
      } else {
        return 0;
      }
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
