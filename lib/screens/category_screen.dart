import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:romanticists_app/models/post.dart';
import 'package:romanticists_app/models/category.dart';
import 'package:romanticists_app/services/wp_api.dart';
import 'package:romanticists_app/widgets/post_card.dart';
import 'package:romanticists_app/app_theme.dart';

enum _ScreenStatus { loading, success, failure }

/// Displays posts for a single category, with infinite scroll pagination.
/// Receives [categoryId] and [categoryName] from GoRoute path params.
class CategoryScreen extends StatefulWidget {
  final int categoryId;
  final String categoryName;

  const CategoryScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final ScrollController _scroll = ScrollController();
  final WpApiService _api = WpApiService.instance;

  final List<Post> _posts = [];
  _ScreenStatus _status = _ScreenStatus.loading;
  String? _errorMessage;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _loadingMore = false;

  bool get _hasMore => _currentPage < _totalPages;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadPosts(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadPosts({required bool reset}) async {
    if (reset) {
      setState(() {
        _status = _ScreenStatus.loading;
        _currentPage = 1;
        _posts.clear();
        _errorMessage = null;
      });
    }
    try {
      final results = await _api.fetchPosts(
        page: _currentPage,
        categoryId: widget.categoryId,
      );
      final total = await _api.fetchTotalPages(categoryId: widget.categoryId);
      if (mounted) {
        setState(() {
          _posts.addAll(results);
          _totalPages = total;
          _status = _ScreenStatus.success;
          _loadingMore = false;
        });
      }
    } on WpApiException catch (e) {
      if (mounted) {
        setState(() {
          _status = _ScreenStatus.failure;
          _errorMessage = e.message;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _status = _ScreenStatus.failure;
          _errorMessage = 'Something went wrong. Please try again.';
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    setState(() {
      _loadingMore = true;
      _currentPage++;
    });
    await _loadPosts(reset: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        controller: _scroll,
        headerSliverBuilder: (_, innerScrolled) => [
          _buildAppBar(innerScrolled),
        ],
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildAppBar(bool innerScrolled) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.primary,
      elevation: innerScrolled ? 0.5 : 0,
      shadowColor: AppColors.outlineVariant.withValues(alpha: 0.3),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      title: Text(
        widget.categoryName,
        style: GoogleFonts.ebGaramond(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: AppColors.primary,
          letterSpacing: -0.3,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 0.4, color: AppColors.outlineVariant),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_status == _ScreenStatus.loading) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => PostCardSkeleton(featured: i == 0),
      );
    }

    if (_status == _ScreenStatus.failure && _posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_outlined,
                  size: 56,
                  color: AppColors.outline.withValues(alpha: 0.5)),
              const SizedBox(height: 20),
              Text('Unable to load posts',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(_errorMessage ?? 'An error occurred.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => _loadPosts(reset: true),
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_stories_outlined,
                  size: 56,
                  color: AppColors.outline.withValues(alpha: 0.4)),
              const SizedBox(height: 20),
              Text('No posts in ${widget.categoryName}',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    final cat = Category(
      id: widget.categoryId,
      name: widget.categoryName,
      slug: widget.categoryName.toLowerCase(),
      count: 0,
    );

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.background,
      strokeWidth: 1.5,
      onRefresh: () => _loadPosts(reset: true),
      child: ListView.separated(
        padding: const EdgeInsets.only(
            left: 16, right: 16, top: 20, bottom: 120),
        itemCount: _posts.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == _posts.length) {
            return _CategoryListFooter(
              isLoading: _loadingMore,
              hasMore: _hasMore,
            );
          }
          return PostCard(
            post: _posts[index],
            categories: [cat],
            featured: index == 0,
          );
        },
      ),
    );
  }
}

class _CategoryListFooter extends StatelessWidget {
  final bool isLoading;
  final bool hasMore;
  const _CategoryListFooter(
      {required this.isLoading, required this.hasMore});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
            child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 1.5))),
      );
    }
    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            '— fin —',
            style: GoogleFonts.ebGaramond(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: AppColors.outline,
              letterSpacing: 1,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
