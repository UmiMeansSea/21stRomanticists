import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:romanticists_app/app_theme.dart';
import 'package:romanticists_app/models/submission.dart';
import 'package:romanticists_app/providers/auth_provider.dart';
import 'package:romanticists_app/providers/activity_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
    
    // Initialize provider data as soon as we have a user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().user?.uid;
      if (uid != null) {
        context.read<ActivityProvider>().init(uid);
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

// ─── Tab 1: Subscribed Feed ──────────────────────────────────────────────────

class _SubscribedFeed extends StatefulWidget {
  const _SubscribedFeed();

  @override
  State<_SubscribedFeed> createState() => _SubscribedFeedState();
}

class _SubscribedFeedState extends State<_SubscribedFeed> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final activity = context.read<ActivityProvider>();
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid != null &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      activity.loadMoreSubscribed(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<ActivityProvider>();
    final auth = context.watch<AuthProvider>();

    // Phase 2: Shimmer Skeletons for empty cache + loading
    if (activity.isLoadingSubscribed && activity.subscribedPosts.isEmpty) {
      return const _ShimmerList();
    }

    if (auth.user == null) return _SignInPrompt();

    if (activity.subscribedPosts.isEmpty && !activity.isLoadingSubscribed) {
      return const _EmptyTab(
        icon: Icons.newspaper_outlined,
        title: 'Nothing new yet',
        subtitle: 'Subscribe to authors on their profiles\nto see their latest works here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => activity.refreshSubscribed(auth.user!.uid),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: activity.subscribedPosts.length + (activity.hasMoreSubscribed ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
        itemBuilder: (context, i) {
          if (i == activity.subscribedPosts.length) {
            return const _PaginationLoader();
          }
          return _SubscribedPostTile(sub: activity.subscribedPosts[i]);
        },
      ),
    );
  }
}

// ─── Tab 2: Notifications Feed ────────────────────────────────────────────────

class _NotificationsFeed extends StatefulWidget {
  const _NotificationsFeed();

  @override
  State<_NotificationsFeed> createState() => _NotificationsFeedState();
}

class _NotificationsFeedState extends State<_NotificationsFeed> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final activity = context.read<ActivityProvider>();
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid != null &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      activity.loadMoreNotifications(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activity = context.watch<ActivityProvider>();
    final auth = context.watch<AuthProvider>();

    // Phase 2: Shimmer Skeletons
    if (activity.isLoadingNotifications && activity.notifications.isEmpty) {
      return const _ShimmerList();
    }

    if (auth.user == null) return _SignInPrompt();

    if (activity.notifications.isEmpty && !activity.isLoadingNotifications) {
      return const _EmptyTab(
        icon: Icons.notifications_none_outlined,
        title: 'All quiet here',
        subtitle: 'When readers subscribe, like, or\ncomment on your work, it will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => activity.refreshNotifications(auth.user!.uid),
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: activity.notifications.length + (activity.hasMoreNotifications ? 1 : 0),
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72, endIndent: 16),
        itemBuilder: (context, i) {
          if (i == activity.notifications.length) {
            return const _PaginationLoader();
          }
          return _NotificationTile(data: activity.notifications[i]);
        },
      ),
    );
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

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
        backgroundImage: sub.imageUrl != null ? CachedNetworkImageProvider(sub.imageUrl!) : null,
        child: sub.imageUrl == null
            ? Text(
                (sub.authorName ?? '?')[0].toUpperCase(),
                style: GoogleFonts.ebGaramond(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
              )
            : null,
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
      onTap: () => context.push('/submission/${sub.id}', extra: sub),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _NotificationTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final type = data['type'] as String? ?? 'other';
    final actorName = data['actorName'] as String? ?? 'Someone';
    final actorImageUrl = data['actorImageUrl'] as String?;
    final title = data['postTitle'] as String?;
    final date = _parseDate(data['createdAt']);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: _NotificationAvatar(url: actorImageUrl, type: type),
      title: RichText(
        text: TextSpan(
          style: GoogleFonts.literata(fontSize: 14, color: Theme.of(context).colorScheme.onSurface),
          children: [
            TextSpan(text: actorName, style: const FontWeight.bold),
            TextSpan(text: _message(type)),
          ],
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text('"$title"',
                style: GoogleFonts.ebGaramond(
                    fontSize: 13, fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          if (date != null)
            Text(DateFormat('MMM d, h:mm a').format(date),
                style: GoogleFonts.inter(fontSize: 11, color: Theme.of(context).colorScheme.outline)),
        ],
      ),
      onTap: () {
        final postId = data['postId'] as String?;
        if (postId != null) context.push('/submission/$postId');
      },
    );
  }

  String _message(String type) {
    switch (type) {
      case 'like': return ' liked your work';
      case 'subscribe': return ' subscribed to you';
      case 'new_post': return ' published a new work';
      default: return ' interacted with your profile';
    }
  }

  DateTime? _parseDate(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    return null;
  }
}

class _NotificationAvatar extends StatelessWidget {
  final String? url;
  final String type;
  const _NotificationAvatar({this.url, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
      child: url != null 
        ? ClipOval(child: CachedNetworkImage(imageUrl: url!, fit: BoxFit.cover, memCacheWidth: 100))
        : Icon(_icon(type), size: 20, color: Theme.of(context).colorScheme.primary),
    );
  }

  IconData _icon(String type) {
    switch (type) {
      case 'like': return Icons.favorite;
      case 'subscribe': return Icons.person_add;
      case 'new_post': return Icons.auto_stories_outlined;
      default: return Icons.notifications;
    }
  }
}

class _ShimmerList extends StatelessWidget {
  const _ShimmerList();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      highlightColor: Theme.of(context).colorScheme.surface,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: 8,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const CircleAvatar(radius: 22, backgroundColor: Colors.white),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 14, width: 150, color: Colors.white),
                    const SizedBox(height: 8),
                    Container(height: 10, width: 220, color: Colors.white),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaginationLoader extends StatelessWidget {
  const _PaginationLoader();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyTab({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
          const SizedBox(height: 20),
          Text(title, style: GoogleFonts.ebGaramond(fontSize: 22)),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.literata(fontSize: 14, color: Theme.of(context).colorScheme.outline, fontStyle: FontStyle.italic)),
        ],
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
          Icon(Icons.lock_outline, size: 48, color: Theme.of(context).colorScheme.outline.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text('Sign in to see your activity', style: GoogleFonts.ebGaramond(fontSize: 20)),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: () => context.push('/login'), child: const Text('Sign In')),
        ],
      ),
    );
  }
}
