import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:romanticists_app/models/feed_item.dart';
import 'package:romanticists_app/models/post.dart';

class SearchUser {
  final String id;
  final String username;
  final String displayName;
  final String? photoUrl;

  SearchUser({
    required this.id,
    required this.username,
    required this.displayName,
    this.photoUrl,
  });

  factory SearchUser.fromJson(Map<String, dynamic> json) => SearchUser(
    id: json['id']?.toString() ?? '',
    username: json['username'] ?? '',
    displayName: json['displayName'] ?? '',
    photoUrl: json['photoUrl'],
  );
}

class SearchResults {
  final List<SearchUser> users;
  final List<FeedItem> posts;
  final List<String> tags;

  SearchResults({
    required this.users,
    required this.posts,
    required this.tags,
  });
}

// Background parsing function for compute()
SearchResults _parseSearchResponse(String body) {
  final data = jsonDecode(body);
  
  final users = (data['users'] as List? ?? [])
      .map((u) => SearchUser.fromJson(u))
      .toList();
      
  final posts = (data['posts'] as List? ?? [])
      .map((p) {
        // Map search result back to FeedItem for UI compatibility
        final isWp = p['id'].toString().startsWith('wp_');
        final id = p['id'].toString();
        
        return FeedItem(
          uniqueId: id,
          authorFirebaseId: '',
          authorName: p['username'] ?? 'Anonymous',
          title: p['title'] ?? '',
          excerpt: p['excerpt'] ?? '',
          imageUrl: p['jetpack_featured_media_url'],
          publishedAt: DateTime.now(),
          isSubmission: !isWp,
          categoryLabel: '',
          tags: (p['tags']?.toString().split(' ') ?? []),
          wpPost: isWp ? Post(
            id: int.tryParse(id.replaceFirst('wp_', '')) ?? 0,
            authorId: 0,
            title: p['title'] ?? '',
            content: '',
            excerpt: p['excerpt'] ?? '',
            author: p['username'] ?? '',
            imageUrl: p['jetpack_featured_media_url'] ?? '',
            publishedAt: DateTime.now(),
            categories: [],
            tagNames: [],
            slug: '',
            link: '',
          ) : null,
        );
      })
      .toList();
      
  final tags = List<String>.from(data['tags'] ?? []);
  
  return SearchResults(users: users, posts: posts, tags: tags);
}

class SearchProvider extends ChangeNotifier {
  static const String _baseUrl = 'https://21st-romanticists.vercel.app/api/search';
  
  bool _isLoading = false;
  String? _errorMessage;
  List<SearchUser> _userResults = [];
  List<FeedItem> _postResults = [];
  List<String> _tagResults = [];
  Timer? _debounceTimer;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<SearchUser> get userResults => _userResults;
  List<FeedItem> get postResults => _postResults;
  List<String> get tagResults => _tagResults;

  void onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    
    if (query.trim().length < 2) {
      _clearResults();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      performSearch(query);
    });
  }

  Future<void> performSearch(String query) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final uri = Uri.parse('$_baseUrl?q=${Uri.encodeComponent(query)}');
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final results = await compute(_parseSearchResponse, response.body);
        _userResults = results.users;
        _postResults = results.posts;
        _tagResults = results.tags;
      } else {
        _errorMessage = 'Search failed: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Connection error: $e';
      debugPrint('Search error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _clearResults() {
    _userResults = [];
    _postResults = [];
    _tagResults = [];
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
