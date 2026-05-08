import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:romanticists_app/app_theme.dart';
import 'package:romanticists_app/models/submission.dart';
import 'package:romanticists_app/providers/auth_provider.dart';
import 'package:romanticists_app/services/firebase_service.dart';

/// Full profile screen — avatar, bio, and "My Submissions" list.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Submission>? _submissions;
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
      if (mounted) setState(() => _submissions = subs);
    } on FirebaseServiceException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await context.read<AuthProvider>().signOut();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Not signed in — prompt login
    if (!auth.isAuthenticated && auth.status != AuthStatus.unknown) {
      return _GuestView();
    }

    final user = auth.user;
    final name = user?.displayName ?? 'Romanticist';
    final email = user?.email ?? '';
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            // ── App Bar ───────────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              backgroundColor: AppColors.background,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Text(
                'Profile',
                style: GoogleFonts.ebGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_outlined,
                      color: AppColors.primary, size: 20),
                  tooltip: 'Sign out',
                  onPressed: _signOut,
                ),
              ],
            ),

            // ── Profile header ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: Column(
                  children: [
                    // Avatar
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: GoogleFonts.ebGaramond(
                            fontSize: 32,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      name,
                      style: GoogleFonts.ebGaramond(
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Submissions count badge
                    if (_submissions != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.secondary.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '${_submissions!.length} ${_submissions!.length == 1 ? 'Submission' : 'Submissions'}',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Section title ─────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Row(
                  children: [
                    Expanded(
                        child: Container(
                            height: 0.4,
                            color: AppColors.outlineVariant)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'MY SUBMISSIONS',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                        child: Container(
                            height: 0.4,
                            color: AppColors.outlineVariant)),
                  ],
                ),
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorState(message: _error!, onRetry: _load),
              )
            else if (_submissions == null || _submissions!.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _SubmissionCard(sub: _submissions![i]),
                    childCount: _submissions!.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Submission card ──────────────────────────────────────────────────────────

class _SubmissionCard extends StatelessWidget {
  final Submission sub;
  const _SubmissionCard({required this.sub});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('d MMM yyyy').format(sub.submittedAt);
    final statusColor = switch (sub.status) {
      SubmissionStatus.approved => const Color(0xFF2D7A4F),
      SubmissionStatus.rejected => AppColors.error,
      SubmissionStatus.pending => AppColors.secondary,
    };
    final statusLabel = switch (sub.status) {
      SubmissionStatus.approved => 'APPROVED',
      SubmissionStatus.rejected => 'DECLINED',
      SubmissionStatus.pending => 'PENDING',
    };
    final icon = switch (sub.status) {
      SubmissionStatus.approved => Icons.check_circle_outline,
      SubmissionStatus.rejected => Icons.cancel_outlined,
      SubmissionStatus.pending => Icons.schedule_outlined,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Category + Status row ──────────────────────────────────────
          Row(
            children: [
              _Chip(label: sub.category.label.toUpperCase()),
              const Spacer(),
              Icon(icon, size: 14, color: statusColor),
              const SizedBox(width: 4),
              Text(
                statusLabel,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Title ─────────────────────────────────────────────────────
          Text(
            sub.title,
            style: GoogleFonts.ebGaramond(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: AppColors.onSurface,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),

          // ── Preview ───────────────────────────────────────────────────
          Text(
            sub.content.length > 120
                ? '${sub.content.substring(0, 120).trimRight()}…'
                : sub.content,
            style: GoogleFonts.literata(
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
              height: 1.55,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),

          // ── Footer ────────────────────────────────────────────────────
          Text(
            'Submitted $date',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ─── Empty / error / guest states ────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.edit_note_outlined,
              size: 64, color: AppColors.outline),
          const SizedBox(height: 16),
          Text(
            'No submissions yet',
            style: GoogleFonts.ebGaramond(
              fontSize: 22,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Head to the Write tab\nto submit your first piece.',
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
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Write Something'),
            onPressed: () => context.go('/write'),
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
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

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
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Profile',
          style: GoogleFonts.ebGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w500,
            color: AppColors.primary,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceContainerHigh,
                ),
                child: const Icon(Icons.person_outline,
                    size: 40, color: AppColors.outline),
              ),
              const SizedBox(height: 24),
              Text(
                'Sign in to see your profile',
                style: GoogleFonts.ebGaramond(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Track your submissions,\nsave bookmarks and more.',
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
                  child: Text(
                    'Sign In',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
