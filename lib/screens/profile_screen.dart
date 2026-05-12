import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:romanticists_app/app_theme.dart';
import 'package:romanticists_app/models/submission.dart';
import 'package:romanticists_app/models/post.dart';
import 'package:romanticists_app/providers/auth_provider.dart';
import 'package:romanticists_app/services/firebase_service.dart';
import 'package:romanticists_app/providers/collections_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Submission>? _submissions;
  List<Submission>? _drafts;
  Map<String, dynamic>? _firestoreData;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;

    // [Async Safety] Trigger background loads BEFORE first await to avoid context issues
    context.read<CollectionsProvider>().load(uid);

    // 1. Optimistic Cache Load
    final cachedSubs = await FirebaseService.instance.getCachedUserSubmissions(uid, status: SubmissionStatus.approved);
    final cachedDrafts = await FirebaseService.instance.getCachedUserSubmissions(uid, status: SubmissionStatus.draft);
    final cachedData = await FirebaseService.instance.getCachedUserPublicInfo(uid);

    if (mounted) {
      setState(() {
        _submissions ??= cachedSubs;
        _drafts ??= cachedDrafts;
        _firestoreData ??= cachedData;
        _loading = (_submissions == null || _submissions!.isEmpty);
        _error = null;
      });
    }

    try {
      // 3. [PERF FIX] Fetch approved submissions, drafts, and profile data
      //    in parallel instead of sequentially. Cuts load time by ~2/3.
      final results = await Future.wait([
        FirebaseService.instance.getUserSubmissions(uid, status: SubmissionStatus.approved),
        FirebaseService.instance.getUserSubmissions(uid, status: SubmissionStatus.draft),
        FirebaseService.instance.getUserPublicInfo(uid),
      ]);

      if (mounted) {
        setState(() {
          _submissions = results[0] as List<Submission>;
          _drafts = results[1] as List<Submission>;
          _firestoreData = results[2] as Map<String, dynamic>?;
        });
      }
    } on FirebaseServiceException catch (e) {
      if (mounted && (_submissions == null || _submissions!.isEmpty)) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isAuthenticated && auth.status != AuthStatus.unknown) {
      return _GuestView();
    }

    final user = auth.user;
    final name = user?.displayName ?? 'Romanticist';
    final photoUrl = user?.photoURL;

    if (_error != null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: _ErrorState(message: _error!, onRetry: _load),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            // ── App Bar ───────────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.menu, color: Theme.of(context).colorScheme.primary),
                onPressed: () {}, // Drawer or Menu
              ),
              centerTitle: true,
              title: Text(
                'The 21st Romanticists',
                style: GoogleFonts.ebGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.settings_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  onPressed: () => context.push('/settings'),
                ),
              ],
            ),

            // ── Profile Header ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  // Avatar with Edit Button
                  GestureDetector(
                    onTap: () => context.push('/edit-profile').then((_) => _load()),
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            image: photoUrl != null
                                ? DecorationImage(
                                    image: CachedNetworkImageProvider(
                                      photoUrl,
                                    ),
                                    fit: BoxFit.cover)
                                : null,
                            color: Theme.of(context).colorScheme.surfaceContainerHigh,
                          ),
                          child: photoUrl == null
                              ? Icon(Icons.person,
                                  size: 60, color: Theme.of(context).colorScheme.outline)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.edit,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    name,
                    style: GoogleFonts.ebGaramond(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if ((_firestoreData?['username'] as String?)?.isNotEmpty ?? false)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '@${_firestoreData!['username']}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.outline,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      _firestoreData?['bio'] ?? '"Seeking the sublime in the mundane. A traveler through ink and parchment, reviving the archaic soul for the digital age."',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.literata(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Action Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            onPressed: () => context.push('/edit-profile').then((_) => _load()),
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                            ),
                            child: Text(
                              'EDIT PROFILE',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.share_outlined, size: 20),
                            color: Theme.of(context).colorScheme.onSurface,
                            onPressed: () {
                              final profileLink = 'https://romanticists.app/profile/${user?.uid}';
                              Share.share(
                                'Check out $name on The 21st Romanticists: $profileLink',
                                subject: 'Poet Profile on The 21st Romanticists',
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Stats Row
                  IntrinsicHeight(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _StatItem(
                            count: '${_submissions?.length ?? 0}',
                            label: 'WORKS'),
                        const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                        FutureBuilder<int>(
                          future: FirebaseService.instance.getFollowingCount(user?.uid ?? ''),
                          builder: (context, snapshot) => _StatItem(
                              count: '${snapshot.data ?? 0}', label: 'FOLLOWING'),
                        ),
                        const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                        FutureBuilder<int>(
                          future: FirebaseService.instance.getFollowerCount(user?.uid ?? ''),
                          builder: (context, snapshot) => _StatItem(
                              count: '${snapshot.data ?? 0}', label: 'FOLLOWERS'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),

            // ── Tab Bar ───────────────────────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: Theme.of(context).colorScheme.onSurface,
                  unselectedLabelColor: Theme.of(context).colorScheme.outline,
                  dividerColor: Colors.transparent,
                  labelStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2),
                  tabs: const [
                    Tab(text: 'PUBLISHED'),
                    Tab(text: 'COLLECTIONS'),
                    Tab(text: 'DRAFTS'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _buildPublishedGrid(),
              _buildCollectionsGrid(),
              _buildDraftsGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPublishedGrid() {
    if (_loading) {
      return Center(
          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
    }
    if (_submissions == null || _submissions!.isEmpty) {
      return _EmptyState();
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: MasonryGrid(posts: _submissions!),
    );
  }

  Widget _buildCollectionsGrid() {
    final uid = context.read<AuthProvider>().user?.uid ?? '';
    final collectionsProvider = context.watch<CollectionsProvider>();
    
    if (collectionsProvider.status == CollectionsStatus.loading && collectionsProvider.items.isEmpty) {
      return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary));
    }
    
    final cols = collectionsProvider.items;
    if (cols.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.collections_bookmark_outlined,
                size: 52,
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('No Collections Yet',
                style: GoogleFonts.ebGaramond(
                    fontSize: 20, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text('Save a post and add it to a collection.',
                style: GoogleFonts.literata(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.outline,
                    fontStyle: FontStyle.italic)),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: cols.length,
      itemBuilder: (context, i) {
        final col = cols[i];
        return GestureDetector(
          onTap: () => context.push(
              '/collection/$uid/${col.id}?name=${Uri.encodeComponent(col.name)}'),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
              image: col.coverImageUrl != null
                  ? DecorationImage(
                      image: NetworkImage(col.coverImageUrl!),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                          Colors.black.withValues(alpha: 0.25),
                          BlendMode.darken))
                  : null,
            ),
            child: Stack(
              children: [
                if (col.coverImageUrl == null)
                  Center(
                    child: Icon(Icons.collections_bookmark_outlined,
                        size: 36, color: Theme.of(context).colorScheme.outline),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(8)),
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: col.coverImageUrl != null ? 0.7 : 0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          col.name,
                          style: GoogleFonts.ebGaramond(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: col.coverImageUrl != null
                                ? Colors.white
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${col.postCount} post${col.postCount == 1 ? '' : 's'}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: col.coverImageUrl != null
                                ? Colors.white70
                                : Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Widget _buildDraftsGrid() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_drafts == null || _drafts!.isEmpty) {
      return _EmptyState(message: 'No drafts saved', icon: Icons.drafts_outlined);
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: MasonryGrid(posts: _drafts!, onAction: _load),
    );
  }


}

class _StatItem extends StatelessWidget {
  final String count;
  final String label;
  _StatItem({required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          count,
          style: GoogleFonts.ebGaramond(
              fontSize: 22, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
              fontSize: 11, color: Theme.of(context).colorScheme.outline, letterSpacing: 0.5),
        ),
      ],
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);
  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

class MasonryGrid extends StatelessWidget {
  final List<dynamic> posts; // Can be List<Submission> or List<Post>
  final VoidCallback? onAction;
  const MasonryGrid({super.key, required this.posts, this.onAction});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.7,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = posts[index];
              return _GridCard(item: item, onAction: onAction);
            },
            childCount: posts.length,
          ),
        ),
      ],
    );
  }
}

class _GridCard extends StatelessWidget {
  final dynamic item;
  final VoidCallback? onAction;
  const _GridCard({required this.item, this.onAction});

  void _showMenu(BuildContext context) {
    if (item is! Submission) return;
    final sub = item as Submission;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Edit'),
            onTap: () {
              Navigator.pop(context);
              context.push('/submit', extra: sub).then((_) => onAction?.call());
            },
          ),
          if (sub.status == SubmissionStatus.approved)
            ListTile(
              leading: Icon(Icons.archive_outlined),
              title: Text('Archive to Drafts'),
              onTap: () async {
                Navigator.pop(context);
                final updated = sub.copyWith(status: SubmissionStatus.draft);
                await FirebaseService.instance.updateSubmission(sub.id!, updated);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Post has been sent to drafts.'))
                  );
                  onAction?.call();
                }
              },
            ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
            title: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            onTap: () {
              Navigator.pop(context);
              _confirmDelete(context, sub);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, Submission sub) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Post'),
        content: Text('Are you sure you want to delete this? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseService.instance.deleteSubmission(sub.id!);
              onAction?.call();
            },
            child: Text('DELETE', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? imageUrl;
    String title;
    String? route;

    if (item is Submission) {
      imageUrl = item.imageUrl;
      title = item.title;
      route = '/submission/${item.id}';
    } else if (item is Post) {
      imageUrl = item.imageUrl;
      title = item.cleanTitle;
      route = '/post/${item.id}';
    } else {
      title = 'Unknown';
    }

    return GestureDetector(
      onTap: route != null ? () => context.push(route!, extra: item) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null && imageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      // [Technique: Downsampling] Grid items only need 400px width
                      memCacheWidth: 400,
                      placeholder: (_, __) => _placeholderShimmer(context),
                      errorWidget: (_, __, ___) => _placeholder(context),
                    )
                  else
                    _placeholder(context),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: GestureDetector(
                        onTap: () => _showMenu(context),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.more_vert, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.ebGaramond(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: Icon(Icons.auto_stories_outlined, color: Theme.of(context).colorScheme.outline),
      );
 
  Widget _placeholderShimmer(BuildContext context) => Container(
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    child: Center(
      child: CircularProgressIndicator(strokeWidth: 1.5, color: Theme.of(context).colorScheme.outline),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const _EmptyState({
    this.message = 'No submissions yet',
    this.icon = Icons.edit_note_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.ebGaramond(
              fontSize: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, style: GoogleFonts.literata(fontSize: 14)),
          TextButton(onPressed: onRetry, child: Text('Retry')),
        ],
      ),
    );
  }
}

class _GuestView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_outline, size: 64, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 24),
              Text(
                'Sign in to see your profile',
                style: GoogleFonts.ebGaramond(fontSize: 24),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => context.push('/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: Text('Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}