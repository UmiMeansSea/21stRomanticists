import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:romanticists_app/app_theme.dart';
import 'package:romanticists_app/models/submission.dart';

import 'package:provider/provider.dart';
import 'package:romanticists_app/providers/auth_provider.dart';
import 'package:romanticists_app/providers/posts_provider.dart';
import 'package:romanticists_app/services/read_status_service.dart';
import 'package:romanticists_app/models/comment.dart';
import 'package:romanticists_app/services/firebase_service.dart';
import 'package:romanticists_app/services/engagement_service.dart';
import 'package:romanticists_app/widgets/comment_bottom_sheet.dart';
import 'package:romanticists_app/widgets/interaction_bar.dart';
import 'package:romanticists_app/widgets/save_to_collection_sheet.dart';
import 'package:romanticists_app/providers/bookmarks_provider.dart';
import 'package:flutter/rendering.dart';

/// Full-screen reader for a community [Submission] stored in Firestore.
class SubmissionDetailScreen extends StatefulWidget {
  final Submission submission;
  final bool scrollToComments;
  const SubmissionDetailScreen({
    super.key, 
    required this.submission,
    this.scrollToComments = false,
  });

  @override
  State<SubmissionDetailScreen> createState() => _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState extends State<SubmissionDetailScreen> {
  late ScrollController _scrollController;
  bool _showInteractionBar = true;
  late Submission _submission;

  @override
  void initState() {
    super.initState();
    _submission = widget.submission;
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    _markAsRead();
    
    // Increment view count
    WidgetsBinding.instance.addPostFrameCallback((_) {
      EngagementService.instance.incrementViewCount(widget.submission.id!);
      
      // Auto-scroll to comments if requested
      if (widget.scrollToComments) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (_showInteractionBar) setState(() => _showInteractionBar = false);
    } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
      if (!_showInteractionBar) setState(() => _showInteractionBar = true);
    }
  }

  void _markAsRead() {
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      final uniqueId = widget.submission.wpId != null 
          ? 'wp_${widget.submission.wpId}' 
          : 'sub_${widget.submission.id}';
      ReadStatusService.instance.markAsRead(auth.uid!, widget.submission.id!);
      context.read<PostsProvider>().markAsReadLocally(uniqueId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final submission = _submission;
    final date = DateFormat('MMMM d, yyyy').format(submission.submittedAt);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.background,
            foregroundColor: AppColors.primary,
            elevation: 0,
            actions: [
              Consumer<BookmarksProvider>(
                builder: (context, bm, _) {
                  final uniqueId = submission.wpId != null 
                      ? submission.wpId.toString() 
                      : submission.id!;
                  final saved = bm.isBookmarked(uniqueId);
                  return IconButton(
                    icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border_outlined),
                    color: saved ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                    tooltip: 'Save to collection',
                    onPressed: _handleSave,
                  );
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz),
                color: Theme.of(context).colorScheme.surfaceContainer,
                iconColor: Theme.of(context).colorScheme.onSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                ),
                onSelected: (value) async {
                  switch (value) {
                    case 'follow':
                      final auth = context.read<AuthProvider>();
                      if (auth.isAuthenticated && submission.userId != null) {
                        try {
                          await FirebaseService.instance.subscribe(
                            auth.uid!,
                            submission.userId!,
                            targetName: submission.authorName,
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Following ${submission.authorName}', style: GoogleFonts.inter())),
                            );
                          }
                        } catch (e) {
                          debugPrint('Follow error: $e');
                        }
                      } else {
                        _showLoginPrompt();
                      }
                      break;
                    case 'copy_link':
                      final link = submission.wpId != null 
                          ? 'https://21stromanticists.com/?p=${submission.wpId}'
                          : 'https://21stromanticists.com/submission/${submission.id}';
                      Clipboard.setData(ClipboardData(text: link));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Link copied to clipboard', style: GoogleFonts.inter())),
                      );
                      break;
                    case 'share':
                      Share.share(
                        '${submission.title}\n\nBy ${submission.authorName}\n\n'
                        '${submission.content.length > 300 ? submission.content.substring(0, 300) + '…' : submission.content}',
                      );
                      break;
                    case 'save_image':
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Saved as image', style: GoogleFonts.inter())),
                      );
                      break;
                    case 'copy_text':
                      Clipboard.setData(ClipboardData(text: submission.content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Copied to clipboard', style: GoogleFonts.literata(color: Colors.white)),
                          backgroundColor: AppColors.primary,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      break;
                    case 'show_less':
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('You will see fewer posts like this', style: GoogleFonts.inter())),
                      );
                      break;
                    case 'mute':
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Author muted', style: GoogleFonts.inter())),
                      );
                      break;
                    case 'block':
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('User blocked', style: GoogleFonts.inter())),
                      );
                      break;
                    case 'report':
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Report submitted', style: GoogleFonts.inter())),
                      );
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'follow',
                    child: Row(
                      children: [
                        Icon(
                          Icons.person_add_outlined, 
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Follow ${submission.authorName}', 
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'copy_link',
                    child: Row(
                      children: [
                        Icon(
                          Icons.link, 
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Copy link', 
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(
                          Icons.share_outlined, 
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Share', 
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'save_image',
                    child: Row(
                      children: [
                        Icon(
                          Icons.download_outlined, 
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Save as image', 
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'copy_text',
                    child: Row(
                      children: [
                        Icon(
                          Icons.copy_outlined, 
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Copy text', 
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'show_less',
                    child: Row(
                      children: [
                        Icon(
                          Icons.close, 
                          size: 20,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Show less', 
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'mute',
                    child: Row(
                      children: [
                        const Icon(Icons.volume_off_outlined, size: 20, color: Colors.redAccent),
                        const SizedBox(width: 12),
                        Text('Mute author', style: GoogleFonts.inter(fontSize: 15, color: Colors.redAccent)),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'block',
                    child: Row(
                      children: [
                        const Icon(Icons.block_outlined, size: 20, color: Colors.redAccent),
                        const SizedBox(width: 12),
                        Text('Block', style: GoogleFonts.inter(fontSize: 15, color: Colors.redAccent)),
                      ],
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'report',
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 20, color: Colors.redAccent),
                        const SizedBox(width: 12),
                        Text('Report', style: GoogleFonts.inter(fontSize: 15, color: Colors.redAccent)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Cover image ─────────────────────────────────────────
                if (submission.imageUrl != null)
                  AspectRatio(
                    aspectRatio: 16/9,
                    child: CachedNetworkImage(
                      imageUrl: submission.imageUrl!,
                      imageBuilder: (context, imageProvider) => Stack(
                        fit: StackFit.expand,
                        children: [
                          Image(image: imageProvider, fit: BoxFit.cover),
                          ClipRect(
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.15),
                              ),
                            ),
                          ),
                          Image(image: imageProvider, fit: BoxFit.contain),
                        ],
                      ),
                      placeholder: (_, __) => Container(
                        color: AppColors.surfaceContainerHigh,
                      ),
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Category + date ────────────────────────────────
                      Text(
                        '${submission.category.label.toUpperCase()} • $date',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── Title ──────────────────────────────────────────
                      Text(
                        submission.title,
                        style: GoogleFonts.ebGaramond(
                          fontSize: 32,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Author ──────────────────────────────────────────
                      Text(
                        submission.isAnonymous
                            ? 'Anonymous'
                            : submission.authorName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // ── Tags ──────────────────────────────────────────
                      if (submission.tags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: submission.tags
                              .map((t) => _TagBadge(tag: t))
                              .toList(),
                        ),
                      ],

                      const SizedBox(height: 28),
                      const Divider(height: 1),
                      const SizedBox(height: 32),

                      // ── Content ────────────────────────────────────────
                      SelectableText(
                        submission.content,
                        style: GoogleFonts.literata(
                          fontSize: 17,
                          height: 1.9,
                          color: AppColors.onSurface,
                        ),
                      ),

                      const SizedBox(height: 48),
                      Center(
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
                      const SizedBox(height: 40),

                      // ── Author Profile & Engagement Section ──────────────────────────
                      _AuthorProfileSection(
                        userId: submission.userId,
                        authorName: submission.authorName,
                        postId: submission.id!,
                        postTitle: submission.title,
                        likeCount: submission.likeCount,
                        reshareCount: submission.reshareCount,
                        commentCount: submission.commentCount,
                        isAnonymous: submission.isAnonymous,
                      ),

                      const SizedBox(height: 48),

                      // ── Inline Comments ────────────────────────────────
                      _InlineCommentsSection(postId: submission.id!),
                      
                      const SizedBox(height: 100), // Space for interaction bar
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // ── Interaction Bar ──────────────────────────────────────────────
      Consumer<BookmarksProvider>(
        builder: (context, bm, _) {
          final uniqueId = submission.wpId != null 
              ? submission.wpId.toString() 
              : submission.id!;
          return InteractionBar(
            visible: _showInteractionBar,
            likeCount: submission.likeCount,
            commentCount: submission.commentCount,
            reshareCount: submission.reshareCount,
            isLiked: submission.isLiked,
            isReshared: submission.isReshared,
            isSaved: bm.isBookmarked(uniqueId),
            onLike: _handleLike,
            onComment: _handleComment,
            onReshare: _handleReshare,
            onSave: _handleSave,
            onShare: _handleShare,
          );
        },
      ),
    ],
  ),
);
}

void _handleSave() async {
  final auth = context.read<AuthProvider>();
  if (!auth.isAuthenticated) {
    _showLoginPrompt();
    return;
  }

  final bm = context.read<BookmarksProvider>();
  final uniqueId = _submission.wpId != null 
      ? _submission.wpId.toString() 
      : _submission.id!;
  
  final wasSaved = bm.isBookmarked(uniqueId);
  
  // Toggle bookmark (Optimistic)
  await bm.toggle(
    id: uniqueId,
    title: _submission.title,
    excerpt: _submission.excerpt,
    imageUrl: _submission.imageUrl,
    author: _submission.authorName,
    publishedAt: _submission.submittedAt,
  );

  if (mounted && !wasSaved) {
    await SaveToCollectionSheet.show(
      context,
      uid: auth.uid!,
      id: uniqueId,
      title: _submission.title,
      excerpt: _submission.excerpt,
      imageUrl: _submission.imageUrl,
      author: _submission.authorName,
      publishedAt: _submission.submittedAt,
    );
  }
}

void _handleLike() async {
final auth = context.read<AuthProvider>();
if (!auth.isAuthenticated) {
  _showLoginPrompt();
  return;
}

final service = EngagementService.instance;
try {
  if (_submission.isLiked) {
    await service.unlikePost(auth.uid!, _submission.id!);
    setState(() {
      _submission = _submission.copyWith(
        isLiked: false,
        likeCount: _submission.likeCount - 1,
      );
    });
  } else {
    await service.likePost(auth.uid!, _submission.id!, _submission.userId);
    setState(() {
      _submission = _submission.copyWith(
        isLiked: true,
        likeCount: _submission.likeCount + 1,
      );
    });
  }
} catch (e) {
  debugPrint('Like error: $e');
}
}

void _handleReshare() async {
final auth = context.read<AuthProvider>();
if (!auth.isAuthenticated) {
  _showLoginPrompt();
  return;
}

if (_submission.isReshared) return; // Only allow reshare once for now

final service = EngagementService.instance;
try {
  await service.restackPost(
    auth.uid!, 
    _submission.id!, 
    authorUid: _submission.userId,
    postTitle: _submission.title,
  );
  setState(() {
    _submission = _submission.copyWith(
      isReshared: true,
      reshareCount: _submission.reshareCount + 1,
    );
  });
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Restacked to your profile.', style: GoogleFonts.inter())),
  );
} catch (e) {
  debugPrint('Reshare error: $e');
}
}

void _handleComment() {
// TODO: Open comment bottom sheet
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Comments coming soon.', style: GoogleFonts.inter())),
);
}

void _handleShare() {
Share.share(
  '${_submission.title}\n\nBy ${_submission.authorName}\n\n'
  '${_submission.content.length > 300 ? _submission.content.substring(0, 300) + '…' : _submission.content}',
);
}

void _showLoginPrompt() {
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Sign in to interact with posts.',
        style: GoogleFonts.literata(color: Colors.white)),
    backgroundColor: AppColors.primary,
    behavior: SnackBarBehavior.floating,
  ),
);
}
}

class _AuthorProfileSection extends StatefulWidget {
  final String? userId;
  final String authorName;
  final String postId;
  final String postTitle;
  final int likeCount;
  final int reshareCount;
  final int commentCount;
  final bool isAnonymous;

  const _AuthorProfileSection({
    required this.userId,
    required this.authorName,
    required this.postId,
    required this.postTitle,
    required this.likeCount,
    required this.reshareCount,
    required this.commentCount,
    this.isAnonymous = false,
  });

  @override
  State<_AuthorProfileSection> createState() => _AuthorProfileSectionState();
}

class _AuthorProfileSectionState extends State<_AuthorProfileSection> {
  Map<String, dynamic>? _authorInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAuthorInfo();
  }

  Future<void> _fetchAuthorInfo() async {
    if (widget.userId == null || widget.isAnonymous) {
      setState(() => _isLoading = false);
      return;
    }
    final info = await FirebaseService.instance.getUserPublicInfo(widget.userId!);
    if (mounted) {
      setState(() {
        _authorInfo = info;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox(height: 100);

    final photoUrl = _authorInfo?['photoURL'] as String?;
    final bio = _authorInfo?['bio'] as String? ?? 'A passionate reader and romanticist.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.surfaceContainerHigh,
                backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
                child: photoUrl == null ? const Icon(Icons.person_outline, size: 28) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.authorName,
                      style: GoogleFonts.ebGaramond(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'Romanticist Writer',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (!widget.isAnonymous)
                ElevatedButton(
                  onPressed: () async {
                    if (widget.userId != null) {
                      try {
                        await FirebaseService.instance.subscribe(
                          context.read<AuthProvider>().uid!,
                          widget.userId!,
                          targetName: widget.authorName,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Subscribed to ${widget.authorName}')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to subscribe: $e')),
                          );
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    minimumSize: Size.zero,
                    elevation: 0,
                  ),
                  child: Text('Subscribe', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (!widget.isAnonymous) ...[
            Text(
              bio,
              style: GoogleFonts.literata(
                fontSize: 15,
                height: 1.6,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 24),
          ],
          const Divider(height: 1),
          const SizedBox(height: 20),
          
          // Engagement Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatItem(icon: Icons.favorite_border, label: 'Likes', count: widget.likeCount),
              _StatItem(icon: Icons.chat_bubble_outline, label: 'Comments', count: widget.commentCount),
              _StatItem(icon: Icons.repeat, label: 'Restacks', count: widget.reshareCount),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;

  const _StatItem({required this.icon, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.onSurfaceVariant),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurface,
          ),
        ),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 8,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppColors.outline,
          ),
        ),
      ],
    );
  }
}


class _InlineCommentsSection extends StatelessWidget {
  final String postId;

  const _InlineCommentsSection({required this.postId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StreamBuilder<List<Comment>>(
          stream: EngagementService.instance.getComments(postId),
          builder: (context, snapshot) {
            final count = snapshot.data?.length ?? 0;
            return Text(
              '$count comments',
              style: GoogleFonts.ebGaramond(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        
        // Comment input mimic
        InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => CommentBottomSheet(postId: postId),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  child: const Icon(Icons.person_outline, size: 16),
                ),
                const SizedBox(width: 12),
                Text(
                  'Leave a comment',
                  style: GoogleFonts.inter(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        StreamBuilder<List<Comment>>(
          stream: EngagementService.instance.getComments(postId),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox.shrink();
            }
            
            final comments = snapshot.data!;
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: comments.length > 5 ? 5 : comments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 24),
              itemBuilder: (context, index) {
                final comment = comments[index];
                return _CommentItem(comment: comment);
              },
            );
          },
        ),
      ],
    );
  }
}

class _CommentItem extends StatelessWidget {
  final Comment comment;
  const _CommentItem({required this.comment});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.surfaceContainerHigh,
          child: const Icon(Icons.person_outline, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    comment.authorName,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMM d').format(comment.createdAt),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                comment.content,
                style: GoogleFonts.literata(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('LIKE', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant)),
                  const SizedBox(width: 16),
                  Text('REPLY', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TagBadge extends StatelessWidget {
  final String tag;
  const _TagBadge({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        '#$tag',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
