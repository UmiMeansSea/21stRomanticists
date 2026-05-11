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
import 'package:romanticists_app/services/engagement_service.dart';

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

  bool _filterAnonymous = false;
  String? _selectedTag;
  List<String> _wpTags = [];

  // [New State for Navigation]
  int _scrollToTopCounter = 0;

  // Guard against concurrent background revalidation calls
  bool _isFetchingFresh = false;

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
  bool get filterAnonymous => _filterAnonymous;
  String? get selectedTag => _selectedTag;
  int get scrollToTopCounter => _scrollToTopCounter;

  List<String> get allTags {
    final tags = <String>{};
    
    // FIX 2: Tag normalization (Unify by lowercase using a Set)
    for (var tag in _wpTags) {
      _addTag(tags, tag);
    }
    for (var sub in _submissions) {
      for (var tag in sub.tags) {
        _addTag(tags, tag);
      }
    }
    return tags.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  void _addTag(Set<String> set, String tag) {
    if (tag.trim().isEmpty) return;
    final normalized = tag.trim();
    // We want to keep original casing if possible, but unify by lowercase
    // Check if a similar tag (case-insensitive) already exists
    final exists = set.any((t) => t.toLowerCase() == normalized.toLowerCase());
    if (!exists) {
      // Capitalize first letter for display consistency if it's all lowercase
      final display = (normalized == normalized.toLowerCase() && normalized.length > 1)
        ? normalized[0].toUpperCase() + normalized.substring(1)
        : normalized;
      set.add(display);
    }
  }

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
    
    // 1. Map WordPress posts to FeedItems
    final wpItems = _posts
        .where((p) => !migratedWpIds.contains(p.id))
        .where((p) {
          // Filter by Anonymous (WP posts are never anonymous in the submission sense)
          if (_filterAnonymous) return false;
          
          // Filter by Tag
          if (_selectedTag != null) {
            final normalizedTag = _selectedTag!.toLowerCase();
            return p.tagNames.any((t) => t.toLowerCase() == normalizedTag);
          }
          
          // Filter by Category
          if (_selectedCategory == null || _selectedCategory!.id == 0) return true;
          
          // WP posts only show up in their specific categories
          return p.categories.contains(_selectedCategory!.id);
        })
        .map((p) => FeedItem.fromPost(p, categoryLabel: _catLabel(p)))
        .toList();
    
    // 2. Map all Firestore submissions to FeedItems, filtering locally
    final subItems = _submissions.where((s) {
      // 1. Filter by Anonymous
      if (_filterAnonymous && !s.isAnonymous) return false;

      // 2. Filter by Tag
      if (_selectedTag != null) {
        final normalizedTag = _selectedTag!.toLowerCase();
        if (!s.tags.any((t) => t.toLowerCase() == normalizedTag)) return false;
      }

      // 3. Filter by Category
      if (_selectedCategory == null || _selectedCategory!.id == 0) return true;
      
      final subCat = s.category.label.toLowerCase();
      final selectedCat = _selectedCategory!.name.toLowerCase();
      
      if (selectedCat == 'prose' && subCat == 'prose') return true;
      if (selectedCat == 'poems' && subCat == 'poems') return true;
      if (selectedCat == 'poetry' && subCat == 'poems') return true;
      
      return subCat == selectedCat;
    }).map((s) => FeedItem.fromSubmission(s)).toList();

    final merged = [...wpItems, ...subItems];
    _sortFeed(merged);
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
    // Load categories/tags in parallel (fast, can be cached later too)
    unawaited(Future.wait([_loadCategories(), _loadTags()]));

    // ── STEP A: Show cached posts INSTANTLY ───────────────────────────────────
    // This makes the UI appear full and usable within ~1 frame.
    final cached = await _api.readCachedPosts();
    if (cached.isNotEmpty) {
      _posts = cached;
      _status = PostsStatus.success;
      notifyListeners();
    }

    // ── STEP B: Silently fetch Firestore submissions ──────────────────────────
    unawaited(_fetchSubmissions());

    // ── STEP C: Silently revalidate WP posts from network ─────────────────────
    // Only show loading spinner if cache was empty (first launch).
    if (cached.isEmpty) {
      _status = PostsStatus.loading;
      notifyListeners();
    }
    await _revalidateWpPosts();
  }

  /// Fetches fresh WP posts from the network (page 1).
  /// Compares with current cache; if new posts exist, inserts them at the top.
  Future<void> _revalidateWpPosts() async {
    if (_isFetchingFresh) return;
    _isFetchingFresh = true;
    try {
      _totalPages = await _api.fetchTotalPages();
      final fresh = await _api.fetchPosts(page: 1);

      if (fresh.isEmpty) {
        if (_posts.isEmpty) _status = PostsStatus.failure;
        return;
      }

      // ── STEP C: Compare fresh vs. cached ─────────────────────────────────
      // Find posts whose IDs are NOT in the current local list.
      final existingIds = _posts.map((p) => p.id).toSet();
      final newPosts = fresh.where((p) => !existingIds.contains(p.id)).toList();

      if (newPosts.isNotEmpty) {
        // Inject new posts at the TOP of the feed.
        _posts = [...newPosts, ..._posts];
      } else {
        // Even if no new posts, update existing ones with fresh data
        // (e.g. updated titles, images from WP edits).
        final freshById = {for (final p in fresh) p.id: p};
        _posts = _posts.map((p) => freshById[p.id] ?? p).toList();
      }

      // Overwrite disk cache with latest data.
      unawaited(_api.writeCachedPosts(fresh));

      _status = PostsStatus.success;
    } catch (e) {
      debugPrint('WP revalidation failed: $e');
      // Keep showing cached data; don't change status if we already have posts.
      if (_posts.isEmpty) _status = PostsStatus.failure;
    } finally {
      _isFetchingFresh = false;
      notifyListeners();
    }
  }

  Future<void> _fetchSubmissions() async {
    try {
      _submissions = await FirebaseService.instance.getPublishedSubmissions();
      notifyListeners();
    } catch (e) {
      debugPrint('Firestore submissions failed: $e');
    }
  }

  Future<void> _loadTags() async {
    try {
      _wpTags = await _api.fetchTags();
      notifyListeners();
    } catch (_) {}
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

  // ─── Load Posts (pagination + filter reloads) ──────────────────────────────
  Future<void> _loadPosts({bool reset = false}) async {
    if (_status == PostsStatus.loading && !reset) return;

    if (reset) {
      _currentPage = 1;
      // Don't clear _posts immediately on reset if we have cache — show stale.
      if (_posts.isEmpty) {
        _status = PostsStatus.loading;
        notifyListeners();
      }
    }

    try {
      // 1. Fetch WordPress posts
      try {
        final categoryId = _selectedCategory?.id;
        List<Post> results;

        if (_searchQuery.isNotEmpty) {
          results = await _api.searchPosts(_searchQuery, page: _currentPage);
        } else {
          _totalPages = await _api.fetchTotalPages(
            categoryId: categoryId == 0 ? null : categoryId,
            search: _searchQuery.isEmpty ? null : _searchQuery,
            tagName: _selectedTag,
          );
          results = await _api.fetchPosts(
            page: _currentPage,
            categoryId: categoryId == 0 ? null : categoryId,
            tagName: _selectedTag,
          );
        }
        // FIX 3: Deduplicate posts (Avoid overlapping items from pagination)
        final existingIds = _posts.map((p) => p.id).toSet();
        final deduplicatedResults = results.where((p) => !existingIds.contains(p.id)).toList();
        _posts = reset ? results : [..._posts, ...deduplicatedResults];

        // Only update the disk cache when fetching unfiltered page 1
        if (reset && _selectedCategory == null && _selectedTag == null && _searchQuery.isEmpty) {
          unawaited(_api.writeCachedPosts(results));
        }
      } catch (e) {
        debugPrint('WP load failed: $e');
        if (reset) _posts = _posts.isEmpty ? [] : _posts; // keep stale
      }

      // 2. Fetch Firestore submissions (only on reset)
      if (reset) {
        try {
          _submissions = await FirebaseService.instance.getPublishedSubmissions();
        } catch (e) {
          debugPrint('Firestore load failed: $e');
          _submissions = [];
        }
      }

      _status = feedItems.isEmpty ? PostsStatus.failure : PostsStatus.success;
    } catch (e) {
      _status = feedItems.isEmpty ? PostsStatus.failure : PostsStatus.success;
    } finally {
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
  /// Increments the scroll counter to signal HomeScreen to scroll to top.
  void requestScrollToTop() {
    _scrollToTopCounter++;
    notifyListeners();
  }

  /// Pull-to-refresh: show stale data, revalidate silently in background.
  Future<void> refresh() async {
    _currentPage = 1;
    await Future.wait([_revalidateWpPosts(), _fetchSubmissions()]);
  }

  Future<void> loadMore() async {
    if (!hasMore || isLoadingMore) return;
    _currentPage++;
    await _loadPosts(reset: false);
  }

  void selectCategory(Category? category) {
    // Always reset other filters when a category is selected
    _searchQuery = '';
    _selectedTag = null;
    _filterAnonymous = false;

    if (_selectedCategory == category) {
      notifyListeners(); // Still notify to update UI (clearing filters)
      return;
    }
    
    _selectedCategory = category;
    _loadPosts(reset: true);
  }

  void toggleAnonymousFilter() {
    _filterAnonymous = !_filterAnonymous;
    if (_filterAnonymous) {
      _selectedTag = null;
      _selectedCategory = null;
      _searchQuery = '';
    }
    notifyListeners();
  }

  void selectTag(String? tag) {
    if (_selectedTag == tag) return;
    _selectedTag = tag;
    if (_selectedTag != null) {
      _filterAnonymous = false;
      _selectedCategory = null;
      _searchQuery = '';
    }
    // FRESH LOAD when tag changes to ensure we get all posts from WP
    _loadPosts(reset: true);
  }

  void search(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _selectedCategory = null;
    _selectedTag = null;
    _filterAnonymous = false;
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

  Future<void> toggleLike(FeedItem item) async {
    if (_currentUserId == null) return;

    Submission? sub;
    if (item.isSubmission) {
      sub = item.submission;
    } else if (item.wpPost != null) {
      // Migrate WP post on-the-fly if needed
      await FirebaseService.instance.migrateWordPressPost(item.wpPost!);
      // Re-fetch to get the newly created submission
      final results = await FirebaseService.instance.getPublishedSubmissions();
      sub = results.firstWhere((s) => s.wpId == item.wpPost!.id);
      _submissions.add(sub);
      notifyListeners();
    }

    if (sub == null) return;

    final index = _submissions.indexWhere((s) => s.id == sub?.id);
    if (index == -1) return;

    final wasLiked = sub.isLiked;
    final newIsLiked = !wasLiked;
    final newLikeCount = sub.likeCount + (newIsLiked ? 1 : -1);

    // Optimistic update
    _submissions[index] = sub.copyWith(
      isLiked: newIsLiked,
      likeCount: newLikeCount,
    );
    notifyListeners();

    try {
      if (newIsLiked) {
        await EngagementService.instance.likePost(_currentUserId!, sub.id!, sub.userId);
      } else {
        await EngagementService.instance.unlikePost(_currentUserId!, sub.id!);
      }
    } catch (e) {
      // Revert on error
      _submissions[index] = sub.copyWith(
        isLiked: wasLiked,
        likeCount: sub.likeCount,
      );
      notifyListeners();
    }
  }

  Future<void> toggleReshare(FeedItem item) async {
    if (_currentUserId == null) return;

    Submission? sub;
    if (item.isSubmission) {
      sub = item.submission;
    } else if (item.wpPost != null) {
      await FirebaseService.instance.migrateWordPressPost(item.wpPost!);
      final results = await FirebaseService.instance.getPublishedSubmissions();
      sub = results.firstWhere((s) => s.wpId == item.wpPost!.id);
      _submissions.add(sub);
      notifyListeners();
    }

    if (sub == null || sub.isReshared) return;

    final index = _submissions.indexWhere((s) => s.id == sub!.id);
    if (index == -1) return;

    // Optimistic update
    _submissions[index] = sub.copyWith(
      isReshared: true,
      reshareCount: sub.reshareCount + 1,
    );
    notifyListeners();

    try {
      await EngagementService.instance.restackPost(
        _currentUserId!,
        sub.id!,
        authorUid: sub.userId,
        postTitle: sub.title,
      );
    } catch (e) {
      // Revert on error
      _submissions[index] = sub.copyWith(
        isReshared: false,
        reshareCount: sub.reshareCount,
      );
      notifyListeners();
    }
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
