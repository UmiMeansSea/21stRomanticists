import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:romanticists_app/app_theme.dart';
import 'package:romanticists_app/models/submission.dart';
import 'package:romanticists_app/providers/auth_provider.dart';
import 'package:romanticists_app/services/firebase_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Submission>? _submissions;
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

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final subs = await FirebaseService.instance.getUserSubmissions(uid);
      final data = await FirebaseService.instance.getUserPublicInfo(uid);
      if (mounted) {
        setState(() {
          _submissions = subs;
          _firestoreData = data;
        });
      }
    } on FirebaseServiceException catch (e) {
      if (mounted) setState(() => _error = e.message);
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
    final email = user?.email ?? '';
    final photoUrl = user?.photoURL;

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: _ErrorState(message: _error!, onRetry: _load),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            // ── App Bar ───────────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.background,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.menu, color: AppColors.primary),
                onPressed: () {}, // Drawer or Menu
              ),
              centerTitle: true,
              title: Text(
                'The 21st Romanticists',
                style: GoogleFonts.ebGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined,
                      color: AppColors.primary),
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
                                    image: NetworkImage(photoUrl),
                                    fit: BoxFit.cover)
                                : null,
                            color: AppColors.surfaceContainerHigh,
                          ),
                          child: photoUrl == null
                              ? const Icon(Icons.person,
                                  size: 60, color: AppColors.outline)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit,
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
                      color: AppColors.onSurface,
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
                        color: AppColors.onSurfaceVariant,
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
                          child: OutlinedButton(
                            onPressed: () => context.push('/edit-profile').then((_) => _load()),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.outlineVariant),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              'EDIT PROFILE',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.outlineVariant),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.share_outlined, size: 20),
                            onPressed: () {},
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
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
                  indicatorColor: AppColors.onSurface,
                  indicatorWeight: 2,
                  labelColor: AppColors.onSurface,
                  unselectedLabelColor: AppColors.outline,
                  labelStyle: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1),
                  tabs: const [
                    Tab(text: 'PUBLISHED'),
                    Tab(text: 'DRAFTS'),
                    Tab(text: 'COLLECTIONS'),
                    Tab(text: 'SAVED'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _buildPublishedGrid(),
              _buildEmptyPlaceholder('No Drafts'),
              _buildEmptyPlaceholder('No Collections'),
              _buildEmptyPlaceholder('No Saved Posts'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPublishedGrid() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_submissions == null || _submissions!.isEmpty) {
      return _EmptyState();
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: MasonryGrid(
        submissions: _submissions!,
      ),
    );
  }

  Widget _buildEmptyPlaceholder(String title) {
    return Center(
      child: Text(title, style: GoogleFonts.ebGaramond(fontSize: 18)),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String count;
  final String label;
  const _StatItem({required this.count, required this.label});

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
              fontSize: 11, color: AppColors.outline, letterSpacing: 0.5),
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
      color: AppColors.background,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

class MasonryGrid extends StatelessWidget {
  final List<Submission> submissions;
  const MasonryGrid({super.key, required this.submissions});

  @override
  Widget build(BuildContext context) {
    // Simple custom grid for the "Masonry" effect
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
              final sub = submissions[index];
              return _GridCard(sub: sub);
            },
            childCount: submissions.length,
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

class _GridCard extends StatelessWidget {
  final Submission sub;
  const _GridCard({required this.sub});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMMM d').format(sub.submittedAt);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // If we had images for submissions, we'd show them here.
          // For now, let's use a themed placeholder or just text.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    date,
                    style: GoogleFonts.inter(
                        fontSize: 10, color: AppColors.outline),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sub.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.ebGaramond(
                        fontSize: 18, fontWeight: FontWeight.w600, height: 1.1),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Text(
                      sub.content,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.literata(
                          fontSize: 12,
                          color: AppColors.onSurfaceVariant,
                          height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'KEEP READING',
                        style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5),
                      ),
                      const Spacer(),
                      const Icon(Icons.bookmark_border, size: 16),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Reuse the existing states but styled for the new profile
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.edit_note_outlined,
              size: 48, color: AppColors.outline),
          const SizedBox(height: 16),
          Text(
            'No submissions yet',
            style: GoogleFonts.ebGaramond(
              fontSize: 20,
              color: AppColors.onSurface,
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
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _GuestView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline, size: 64, color: AppColors.outline),
              const SizedBox(height: 24),
              Text(
                'Sign in to see your profile',
                style: GoogleFonts.ebGaramond(fontSize: 24),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => context.push('/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
