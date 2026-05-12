import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:romanticists_app/app_theme.dart';
import 'package:romanticists_app/models/submission.dart';
import 'package:romanticists_app/providers/auth_provider.dart';
import 'package:romanticists_app/services/firebase_service.dart';
import 'package:romanticists_app/services/notification_service.dart';
import 'package:romanticists_app/services/wp_api.dart';
import 'package:romanticists_app/widgets/full_screen_viewer.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  final String? initialName;

  const PublicProfileScreen({
    super.key,
    required this.userId,
    this.initialName,
  });

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  Map<String, dynamic>? _userInfo;
  List<Submission>? _submissions;
  bool _isSubscribed = false;
  int _followerCount = 0;
  int _worksCount = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = FirebaseService.instance;
    final currentUid = context.read<AuthProvider>().user?.uid;

    // 1. Optimistic Cache Load
    final cachedSubs = await service.getCachedUserSubmissions(widget.userId);
    final cachedInfo = await service.getCachedUserPublicInfo(widget.userId);
    
    if (mounted) {
      setState(() {
        if (_userInfo == null) _userInfo = cachedInfo;
        if (_submissions == null) {
          _submissions = cachedSubs.where((s) => !s.isAnonymous).toList();
          _worksCount = _submissions?.length ?? 0;
        }
        _loading = (_userInfo == null && _submissions == null);
      });
    }

    try {
      // Parallelize fetches for better performance
      final results = await Future.wait([
        service.getUserPublicInfo(widget.userId),
        service.getUserSubmissions(widget.userId),
        service.getFollowerCount(widget.userId),
        currentUid != null 
            ? service.isSubscribed(currentUid, widget.userId) 
            : Future.value(false),
      ]);

      final info = results[0] as Map<String, dynamic>?;
      final allSubs = results[1] as List<Submission>;
      final followers = results[2] as int;
      final subscribed = results[3] as bool;

      // FIX 5: Handle "Legacy" WordPress users
      List<Submission> subs = allSubs.where((s) => !s.isAnonymous).toList();
      final isLegacy = widget.userId.startsWith('legacy_') || int.tryParse(widget.userId) != null;
      
      if (isLegacy && subs.isEmpty) {
        final wpIdStr = widget.userId.replaceAll('legacy_', '');
        try {
          // Fetch posts from WP for this author
          final wpPosts = await WpApiService.instance.fetchPosts(perPage: 20);
          // Filter to only include posts by this author name/ID
          final authorPosts = wpPosts.where((p) => p.authorId.toString() == wpIdStr || p.author == (info?['displayName'] ?? widget.initialName));
          
          final converted = authorPosts.map((p) => Submission(
            id: 'wp_${p.id}',
            title: p.cleanTitle,
            content: p.cleanExcerpt,
            imageUrl: p.imageUrl,
            authorName: p.author,
            userId: widget.userId,
            submittedAt: p.publishedAt,
            tags: p.tagNames,
            status: SubmissionStatus.approved,
            isAnonymous: false,
            category: p.categories.isNotEmpty ? SubmissionCategory.prose : SubmissionCategory.poems, // Fallback
          )).toList();
          
          subs.addAll(converted);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _userInfo = info;
          _submissions = subs;
          _followerCount = followers;
          _worksCount = subs.length;
          _isSubscribed = subscribed;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleSubscribe() async {
    final currentUid = context.read<AuthProvider>().user?.uid;
    if (currentUid == null) return; // Prompt login if needed

    final service = FirebaseService.instance;
    final name = _userInfo?['displayName'] ?? widget.initialName ?? 'Unknown';

    try {
      if (_isSubscribed) {
        await service.unsubscribe(currentUid, widget.userId);
        await NotificationService.instance.unsubscribeFromTopic('author_${widget.userId}');
        setState(() {
          _isSubscribed = false;
          _followerCount--;
        });
      } else {
        await service.subscribe(currentUid, widget.userId, targetName: name);
        await NotificationService.instance.subscribeToTopic('author_${widget.userId}');
        setState(() {
          _isSubscribed = true;
          _followerCount++;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _userInfo?['displayName'] ?? widget.initialName ?? 'Romanticist';
    final photoUrl = _userInfo?['photoURL'];
    final bio = _userInfo?['bio'] ?? '"A silent observer of beauty, finding eternity in a moment of ink."';

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: Theme.of(context).colorScheme.surface,
                  elevation: 0,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.primary),
                    onPressed: () => Navigator.pop(context),
                  ),
                  centerTitle: true,
                  title: Text(
                    'Author Profile',
                    style: GoogleFonts.ebGaramond(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      // Avatar
                      GestureDetector(
                        onTap: () {
                          if (photoUrl != null) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FullScreenViewer(
                                  imageUrl: photoUrl,
                                  heroTag: 'public_avatar_${widget.userId}',
                                ),
                              ),
                            );
                          }
                        },
                        child: Hero(
                          tag: 'public_avatar_${widget.userId}',
                          child: Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              image: photoUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(photoUrl),
                                      fit: BoxFit.cover)
                                  : null,
                              color: Theme.of(context).colorScheme.surfaceContainerHigh,
                            ),
                            child: photoUrl == null
                                ? Icon(Icons.person,
                                    size: 50, color: Theme.of(context).colorScheme.outline)
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        name,
                        style: GoogleFonts.ebGaramond(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          bio,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.literata(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Subscribe Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _toggleSubscribe,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isSubscribed 
                                  ? Theme.of(context).colorScheme.surface 
                                  : Theme.of(context).colorScheme.onSurface,
                              foregroundColor: _isSubscribed 
                                  ? Theme.of(context).colorScheme.onSurface 
                                  : Theme.of(context).colorScheme.surface,
                              side: _isSubscribed 
                                  ? BorderSide(color: Theme.of(context).colorScheme.outline)
                                  : BorderSide.none,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(
                              _isSubscribed ? 'SUBSCRIBED' : 'SUBSCRIBE',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Stats
                      IntrinsicHeight(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _StatItem(count: '$_worksCount', label: 'WORKS'),
                            const VerticalDivider(width: 1, indent: 8, endIndent: 8),
                            _StatItem(count: '$_followerCount', label: 'SUBSCRIBERS'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Divider(),
                    ],
                  ),
                ),
                // Submissions Grid
                if (_submissions != null && _submissions!.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.7,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _GridCard(sub: _submissions![index]),
                        childCount: _submissions!.length,
                      ),
                    ),
                  )
                else
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('No public works yet.')),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
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
              fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
              fontSize: 10, color: Theme.of(context).colorScheme.outline, letterSpacing: 0.5),
        ),
      ],
    );
  }
}

class _GridCard extends StatelessWidget {
  final Submission sub;
  const _GridCard({required this.sub});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d, yyyy').format(sub.submittedAt);
    return GestureDetector(
      onTap: () => context.push('/submission/${sub.id}', extra: sub),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(date, style: GoogleFonts.inter(fontSize: 9, color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 6),
            Text(
              sub.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.ebGaramond(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                sub.content,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.literata(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}