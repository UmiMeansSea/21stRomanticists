import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/foundation.dart' hide Category;
import 'package:romanticists_app/models/post.dart';
import 'package:romanticists_app/models/category.dart';
import 'package:romanticists_app/models/feed_item.dart';
import 'package:romanticists_app/models/submission.dart';
import 'package:romanticists_app/services/wp_api.dart';
import 'package:romanticists_app/services/firebase_service.dart';
import 'package:romanticists_app/services/read_status_service.dart';

enum PostsStatus { initial, loading, loadingMore, success, failure }

/// Manages the merged home feed: WordPress posts + Firestore community
/// submissions. Pagination applies to WP posts only; submissions are loaded
/// in full (≤30) and merged into the sorted result.
class PostsProvider extends ChangeNotifier {
  PostsProvider() {
    _init();
  }

  final WpApiService _api = WpApiService.instance;

  // ─── State ─────────────────────────────────────────────────────────────────
  List<Post> _posts = [];
  List<Submission> _submissions = [];
  List<Category> _categories = [];
  Category? _selectedCategory;
  PostsStatus _status = PostsStatus.initial;
  bool _isLoadingMore = false;
  String? _errorMessage;
  bool _wpError = false;
  bool _subError = false;
  int _currentPage = 1;
  int _totalPages = 1;
  String _searchQuery = '';
  List<String> _followingIds = [];
  Set<String> _readPostIds = {};
  String? _currentUserId;
  Set<String> _followedRestackIds = {}; // Post IDs restacked by people I follow

  // ─── Getters ───────────────────────────────────────────────────────────────
  List<Category> get categories => List.unmodifiable(_categories);
  Category? get selectedCategory => _selectedCategory;
  PostsStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get hasWpError => _wpError;
  bool get hasSubError => _subError;
  bool get hasMore => _currentPage < _totalPages;
  bool get isLoading => _status == PostsStatus.loading;
  bool get isLoadingMore => _status == PostsStatus.loadingMore;
  String get searchQuery => _searchQuery;
  List<String> get followingIds => _followingIds;
  Set<String> get readPostIds => _readPostIds;

  /// Merged, sorted feed of WP posts + community submissions.
  List<FeedItem> get feedItems {
    // When searching, show both
    if (_searchQuery.isNotEmpty) {
      final wpItems = _posts.map((p) => FeedItem.fromPost(p, categoryLabel: _catLabel(p))).toList();
      // Only show submissions if they match search (client-side filter for now)
      final subItems = _submissions
          .where((s) => s.title.toLowerCase().contains(_searchQuery.toLowerCase()))
          .map((s) => FeedItem.fromSubmission(s))
          .toList();
      final merged = [...wpItems, ...subItems];
      _sortFeed(merged);
      return merged;
    }

    // Identify which WP IDs are already in Firestore to avoid duplicates
    final migratedWpIds = _submissions
        .where((s) => s.wpId != null)
        .map((s) => s.wpId!)
        .toSet();
    
    debugPrint('PostsProvider: Migrated WP IDs count: ${migratedWpIds.length}');

    // 1. Map WordPress posts to FeedItems, but ONLY those that haven't been migrated yet
    final wpItems = _posts
        .where((p) => !migratedWpIds.contains(p.id))
        .map((p) => FeedItem.fromPost(p, categoryLabel: _catLabel(p)))
        .toList();
    
    // 2. Map all Firestore submissions to FeedItems, filtering by category locally
    final subItems = _submissions.where((s) {
      if (_selectedCategory == null || _selectedCategory!.id == 0) return true;
      
      // Map submission category to WordPress category name
      final subCat = s.category.label.toLowerCase();
      final selectedCat = _selectedCategory!.name.toLowerCase();
      
      // Support common mappings
      if (selectedCat == 'prose' && subCat == 'prose') return true;
      if (selectedCat == 'poems' && subCat == 'poems') return true;
      if (selectedCat == 'poetry' && subCat == 'poems') return true;
      
      return subCat == selectedCat;
    }).map((s) => FeedItem.fromSubmission(s)).toList();

    debugPrint('PostsProvider: WP items: ${wpItems.length}, Sub items: ${subItems.length}');

    final merged = [...wpItems, ...subItems];
    _sortFeed(merged);
    
    debugPrint('PostsProvider: Final merged items: ${merged.length}');
    if (merged.isEmpty && _posts.isNotEmpty) {
      debugPrint('PostsProvider WARNING: Feed is empty despite having posts! Filtering might be too aggressive.');
    }
    
    return merged;
  }

  String _catLabel(Post p) {
    for (final c in _categories) {
      if (c.id != 0 && p.categories.contains(c.id)) return c.name;
    }
    return '';
  }

