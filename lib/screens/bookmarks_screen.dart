import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:romanticists_app/app_theme.dart';
import 'package:romanticists_app/models/post.dart';
import 'package:romanticists_app/providers/auth_provider.dart';
import 'package:romanticists_app/providers/bookmarks_provider.dart';
import 'package:romanticists_app/widgets/post_card.dart';

/// Shows the signed-in user's bookmarked posts.
class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isAuthenticated && auth.status != AuthStatus.unknown) {
      return _GuestPrompt();
    }

    return Consumer<BookmarksProvider>(
      builder: (context, bm, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: RefreshIndicator(
            onRefresh: () async {
              final uid = auth.user?.uid;
              if (uid != null) await bm.load(uid);
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ── AppBar ─────────────────────────────────────────────────
                SliverAppBar(
                  pinned: true,
                  backgroundColor: AppColors.background,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  title: Text(
                    'Saved',
                    style: GoogleFonts.ebGaramond(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                  actions: [
                    if (bm.posts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Center(
                          child: Text(
                            '${bm.posts.length} saved',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                // ── Body ───────────────────────────────────────────────────
                ..._buildBody(context, bm),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildBody(BuildContext context, BookmarksProvider bm) {
    if (bm.status == BookmarksStatus.loading ||
        bm.status == BookmarksStatus.initial) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(
                color: AppColors.primary, strokeWidth: 2),
          ),
        ),
      ];
    }

    if (bm.status == BookmarksStatus.failure) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _ErrorState(message: bm.errorMessage ?? 'Could not load bookmarks.'),
        ),
      ];
    }

    if (bm.posts.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final post = bm.posts[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PostCard(post: post, featured: false),
              );
            },
            childCount: bm.posts.length,
          ),
        ),
      ),
    ];
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
          const Icon(Icons.bookmark_border_outlined,
              size: 64, color: AppColors.outline),
          const SizedBox(height: 16),
          Text(
            'Nothing saved yet',
            style: GoogleFonts.ebGaramond(
              fontSize: 22,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the bookmark icon on any post\nto save it here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.literata(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
              fontStyle: FontStyle.italic,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.home_outlined, size: 16),
            label: const Text('Browse Posts'),
            onPressed: () => context.go('/'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2)),
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
          const Icon(Icons.cloud_off_outlined,
              size: 56, color: AppColors.outline),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.literata(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        title: Text(
          'Saved',
          style: GoogleFonts.ebGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: AppColors.primary,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bookmark_border_outlined,
                  size: 64, color: AppColors.outline),
              const SizedBox(height: 20),
              Text(
                'Sign in to save posts',
                style: GoogleFonts.ebGaramond(
                    fontSize: 24, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                'Your bookmarks will sync\nacross all your devices.',
                textAlign: TextAlign.center,
                style: GoogleFonts.literata(
                  fontSize: 14,
                  color: AppColors.onSurfaceVariant,
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
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  child: Text('Sign In',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
