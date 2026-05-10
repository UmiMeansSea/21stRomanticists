import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:romanticists_app/providers/posts_provider.dart';
import 'package:romanticists_app/models/category.dart';
import 'package:romanticists_app/widgets/post_card.dart'; // PostCard + FeedCard + PostCardSkeleton + CategoryChip
import 'package:romanticists_app/app_theme.dart';
import 'package:romanticists_app/services/firebase_service.dart';
import 'package:romanticists_app/providers/auth_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _searchOpen = false;
  List<Map<String, dynamic>> _peopleResults = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Ensure data is loading
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final posts = context.read<PostsProvider>();
      if (posts.status == PostsStatus.initial) {
        posts.refresh();
      }
      _syncFollowing();
    });
  }

  Future<void> _syncFollowing() async {
    final auth = context.read<AuthProvider>();
    if (auth.user != null) {
      final following = await FirebaseService.instance.getFollowingIds(auth.user!.uid);
      if (mounted) {
        context.read<PostsProvider>().updateFollowingIds(following);
      }
    }
    
    // Precache first few images for smoother experience
    if (mounted) {
      final provider = context.read<PostsProvider>();
      final items = provider.feedItems;
      for (int i = 0; i < (items.length > 3 ? 3 : items.length); i++) {
        final url = items[i].imageUrl;
        if (url != null && url.isNotEmpty) {
          precacheImage(CachedNetworkImageProvider(url), context);
        }
      }
    }
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
    _searchPeople(value);
  }

  Future<void> _searchPeople(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _peopleResults = []);
      return;
    }
    final results = await FirebaseService.instance.searchUsers(query);
    if (mounted) setState(() => _peopleResults = results);
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
          icon: const Icon(Icons.sync_outlined, color: AppColors.primary),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Starting WordPress migration...')),
            );
            context.read<PostsProvider>().syncWithWordPress();
          },
          tooltip: 'Sync with WordPress',
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
    if (provider.status == PostsStatus.failure && provider.feedItems.isEmpty) {
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
    if (provider.feedItems.isEmpty) {
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
    final slivers = <Widget>[];

    // People results (shown above posts during search)
    if (_peopleResults.isNotEmpty) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'PEOPLE',
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.4,
                color: AppColors.outline,
              ),
            ),
          ),
        ),
      );
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final person = _peopleResults[i];
              final uid = person['uid'] as String? ?? '';
              final name = person['displayName'] as String? ?? 'Romanticist';
              final username = person['username'] as String? ?? '';
              final photo = person['photoURL'] as String?;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  backgroundImage: photo != null ? NetworkImage(photo) : null,
                  child: photo == null
                      ? Text(name[0].toUpperCase(),
                          style: GoogleFonts.ebGaramond(
                              fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary))
                      : null,
                ),
                title: Text(name, style: GoogleFonts.ebGaramond(fontSize: 16, fontWeight: FontWeight.w600)),
                subtitle: username.isNotEmpty
                    ? Text('@$username', style: GoogleFonts.inter(fontSize: 12, color: AppColors.outline))
                    : null,
                trailing: const Icon(Icons.chevron_right, color: AppColors.outline),
                onTap: () => context.push('/user/$uid?name=$name'),
              );
            },
            childCount: _peopleResults.length,
          ),
        ),
      );
      slivers.add(
        const SliverToBoxAdapter(
          child: Divider(height: 1, indent: 16, endIndent: 16),
        ),
      );
    }

    // Partial error indicator (WP failed but we have submissions, or vice-versa)
    if (provider.hasWpError || provider.hasSubError) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.error.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 20,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      provider.hasWpError 
                          ? 'Failed to load some articles. Showing community posts only.' 
                          : 'Failed to load community posts. Showing articles only.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Feed items (WP posts + community submissions merged)
    final items = provider.feedItems;
    slivers.add(
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
              if (index == items.length) {
                return _ListFooter(
                  isLoading: provider.isLoadingMore,
                  hasMore: provider.hasMore,
                );
              }
              final item = items[index];
              final isFeatured = index == 0 &&
                  provider.searchQuery.isEmpty &&
                  _peopleResults.isEmpty;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FeedCard(
                  item: item,
                  featured: isFeatured,
                ),
              );
            },
            childCount: items.length + 1,
          ),
        ),
      ),
    );
    return slivers;
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
