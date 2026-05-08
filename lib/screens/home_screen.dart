import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:romanticists_app/providers/posts_provider.dart';
import 'package:romanticists_app/models/category.dart';
import 'package:romanticists_app/widgets/post_card.dart';
import 'package:romanticists_app/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Ensure data is loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PostsProvider>();
      if (provider.status == PostsStatus.initial) {
        provider.refresh();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<PostsProvider>().loadMore();
    }
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (!_searchOpen) {
      _searchController.clear();
      context.read<PostsProvider>().clearSearch();
    }
  }

  void _onSearch(String value) {
    context.read<PostsProvider>().search(value);
  }

  @override
  Widget build(BuildContext context) {
    // Consumer wraps the Scaffold — NOT inside slivers[] (which requires RenderSliver)
    return Consumer<PostsProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: RefreshIndicator(
            onRefresh: provider.refresh,
            displacement: 100,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                _buildAppBar(),
                _buildCategoryBar(provider),
                ..._buildBodySlivers(provider),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── AppBar ──────────────────────────────────────────────────────────────

  Widget _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      floating: false,
      backgroundColor: AppColors.background,
      elevation: 0,
      shadowColor: AppColors.outlineVariant.withValues(alpha: 0.3),
      leading: IconButton(
        icon: const Icon(Icons.menu, color: AppColors.primary),
        onPressed: () {},
        tooltip: 'Menu',
      ),
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _searchOpen
            ? _SearchField(
                controller: _searchController,
                onChanged: _onSearch,
                onClear: _toggleSearch,
              )
            : Text(
                'The 21st Romanticists',
                style: GoogleFonts.ebGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                  letterSpacing: -0.3,
                ),
              ),
      ),
      actions: [
        if (!_searchOpen)
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.primary),
            onPressed: _toggleSearch,
            tooltip: 'Search',
          ),
        IconButton(
          icon: const Icon(Icons.settings_outlined, color: AppColors.primary),
          onPressed: () => context.push('/settings'),
          tooltip: 'Settings',
        ),
      ],
    );
  }

  // ─── Category filter bar ─────────────────────────────────────────────────

  Widget _buildCategoryBar(PostsProvider provider) {
    if (provider.categories.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverPersistentHeader(
      pinned: true,
      delegate: _CategoryBarDelegate(
        child: _CategoryTabRow(
          categories: provider.categories.toList(),
          selected: provider.selectedCategory,
          onSelect: provider.selectCategory,
        ),
      ),
    );
  }

  // ─── Body Slivers (returns a list — safe to spread into slivers:[]) ─────────

  List<Widget> _buildBodySlivers(PostsProvider provider) {
    // ── Initial / loading ──
    if (provider.status == PostsStatus.initial ||
        provider.status == PostsStatus.loading) {
      return [
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          sliver: _SkeletonSliver(),
        ),
      ];
    }

    // ── Error with no data ──
    if (provider.status == PostsStatus.failure && provider.posts.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _ErrorView(
            message: provider.errorMessage ?? 'Failed to load posts.',
            onRetry: provider.refresh,
          ),
        ),
      ];
    }

    // ── Empty state ──
    if (provider.posts.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyView(
            query: provider.searchQuery,
            onClear: provider.clearSearch,
          ),
        ),
      ];
    }

    // ── Posts list ──
    return [
      SliverPadding(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 20,
          bottom: 120,
        ),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index == provider.posts.length) {
                return _ListFooter(
                  isLoading: provider.isLoadingMore,
                  hasMore: provider.hasMore,
                );
              }
              final post = provider.posts[index];
              final isFeatured = index == 0 && provider.searchQuery.isEmpty;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PostCard(
                  post: post,
                  categories: provider.categories.toList(),
                  featured: isFeatured,
                ),
              );
            },
            childCount: provider.posts.length + 1,
          ),
        ),
      ),
    ];
  }
}

// ─── Search field ────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      onChanged: onChanged,
      style: GoogleFonts.literata(fontSize: 16, color: AppColors.onSurface),
      decoration: InputDecoration(
        hintText: 'Search poems, prose…',
        hintStyle: GoogleFonts.literata(
          fontSize: 16,
          color: AppColors.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        suffixIcon: IconButton(
          icon: const Icon(Icons.close, size: 20),
          onPressed: onClear,
        ),
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

// ─── Category tab row ────────────────────────────────────────────────────────

class _CategoryTabRow extends StatelessWidget {
  final List<Category> categories;
  final Category? selected;
  final ValueChanged<Category?> onSelect;

  const _CategoryTabRow({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: categories.map((cat) {
                final isSelected = selected == null
                    ? cat.id == 0
                    : selected!.id == cat.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: CategoryChip(
                    label: cat.name,
                    selected: isSelected,
                    onTap: () => onSelect(cat.id == 0 ? null : cat),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1, thickness: 0.4),
        ],
      ),
    );
  }
}

// ─── List footer ─────────────────────────────────────────────────────────────

class _ListFooter extends StatelessWidget {
  final bool isLoading;
  final bool hasMore;

  const _ListFooter({required this.isLoading, required this.hasMore});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ),
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

// ─── Skeleton loading sliver ────────────────────────────────────────────────

class _SkeletonSliver extends StatelessWidget {
  const _SkeletonSliver();

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PostCardSkeleton(featured: i == 0),
        ),
        childCount: 6,
      ),
    );
  }
}

// ─── Error view ───────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 56, color: AppColors.outline.withValues(alpha: 0.5)),
            const SizedBox(height: 20),
            Text(
              'Unable to load posts',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final String query;
  final VoidCallback onClear;

  const _EmptyView({required this.query, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_outlined,
                size: 56, color: AppColors.outline.withValues(alpha: 0.4)),
            const SizedBox(height: 20),
            Text(
              query.isNotEmpty
                  ? 'No results for "$query"'
                  : 'No posts yet',
              style: Theme.of(context).textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            if (query.isNotEmpty) ...[
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: onClear,
                child: const Text('Clear Search'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── SliverPersistentHeaderDelegate for category bar ─────────────────────────

class _CategoryBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  const _CategoryBarDelegate({required this.child});

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(_, __, ___) => child;

  @override
  bool shouldRebuild(_CategoryBarDelegate old) => old.child != child;
}