  void _sortFeed(List<FeedItem> items) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    items.sort((a, b) {
      final aSubmission = a.submission;
      final bSubmission = b.submission;

      // Fallback to simple date sorting for WP posts for now
      if (aSubmission == null || bSubmission == null) {
        return b.publishedAt.compareTo(a.publishedAt);
      }

      // ─── Calculate Priority Weights ───────────────────────────────────────────
      double aWeight = 0;
      double bWeight = 0;

      // 1. Self Priority
      if (currentUserId != null) {
        if (aSubmission.userId == currentUserId) aWeight += 50;
        if (bSubmission.userId == currentUserId) bWeight += 50;
      }

      // 2. Restack Priority
      if (_followedRestackIds.contains('sub_${aSubmission.id}')) aWeight += 30;
      if (_followedRestackIds.contains('sub_${bSubmission.id}')) bWeight += 30;

      // 3. Subscription Priority
      if (_followingIds.contains(aSubmission.userId ?? '')) aWeight += 20;
      if (_followingIds.contains(bSubmission.userId ?? '')) bWeight += 20;

      // ─── Calculate Engagement Ratio ───────────────────────────────────────────
      // Formula: (Likes + Comments + Reshares) / max(1, Views)
      final aEngagement = (aSubmission.likeCount + aSubmission.commentCount + aSubmission.reshareCount) /
          (aSubmission.viewCount > 0 ? aSubmission.viewCount.toDouble() : 1.0);
      final bEngagement = (bSubmission.likeCount + bSubmission.commentCount + bSubmission.reshareCount) /
          (bSubmission.viewCount > 0 ? bSubmission.viewCount.toDouble() : 1.0);

      // ─── Calculate Time Decay ─────────────────────────────────────────────────
      final now = DateTime.now();
      final aAgeHours = now.difference(a.publishedAt).inHours.toDouble();
      final bAgeHours = now.difference(b.publishedAt).inHours.toDouble();

      // Simple decay: 1 / (1 + age_in_hours * 0.1)
      final aDecay = 1.0 / (1.0 + aAgeHours * 0.1);
      final bDecay = 1.0 / (1.0 + bAgeHours * 0.1);

      // ─── Final Score ──────────────────────────────────────────────────────────
      final aScore = aWeight * aDecay + aEngagement;
      final bScore = bWeight * bDecay + bEngagement;

      return bScore.compareTo(aScore);
    });
  }

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
      _categories = [
        const Category(id: 0, name: 'All', slug: 'all', count: 0),
        ...cats,
      ];
      notifyListeners();
    } catch (_) {}
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

      // ── WP Posts ──
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

      // ── Firestore submissions (only on first page load, not paginated) ──
      if (reset && search.isEmpty) {
        debugPrint('PostsProvider: Loading submissions from Firestore...');
        _submissions = await FirebaseService.instance.getPublishedSubmissions();
        debugPrint('PostsProvider: Loaded ${_submissions.length} submissions');
        await _loadFollowedRestacks();
      }

      _status = PostsStatus.success;
      _wpError = false;
      _subError = false;
    } on WpApiException catch (e) {
      _status = feedItems.isEmpty ? PostsStatus.failure : PostsStatus.success;
      _wpError = true;
      _errorMessage = e.message;
    } catch (e) {
      _status = feedItems.isEmpty ? PostsStatus.failure : PostsStatus.success;
      _subError = true;
      _errorMessage = 'An unexpected error occurred: $e';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> _loadFollowedRestacks() async {
    if (_currentUserId == null || _followingIds.isEmpty) {
      _followedRestackIds = {};
      return;
    }

    try {
      final restacks = await FirebaseService.instance.getRestacksFromFollowedUsers(_followingIds);
      _followedRestackIds = restacks.map((r) => 'sub_$r').toSet();
    } catch (_) {}
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
    notifyListeners();
  }

  void updateUserId(String? uid) {
    if (_currentUserId == uid) return;
    _currentUserId = uid;
    _loadReadHistory();
  }

  Future<void> _loadReadHistory() async {
    if (_currentUserId != null) {
      _readPostIds = await ReadStatusService.instance.getReadPostIds(_currentUserId!);
      notifyListeners();
    } else {
      _readPostIds = {};
      notifyListeners();
    }
  }

  /// Manually mark a post as read in the local state to update the feed immediately.
  void markAsReadLocally(String uniqueId) {
    if (_readPostIds.contains(uniqueId)) return;
    _readPostIds.add(uniqueId);
    notifyListeners();
  }

  /// Manually add a submission to local state for instant visibility.
  void addSubmissionLocally(Submission s) {
    // Check if already exists
    if (_submissions.any((existing) => existing.id == s.id)) return;
    
    _submissions = [s, ..._submissions];
    notifyListeners();
  }

  /// Migrates WordPress posts to Firebase and refreshes the feed.
  Future<void> syncWithWordPress() async {
    try {
      // Fetch latest posts to sync
      final wpPosts = await _api.fetchPosts(page: 1);
      for (final post in wpPosts) {
        await FirebaseService.instance.migrateWordPressPost(post);
      }
      // After sync, refresh the feed from Firebase
      await refresh();
    } catch (_) {}
  }
}
