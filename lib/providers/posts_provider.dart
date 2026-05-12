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

import 'package:romanticists_app/repositories/post_repository.dart';
import 'package:romanticists_app/repositories/wp_post_repository.dart';

enum PostsStatus { initial, loading, loadingMore, success, failure }

/// Manages the merged home feed: WordPress posts + Firestore community
/// submissions. Pagination applies to WP posts only; submissions are loaded
/// in full (≤30) and merged into the sorted result.
class PostsProvider extends ChangeNotifier {
  final IPostRepository firebaseRepository;
  final WpPostRepository wpRepository;

  PostsProvider({
    required this.firebaseRepository,
    required this.wpRepository,
  }) {
    _init();
  }

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
  String? _activeFilter; // New state for sidebar/tag filtering

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
  String? get activeFilter => _activeFilter;

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
    final exists = set.any((t) => t.toLowerCase() == normalized.toLowerCase());
    if (!exists) {
      final display = (normalized == normalized.toLowerCase() && normalized.length > 1)
        ? normalized[0].toUpperCase() + normalized.substring(1)
        : normalized;
      set.add(display);
    }
  }

  /// Merged, sorted feed of WP posts + community submissions.
  List<FeedItem> get feedItems {
    // 1. Combine all sources into one master list
    final allItems = [
      ..._posts.map((p) => FeedItem.fromPost(p, categoryLabel: _catLabel(p))),
      ..._submissions.map((s) => FeedItem.fromSubmission(s)),
    ];

    // 2. Apply search filter if active
    if (_searchQuery.isNotEmpty) {
      final filtered = allItems.where((item) {
        return item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               item.authorName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
      _sortFeed(filtered);
      return filtered;
    }

    // 3. Apply Sidebar/Tag filter if active (New activeFilter state)
    if (_activeFilter != null) {
      final normalizedFilter = _activeFilter!.toLowerCase();
      
      final filtered = allItems.where((item) {
        // Special case: Anonymous Sidebar Filter
        if (normalizedFilter == 'anonymous') {
          return item.isAnonymous;
        }

        // Match by category label
        final categoryMatch = item.categoryLabel.toLowerCase() == normalizedFilter;
        
        // Match by tags
        final tagMatch = item.tags.any((t) => t.toLowerCase() == normalizedFilter);
        
        // Special case for 'Poetry' mapping to 'Poems'
        final poetryMatch = (normalizedFilter == 'poetry' || normalizedFilter == 'poems') && 
                           (item.categoryLabel.toLowerCase() == 'poems' || item.categoryLabel.toLowerCase() == 'poetry');

        return categoryMatch || tagMatch || poetryMatch;
      }).toList();
      _sortFeed(filtered);
      return filtered;
    }

    // 4. Fallback to existing manual filters (Category chips / Anonymous toggle)
    final migratedWpIds = _submissions
        .where((s) => s.wpId != null)
        .map((s) => s.wpId!)
        .toSet();
    
    final wpItems = _posts
        .where((p) => !migratedWpIds.contains(p.id))
        .where((p) {
          if (_filterAnonymous) return false;
          if (_selectedTag != null) {
            final normalizedTag = _selectedTag!.toLowerCase();
            return p.tagNames.any((t) => t.toLowerCase() == normalizedTag);
          }
          if (_selectedCategory == null || _selectedCategory!.id == 0) return true;
          return p.categories.contains(_selectedCategory!.id);
        })
        .map((p) => FeedItem.fromPost(p, categoryLabel: _catLabel(p)))
        .toList();
    
    final subItems = _submissions.where((s) {
      if (_filterAnonymous && !s.isAnonymous) return false;
      if (_selectedTag != null) {
        final normalizedTag = _selectedTag!.toLowerCase();
        if (!s.tags.any((t) => t.toLowerCase() == normalizedTag)) return false;
      }
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
    _status = PostsStatus.loading;
    _errorMessage = null;
    
    // Load categories/tags in parallel
    unawaited(Future.wait([_loadCategories(), _loadTags()]));

    // ── STEP A: Show cached posts INSTANTLY ───────────────────────────────────
    final cached = await wpRepository.getCachedPosts();
    if (cached.isNotEmpty) {
      _posts = cached.whereType<Post>().toList();
      _status = PostsStatus.success;
      notifyListeners();
    }

    // ── STEP B: Silently fetch Firestore submissions ──────────────────────────
    unawaited(_fetchSubmissions());

    // ── STEP C: Revalidate WP posts from network ─────────────────────────────
    // If we have cached posts, we stay in 'success' but fetch silently.
    // If cache is empty, we stay in 'loading' until network responds.
    await _fetchWpPosts();
  }

  /// Fetches fresh WP posts from the network (page 1).
  /// Renamed from _revalidateWpPosts to match architectural requirement.
  Future<void> _fetchWpPosts() async {
    if (_isFetchingFresh) return;
    _isFetchingFresh = true;
    
    // Clear error message at start of network fetch
    _errorMessage = null;

    try {
      _totalPages = await wpRepository.fetchTotalPages();
      final fresh = await wpRepository.fetchPosts(page: 1);

      if (fresh.isEmpty) {
        // Only fail if we have NO data at all (cache empty + network empty)
        if (_posts.isEmpty && _submissions.isEmpty) {
          _status = PostsStatus.failure;
          _errorMessage = 'No posts found.';
        }
        return;
      }

      // Merge fresh items into local list
      final existingIds = _posts.map((p) => p.id).toSet();
      final newPosts = fresh.map((e) => e.wpPost).whereType<Post>()
          .where((p) => !existingIds.contains(p.id)).toList();

      if (newPosts.isNotEmpty) {
        _posts = [...newPosts, ..._posts];
      } else {
        final freshById = {for (final e in fresh) if (e.wpPost != null) e.wpPost!.id: e.wpPost!};
        _posts = _posts.map((p) => freshById[p.id] ?? p).cast<Post>().toList();
      }

      unawaited(wpRepository.cachePosts(fresh));
      _status = PostsStatus.success;
    } catch (e) {
      debugPrint('WP fetch failed: $e');
      // Only set failure if we have no data to show
      if (_posts.isEmpty && _submissions.isEmpty) {
        _status = PostsStatus.failure;
        _errorMessage = 'Network error. Please check your connection.';
      }
    } finally {
      _isFetchingFresh = false;
      notifyListeners();
    }
  }

  Future<void> _fetchSubmissions() async {
    try {
      final items = await firebaseRepository.fetchPosts();
      _submissions = items.map((e) => e.submission).whereType<Submission>().toList();
      notifyListeners();
    } catch (e) {
      debugPrint('Firestore submissions failed: $e');
    }
  }

  Future<void> _loadTags() async {
    try {
      _wpTags = await wpRepository.fetchTags();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await wpRepository.fetchCategories();
      _categories = [
        const Category(id: 0, name: 'All', slug: 'all', count: 0),
        ...cats.whereType<Category>(),
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
          final res = await wpRepository.fetchPosts(search: _searchQuery, page: _currentPage);
          results = res.map((e) => e.wpPost).whereType<Post>().toList();
        } else {
          _totalPages = await wpRepository.fetchTotalPages(
            categoryId: categoryId == 0 ? null : categoryId,
            search: _searchQuery.isEmpty ? null : _searchQuery,
            tagName: _selectedTag,
          );
          final res = await wpRepository.fetchPosts(
            page: _currentPage,
            categoryId: categoryId == 0 ? null : categoryId,
            tagName: _selectedTag,
          );
          results = res.map((e) => e.wpPost).whereType<Post>().toList();
        }
        // FIX 3: Deduplicate posts (Avoid overlapping items from pagination)
        final existingIds = _posts.map((p) => p.id).toSet();
        final deduplicatedResults = results.where((p) => !existingIds.contains(p.id)).toList();
        _posts = reset ? results : [..._posts, ...deduplicatedResults];

        // Only update the disk cache when fetching unfiltered page 1
        if (reset && _selectedCategory == null && _selectedTag == null && _searchQuery.isEmpty) {
          final feedItemsToCache = results.map((p) => FeedItem.fromPost(p, categoryLabel: _catLabel(p))).toList();
          unawaited(wpRepository.cachePosts(feedItemsToCache));
        }
      } catch (e) {
        debugPrint('WP load failed: $e');
        if (reset) _posts = _posts.isEmpty ? [] : _posts; // keep stale
      }

      // 2. Fetch Firestore submissions (only on reset)
      if (reset) {
        try {
          final items = await firebaseRepository.fetchPosts();
          _submissions = items.map((e) => e.submission).whereType<Submission>().toList();
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
      final restacks = await firebaseRepository.getRestacksFromFollowedUsers(_followingIds);
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
    await Future.wait([_fetchWpPosts(), _fetchSubmissions()]);
  }

  void setFilter(String filter) {
    _activeFilter = filter;
    // Reset other specific filters when using the sidebar
    _selectedCategory = null;
    _selectedTag = null;
    _filterAnonymous = false;
    _searchQuery = '';
    notifyListeners();
  }

  void clearFilters() {
    _activeFilter = null;
    _selectedCategory = null;
    _selectedTag = null;
    _filterAnonymous = false;
    _searchQuery = '';
    notifyListeners();
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
    notifyListeners(); // [INSTANT] Show existing local items matching this category
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
    notifyListeners(); // [INSTANT] Show existing local items matching this tag
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

  /// Removes a post from local state instantly.
  void removePostLocally(String postId) {
    _submissions.removeWhere((s) => s.id == postId);
    notifyListeners();
  }

  Future<void> toggleLike(FeedItem item) async {
    if (_currentUserId == null) return;

    Submission? sub;
    if (item.isSubmission) {
      sub = item.submission;
    } else if (item.wpPost != null) {
      // Migrate WP post on-the-fly if needed
      await firebaseRepository.migrateWordPressPost(item.wpPost!);
      // Re-fetch to get the newly created submission
      final results = await firebaseRepository.fetchPosts();
      sub = results.map((e) => e.submission).whereType<Submission>().firstWhere((s) => s.wpId == item.wpPost!.id);
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
      await EngagementService.instance.toggleLike(_currentUserId!, sub.id!, wasLiked);
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
      await firebaseRepository.migrateWordPressPost(item.wpPost!);
      final results = await firebaseRepository.fetchPosts();
      sub = results.map((e) => e.submission).whereType<Submission>().firstWhere((s) => s.wpId == item.wpPost!.id);
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
      await EngagementService.instance.toggleRepost(
        _currentUserId!,
        sub.id!,
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
      final wpPosts = await wpRepository.fetchPosts(page: 1);
      for (final post in wpPosts.whereType<Post>()) {
        await firebaseRepository.migrateWordPressPost(post);
      }
      // After sync, refresh the feed from Firebase
      await refresh();
    } catch (_) {}
  }
}
