import 'dart:async';
import 'package:flutter/foundation.dart' hide Category;
import 'package:romanticists_app/models/post.dart';
import 'package:romanticists_app/models/category.dart';
import 'package:romanticists_app/services/wp_api.dart';

enum PostsStatus { initial, loading, loadingMore, success, failure }

/// Manages posts list state: pagination, category filter, search.
class PostsProvider extends ChangeNotifier {
  PostsProvider() {
    _init();
  }

  final WpApiService _api = WpApiService.instance;

  // ─── State ─────────────────────────────────────────────────────────────────
  List<Post> _posts = [];
  List<Category> _categories = [];
  Category? _selectedCategory;
  PostsStatus _status = PostsStatus.initial;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 1;
  String _searchQuery = '';
  List<String> _followingIds = [];

  // ─── Getters ───────────────────────────────────────────────────────────────
  List<Post> get posts => List.unmodifiable(_posts);
  List<Category> get categories => List.unmodifiable(_categories);
  Category? get selectedCategory => _selectedCategory;
  PostsStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _currentPage < _totalPages;
  bool get isLoading => _status == PostsStatus.loading;
  bool get isLoadingMore => _status == PostsStatus.loadingMore;
  String get searchQuery => _searchQuery;
  List<String> get followingIds => _followingIds;

  // ─── Initialization ────────────────────────────────────────────────────────
  Future<void> _init() async {
    await Future.wait([
      _loadCategories(),
      _loadPosts(reset: true),
    ]);
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _api.fetchCategories();
      // Prepend "All" virtual category
      _categories = [
        const Category(id: 0, name: 'All', slug: 'all', count: 0),
        ...cats,
      ];
      notifyListeners();
    } catch (_) {
      // Categories are optional — fail silently
    }
  }

  // ─── Load Posts ────────────────────────────────────────────────────────────
  Future<void> _loadPosts({required bool reset}) async {
    if (reset) {
      _status = PostsStatus.loading;
      _currentPage = 1;
      _posts = [];
      _errorMessage = null;
    } else {
      _status = PostsStatus.loadingMore;
    }
    notifyListeners();

    try {
      final categoryId = _selectedCategory?.id;
      final search = _searchQuery.trim();

      final results = search.isNotEmpty
          ? await _api.searchPosts(search, page: _currentPage)
          : await _api.fetchPosts(
              page: _currentPage,
              categoryId: categoryId == 0 ? null : categoryId,
            );

      _totalPages = await _api.fetchTotalPages(
        categoryId: categoryId == 0 ? null : categoryId,
        search: search.isEmpty ? null : search,
      );

      _posts = [..._posts, ...results];

      // Prioritize posts from followed authors
      if (_followingIds.isNotEmpty && _searchQuery.isEmpty) {
        _posts.sort((a, b) {
          final aFollowed = _followingIds.contains(a.authorId.toString());
          final bFollowed = _followingIds.contains(b.authorId.toString());
          if (aFollowed && !bFollowed) return -1;
          if (!aFollowed && bFollowed) return 1;
          return b.publishedAt.compareTo(a.publishedAt); // secondary sort by date
        });
      }

      _status = PostsStatus.success;
      _errorMessage = null;
    } on WpApiException catch (e) {
      _status = PostsStatus.failure;
      _errorMessage = e.message;
    } catch (e) {
      _status = PostsStatus.failure;
      _errorMessage = 'Something went wrong. Please try again.';
    }

    notifyListeners();
  }

  // ─── Public Actions ────────────────────────────────────────────────────────
  Future<void> refresh() => _loadPosts(reset: true);

  Future<void> loadMore() async {
    if (!hasMore || isLoadingMore) return;
    _currentPage++;
    await _loadPosts(reset: false);
  }

  void selectCategory(Category? category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    _searchQuery = '';
    _loadPosts(reset: true);
  }

  void search(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _selectedCategory = null;
    _loadPosts(reset: true);
  }

  void clearSearch() {
    if (_searchQuery.isEmpty) return;
    _searchQuery = '';
    _loadPosts(reset: true);
  }

  void updateFollowingIds(List<String> ids) {
    _followingIds = ids;
    if (_posts.isNotEmpty) {
      // Re-sort current posts
      _posts.sort((a, b) {
        final aFollowed = _followingIds.contains(a.authorId.toString());
        final bFollowed = _followingIds.contains(b.authorId.toString());
        if (aFollowed && !bFollowed) return -1;
        if (!aFollowed && bFollowed) return 1;
        return b.publishedAt.compareTo(a.publishedAt);
      });
      notifyListeners();
    }
  }
}
