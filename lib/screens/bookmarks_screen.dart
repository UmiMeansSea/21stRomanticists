import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:romanticists_app/app_theme.dart';
import 'package:romanticists_app/providers/auth_provider.dart';
import 'package:romanticists_app/providers/bookmarks_provider.dart';
import 'package:romanticists_app/providers/collections_provider.dart';
import 'package:romanticists_app/widgets/post_card.dart';

/// Shows the signed-in user's bookmarked posts and collections.
class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.isAuthenticated && auth.uid != null) {
        context.read<CollectionsProvider>().load(auth.uid!);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isAuthenticated && auth.status != AuthStatus.unknown) {
      return _GuestPrompt();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Saved',
          style: GoogleFonts.ebGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          labelStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'All Posts'),
            Tab(text: 'Collections'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AllPostsTab(),
          _CollectionsTab(uid: auth.uid ?? ''),
        ],
      ),
    );
  }
}

class _AllPostsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<BookmarksProvider>(
      builder: (context, bm, _) {
        if (bm.status == BookmarksStatus.loading || bm.status == BookmarksStatus.initial) {
          return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary, strokeWidth: 2));
        }
        if (bm.status == BookmarksStatus.failure) {
          return _ErrorState(message: bm.errorMessage ?? 'Could not load bookmarks.');
        }
        if (bm.items.isEmpty) {
          return _EmptyState();
        }

        return RefreshIndicator(
          onRefresh: () async {
            final uid = context.read<AuthProvider>().uid;
            if (uid != null) await bm.load(uid);
          },
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: bm.items.length,
            itemBuilder: (context, i) {
              final item = bm.items[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: FeedCard(item: item),
              );
            },
          ),
        );
      },
    );
  }
}

class _CollectionsTab extends StatelessWidget {
  final String uid;
  const _CollectionsTab({required this.uid});

  @override
  Widget build(BuildContext context) {
    return Consumer<CollectionsProvider>(
      builder: (context, cols, _) {
        if (cols.status == CollectionsStatus.loading || cols.status == CollectionsStatus.initial) {
          return Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary, strokeWidth: 2));
        }
        if (cols.status == CollectionsStatus.failure) {
          return _ErrorState(message: cols.errorMessage ?? 'Could not load collections.');
        }
        if (cols.items.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.collections_bookmark_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 16),
                Text(
                  'No collections yet',
                  style: GoogleFonts.ebGaramond(fontSize: 22, color: Theme.of(context).colorScheme.onSurface),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the bookmark icon on any post\nto organize them into collections.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.literata(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => cols.load(uid),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 24,
              childAspectRatio: 0.85,
            ),
            itemCount: cols.items.length,
            itemBuilder: (context, i) {
              final col = cols.items[i];
              return GestureDetector(
                onTap: () {
                  context.push('/collection/$uid/${col.id}?name=${Uri.encodeComponent(col.name)}');
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                          image: col.coverImageUrl != null && col.coverImageUrl!.isNotEmpty
                              ? DecorationImage(image: CachedNetworkImageProvider(col.coverImageUrl!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: col.coverImageUrl == null || col.coverImageUrl!.isEmpty
                            ? Center(child: Icon(Icons.collections_bookmark_outlined, size: 40, color: Theme.of(context).colorScheme.outline))
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      col.name,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${col.postCount} post${col.postCount == 1 ? '' : 's'}',
                      style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ─── States ───────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'Nothing saved yet',
            style: GoogleFonts.ebGaramond(fontSize: 22, color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the bookmark icon on any post\nto save it here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.literata(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: Icon(Icons.home_outlined, size: 16),
            label: Text('Browse Posts'),
            onPressed: () => context.go('/'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              side: BorderSide(color: Theme.of(context).colorScheme.primary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.literata(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        automaticallyImplyLeading: false,
        title: Text(
          'Saved',
          style: GoogleFonts.ebGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmark_border_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 20),
              Text(
                'Sign in to save posts',
                style: GoogleFonts.ebGaramond(fontSize: 24, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                'Your bookmarks will sync\nacross all your devices.',
                textAlign: TextAlign.center,
                style: GoogleFonts.literata(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push('/login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                  ),
                  child: Text('Sign In', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
