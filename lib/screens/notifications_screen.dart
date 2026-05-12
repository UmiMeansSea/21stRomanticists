import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:romanticists_app/app_theme.dart';
import 'package:romanticists_app/models/submission.dart';
import 'package:romanticists_app/providers/auth_provider.dart';
import 'package:romanticists_app/services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A unified notifications + subscribed-feed screen.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Activity',
          style: GoogleFonts.ebGaramond(
              fontSize: 24, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.primary),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          indicatorWeight: 2,
          labelColor: Theme.of(context).colorScheme.onSurface,
          unselectedLabelColor: Theme.of(context).colorScheme.outline,
          labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
          tabs: const [
            Tab(text: 'SUBSCRIBED'),
            Tab(text: 'NOTIFICATIONS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _SubscribedFeed(),
          _NotificationsFeed(),
        ],
      ),
    );
  }
}

// ─── Tab 1: New posts from subscribed authors ─────────────────────────────────

class _SubscribedFeed extends StatefulWidget {
  const _SubscribedFeed();

  @override
  State<_SubscribedFeed> createState() => _SubscribedFeedState();
}

class _SubscribedFeedState extends State<_SubscribedFeed> {
  List<Submission>? _posts;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    // Only show full-screen spinner if we have no data yet
    if (_posts == null) setState(() => _loading = true);

    try {
      final followingIds = await FirebaseService.instance.getFollowingIds(uid);
      if (followingIds.isEmpty) {
        setState(() { _posts = []; _loading = false; });
        return;
      }

      // Fetch latest submissions (these now use SWR at the service level)
      final List<Submission> allPosts = [];
      for (final authorId in followingIds.take(20)) {
        final subs = await FirebaseService.instance.getUserSubmissions(authorId);
        allPosts.addAll(subs.take(5));
      }

      // Sort newest first globally
      allPosts.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

      if (mounted) setState(() { _posts = allPosts; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return _SignInPrompt();

    if (_posts == null || _posts!.isEmpty) {
      return _EmptyTab(
        icon: Icons.newspaper_outlined,
        title: 'Nothing new yet',
        subtitle: 'Subscribe to authors on their profiles\nto see their latest works here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: _posts!.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, i) => _SubscribedPostTile(sub: _posts![i]),
      ),
    );
  }
}

class _SubscribedPostTile extends StatelessWidget {
  final Submission sub;
  const _SubscribedPostTile({required this.sub});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMM d').format(sub.submittedAt);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: Text(
          (sub.authorName ?? '?')[0].toUpperCase(),
          style: GoogleFonts.ebGaramond(
              fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
        ),
      ),
      title: Text(
        sub.title,
        style: GoogleFonts.ebGaramond(fontSize: 16, fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${sub.authorName ?? 'Unknown'} · $date',
        style: GoogleFonts.inter(fontSize: 12, color: Theme.of(context).colorScheme.outline),
      ),
      trailing: Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.outline),
      onTap: () {
        final uid = sub.userId;
        if (uid != null && uid.isNotEmpty) {
          context.push('/user/$uid?name=${sub.authorName ?? ''}');
        }
      },
    );
  }
}

// ─── Tab 2: Activity notifications ──────────────────────────────────────────

class _NotificationsFeed extends StatefulWidget {
  const _NotificationsFeed();

  @override
  State<_NotificationsFeed> createState() => _NotificationsFeedState();
}

class _NotificationsFeedState extends State<_NotificationsFeed> {
  List<Map<String, dynamic>>? _notifications;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }

    if (_notifications == null) setState(() => _loading = true);

    try {
      // Use the new SWR-aware method
      final notes = await FirebaseService.instance.getNotifications(uid);
      if (mounted) setState(() { _notifications = notes; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _notifications = []; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return _SignInPrompt();

    if (_notifications == null || _notifications!.isEmpty) {
      return _EmptyTab(
        icon: Icons.notifications_none_outlined,
        title: 'All quiet here',
        subtitle: 'When readers subscribe, like, or\ncomment on your work, it will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: _notifications!.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72, endIndent: 16),
        itemBuilder: (context, i) => _NotificationTile(data: _notifications![i]),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _NotificationTile({required this.data});

  IconData _icon(String type) {
    switch (type) {
      case 'like': return Icons.favorite;
      case 'subscribe': return Icons.person_add;
      case 'new_post': return Icons.auto_stories_outlined;
      default: return Icons.notifications;
    }
  }

  Color _iconColor(BuildContext context, String type) {
    switch (type) {
      case 'like': return const Color(0xFFE05252);
      case 'subscribe': return Theme.of(context).colorScheme.secondary;
      case 'new_post': return Theme.of(context).colorScheme.primary;
      default: return Theme.of(context).colorScheme.outline;
    }
  }

  String _message(String type, String actorName) {
    switch (type) {
      case 'like': return '$actorName liked your work';
      case 'subscribe': return '$actorName subscribed to you';
      case 'new_post': return '$actorName published a new work';
      default: return '$actorName interacted with your profile';
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = data['type'] as String? ?? 'other';
    final actorName = data['actorName'] as String? ?? 'Someone';
    final title = data['postTitle'] as String?;
    final ts = data['createdAt'];
    DateTime? date;
    if (ts is Timestamp) {
      date = ts.toDate();
    } else if (ts is String) {
      date = DateTime.tryParse(ts);
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _iconColor(context, type).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(_icon(type), color: _iconColor(context, type), size: 22),
      ),
      title: Text(
        _message(type, actorName),
        style: GoogleFonts.literata(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              '"$title"',
              style: GoogleFonts.ebGaramond(
                  fontSize: 13, fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.onSurfaceVariant),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (date != null)
            Text(
              DateFormat('MMM d, h:mm a').format(date),
              style: GoogleFonts.inter(fontSize: 11, color: Theme.of(context).colorScheme.outline),
            ),
        ],
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyTab({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4)),
            const SizedBox(height: 20),
            Text(title, style: GoogleFonts.ebGaramond(fontSize: 22, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.literata(fontSize: 14, color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 48, color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('Sign in to see your activity',
              style: GoogleFonts.ebGaramond(fontSize: 20)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.push('/login'),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }
}
