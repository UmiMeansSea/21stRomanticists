import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:romanticists_app/models/post.dart';
import 'package:romanticists_app/models/category.dart';
import 'package:romanticists_app/models/feed_item.dart';
import 'package:romanticists_app/providers/auth_provider.dart';
import 'package:romanticists_app/providers/bookmarks_provider.dart';
import 'package:romanticists_app/services/firebase_service.dart';
import 'package:romanticists_app/widgets/save_to_collection_sheet.dart';
import 'package:romanticists_app/app_theme.dart';

/// Editorial post card — mirrors the Stitch design's surface-container-low
/// cards with minimal borders, serif headings, and clean typography.
class PostCard extends StatelessWidget {
  final Post post;
  final List<Category> categories;
  final bool featured; // true → larger "featured" layout

  const PostCard({
    super.key,
    required this.post,
    this.categories = const [],
    this.featured = false,
  });

  String get _categoryLabel {
    if (categories.isEmpty) return '';
    for (final c in categories) {
      if (post.categories.contains(c.id)) return c.name;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return featured ? _FeaturedCard(post: post, categoryLabel: _categoryLabel)
                    : _StandardCard(post: post, categoryLabel: _categoryLabel);
  }
}

// ─── Featured (large) card ─────────────────────────────────────────────────

class _FeaturedCard extends StatelessWidget {
  final Post post;
  final String categoryLabel;

  const _FeaturedCard({required this.post, required this.categoryLabel});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/post/${post.id}', extra: post),
      child: _CardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image hero with floating bookmark
            Stack(
              children: [
                if (post.imageUrl.isNotEmpty)
                  _PostImage(url: post.imageUrl),
                Positioned(
                  top: 16,
                  right: 16,
                  child: _BookmarkButton.fromPost(post, floating: true),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _CommunityBadge(category: categoryLabel, date: post.publishedAt),
                  const SizedBox(height: 16),
                  Text(
                    post.cleanTitle,
                    style: GoogleFonts.ebGaramond(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                      letterSpacing: -0.5,
                      color: AppColors.onSurface,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    post.cleanExcerpt,
                    style: GoogleFonts.ebGaramond(
                      fontSize: 18,
                      height: 1.6,
                      color: AppColors.onSurfaceVariant,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: AppColors.surfaceBright),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _AuthorRow(
                        authorName: post.author,
                        authorId: post.authorId.toString(),
                      ),
                      const Spacer(),
                      _EngagementRow(
                        likeCount: 0,
                        commentCount: 0,
                        reshareCount: 0,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Standard card ─────────────────────────────────────────────────────────

class _StandardCard extends StatelessWidget {
  final Post post;
  final String categoryLabel;

  const _StandardCard({required this.post, required this.categoryLabel});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/post/${post.id}', extra: post),
      child: _CardShell(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            if (post.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CachedNetworkImage(
                    imageUrl: post.imageUrl,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 120,
                      height: 120,
                      color: AppColors.surfaceBright,
                    ),
                  ),
                ),
              ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CommunityBadge(category: categoryLabel, date: post.publishedAt),
                    const SizedBox(height: 8),
                    Text(
                      post.cleanTitle,
                      style: GoogleFonts.ebGaramond(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: AppColors.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _AuthorRow(
                          authorName: post.author,
                          authorId: post.authorId.toString(),
                          small: true,
                        ),
                        const Spacer(),
                        _BookmarkButton.fromPost(post, size: 18),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared sub-widgets ────────────────────────────────────────────────────

class _CardShell extends StatefulWidget {
  final Widget child;
  const _CardShell({required this.child});

  @override
  State<_CardShell> createState() => _CardShellState();
}

class _CardShellState extends State<_CardShell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovered ? 0.3 : 0.1),
                blurRadius: _hovered ? 24 : 12,
                offset: Offset(0, _hovered ? 12 : 4),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _PostImage extends StatelessWidget {
  final String url;
  final double? height;
  final double aspectRatio;
  const _PostImage({required this.url, this.height, this.aspectRatio = 16 / 9});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: url,
              width: double.infinity,
              height: height,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: double.infinity,
                height: height,
                color: AppColors.surfaceBright,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                width: double.infinity,
                height: height,
                color: AppColors.surfaceBright,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.auto_stories_outlined,
                        color: AppColors.onSurfaceVariant.withValues(alpha: 0.4), size: 40),
                  ],
                ),
              ),
            ),
            // Gradient Overlay (image-fade-overlay)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      AppColors.surfaceContainer,
                      AppColors.surfaceContainer.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.4],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final DateTime date;
  final String category;
  const _DateChip({required this.date, required this.category});

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat('MMMM d, yyyy').format(date);
    return Text(
      category.isNotEmpty ? '$category • $formatted' : formatted,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: AppColors.secondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  final String authorName;
  final String authorId;
  final bool small;

  const _AuthorRow({
    required this.authorName,
    required this.authorId,
    this.small = false,
  });

  Future<Map<String, dynamic>?> _fetchUserInfo() async {
    try {
      return await FirebaseService.instance.getUserPublicInfo(authorId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/user/$authorId?name=$authorName'),
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchUserInfo(),
        builder: (context, snapshot) {
          final info = snapshot.data;
          final username = info?['username'] as String? ?? authorName;
          final avatarUrl = info?['profilePicture'] as String?;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surfaceBright, width: 2),
                ),
                child: CircleAvatar(
                  radius: small ? 16 : 24,
                  backgroundColor: AppColors.surfaceBright,
                  backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl) : null,
                  child: avatarUrl == null
                      ? Text(
                          authorName[0].toUpperCase(),
                          style: GoogleFonts.ebGaramond(
                            fontSize: small ? 14 : 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '@$username',
                    style: GoogleFonts.ebGaramond(
                      fontSize: small ? 14 : 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                  Text(
                    'SUBSCRIBE',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Bookmark button ─────────────────────────────────────────────────────────

class _EngagementRow extends StatelessWidget {
  final int likeCount;
  final int commentCount;
  final int reshareCount;
  final bool isLiked;
  final bool isReshared;
  final bool small;

  const _EngagementRow({
    required this.likeCount,
    required this.commentCount,
    required this.reshareCount,
    this.isLiked = false,
    this.isReshared = false,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EngagementItem(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          count: likeCount,
          color: isLiked ? Colors.redAccent : AppColors.onSurfaceVariant,
          small: small,
        ),
        const SizedBox(width: 16),
        _EngagementItem(
          icon: Icons.chat_bubble_outline,
          count: commentCount,
          small: small,
        ),
        const SizedBox(width: 16),
        _EngagementItem(
          icon: Icons.repeat,
          count: reshareCount,
          color: isReshared ? Colors.greenAccent : AppColors.onSurfaceVariant,
          small: small,
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.ios_share,
          size: small ? 14 : 18,
          color: AppColors.onSurfaceVariant,
        ),
      ],
    );
  }
}

class _EngagementItem extends StatelessWidget {
  final IconData icon;
  final int count;
  final String? label;
  final Color? color;
  final bool small;

  const _EngagementItem({
    required this.icon,
    required this.count,
    this.label,
    this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: small ? 16 : 20,
          color: color ?? AppColors.onSurfaceVariant,
        ),
        const SizedBox(height: 2),
        Text(
          label ?? count.toString(),
          style: GoogleFonts.inter(
            fontSize: small ? 9 : 10,
            fontWeight: FontWeight.w600,
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ─── Bookmark button ─────────────────────────────────────────────────────────
class _BookmarkButton extends StatelessWidget {
  final String id;
  final String title;
  final String excerpt;
  final String? imageUrl;
  final String author;
  final DateTime publishedAt;
  final List<int> categories;
  final String slug;
  final String link;
  final double size;

  const _BookmarkButton({
    required this.id,
    required this.title,
    required this.excerpt,
    this.imageUrl,
    required this.author,
    required this.publishedAt,
    this.categories = const [],
    this.slug = '',
    this.link = '',
    this.size = 20,
    this.floating = false,
  });

  final bool floating;

  factory _BookmarkButton.fromPost(Post post, {double size = 20, bool floating = false}) {
    return _BookmarkButton(
      id: post.id.toString(),
      title: post.cleanTitle,
      excerpt: post.cleanExcerpt,
      imageUrl: post.imageUrl,
      author: post.author,
      publishedAt: post.publishedAt,
      categories: post.categories,
      slug: post.slug,
      link: post.link,
      size: size,
      floating: floating,
    );
  }

  factory _BookmarkButton.fromItem(FeedItem item, {double size = 20, bool floating = false}) {
    return _BookmarkButton(
      id: item.uniqueId,
      title: item.title,
      excerpt: item.excerpt,
      imageUrl: item.imageUrl,
      author: item.authorName,
      publishedAt: item.publishedAt,
      size: size,
      floating: floating,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BookmarksProvider>(
      builder: (context, bm, _) {
        final saved = bm.isBookmarked(id);
        Widget button = Container(
          padding: EdgeInsets.all(floating ? 10 : 0),
          decoration: floating ? BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ) : null,
          child: Icon(
            saved ? Icons.bookmark : Icons.bookmark_border_rounded,
            size: size,
            color: saved ? AppColors.primary : (floating ? Colors.white : AppColors.onSurfaceVariant),
          ),
        );

        if (floating) {
          button = ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: button,
            ),
          );
        }

        return GestureDetector(
          onTap: () async {
            final auth = context.read<AuthProvider>();
            if (!auth.isAuthenticated) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Sign in to save posts.',
                      style: GoogleFonts.literata(color: Colors.white)),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                  action: SnackBarAction(
                    label: 'Sign In',
                    textColor: Colors.white70,
                    onPressed: () => context.push('/login'),
                  ),
                ),
              );
              return;
            }

            final wasSaved = saved;
            // Toggle bookmark state (Optimistic)
            await bm.toggle(
              id: id,
              title: title,
              excerpt: excerpt,
              imageUrl: imageUrl,
              author: author,
              publishedAt: publishedAt,
              categories: categories,
              slug: slug,
              link: link,
            );

            // Open collection sheet only if JUST saved
            if (context.mounted && !wasSaved) {
              await SaveToCollectionSheet.show(
                context,
                uid: auth.uid!,
                id: id,
                title: title,
                excerpt: excerpt,
                imageUrl: imageUrl,
                author: author,
                publishedAt: publishedAt,
              );
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                saved ? Icons.bookmark : Icons.bookmark_border_outlined,
                key: ValueKey(saved),
                size: size,
                color: saved ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Shimmer skeleton ─────────────────────────────────────────────────────

class PostCardSkeleton extends StatefulWidget {
  final bool featured;
  const PostCardSkeleton({super.key, this.featured = false});

  @override
  State<PostCardSkeleton> createState() => _PostCardSkeletonState();
}

class _PostCardSkeletonState extends State<PostCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _shimmer = Tween<double>(begin: 0.4, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _block(double w, double h) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, __) => Container(
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh.withValues(alpha: _shimmer.value),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.featured) {
      return Container(
        color: AppColors.surfaceContainerLow,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(aspectRatio: 16/9, child: _block(double.infinity, 220)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _block(100, 12),
                  const SizedBox(height: 12),
                  _block(double.infinity, 32),
                  const SizedBox(height: 8),
                  _block(double.infinity * 0.7, 16),
                  const SizedBox(height: 12),
                  _block(double.infinity, 14),
                  const SizedBox(height: 6),
                  _block(double.infinity, 14),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      color: AppColors.surfaceContainerLow,
      height: 120,
      child: Row(
        children: [
          _block(100, 120),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _block(80, 10),
                  const SizedBox(height: 8),
                  _block(double.infinity, 18),
                  const SizedBox(height: 6),
                  _block(double.infinity, 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Category chip for the filter tab row.
class CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(2),
        ),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: selected ? AppColors.onPrimary : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FeedCard — unified card for both WP posts and community submissions
// ─────────────────────────────────────────────────────────────────────────────

/// Renders the correct card for a [FeedItem]: a [PostCard] for WordPress posts,
/// or a community submission card for Firestore submissions.
class FeedCard extends StatelessWidget {
  final FeedItem item;
  final bool featured;

  const FeedCard({super.key, required this.item, this.featured = false});

  @override
  Widget build(BuildContext context) {
    if (!item.isSubmission && item.wpPost != null) {
      return PostCard(
        post: item.wpPost!,
        categories: const [],
        featured: featured,
      );
    }
    // Community submission
    return featured
        ? _FeaturedSubmissionCard(item: item)
        : _StandardSubmissionCard(item: item);
  }
}

class _FeaturedSubmissionCard extends StatelessWidget {
  final FeedItem item;
  const _FeaturedSubmissionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/submission/${item.uniqueId}', extra: item.submission),
      child: _CardShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.imageUrl != null)
              Stack(
                children: [
                  _PostImage(url: item.imageUrl!, height: 220),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: _BookmarkButton.fromItem(item, floating: true),
                  ),
                ],
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _CommunityBadge(category: item.categoryLabel, date: item.publishedAt),
                  const SizedBox(height: 16),
                  Text(
                    item.title,
                    style: GoogleFonts.ebGaramond(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                      letterSpacing: -0.5,
                      color: AppColors.onSurface,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    item.excerpt,
                    style: GoogleFonts.ebGaramond(
                      fontSize: 18,
                      height: 1.6,
                      color: AppColors.onSurfaceVariant,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.tags.isNotEmpty) ...[  
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: item.tags
                          .map((t) => _InlineTag(tag: t))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: AppColors.surfaceBright),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _AuthorRow(
                        authorName: item.authorName,
                        authorId: item.authorFirebaseId,
                      ),
                      const Spacer(),
                      _EngagementRow(
                        likeCount: item.likeCount,
                        commentCount: item.commentCount,
                        reshareCount: item.reshareCount,
                        isLiked: item.isLiked,
                        isReshared: item.isReshared,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StandardSubmissionCard extends StatelessWidget {
  final FeedItem item;
  const _StandardSubmissionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/submission/${item.uniqueId}', extra: item.submission),
      child: _CardShell(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.imageUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl!,
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 120, height: 120,
                      color: AppColors.surfaceBright,
                    ),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CommunityBadge(category: item.categoryLabel, date: item.publishedAt),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      style: GoogleFonts.ebGaramond(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: AppColors.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _AuthorRow(
                          authorName: item.authorName,
                          authorId: item.authorFirebaseId,
                          small: true,
                        ),
                        const Spacer(),
                        _EngagementRow(
                          likeCount: item.likeCount,
                          commentCount: item.commentCount,
                          reshareCount: item.reshareCount,
                          isLiked: item.isLiked,
                          isReshared: item.isReshared,
                          small: true,
                        ),
                        const SizedBox(width: 12),
                        _BookmarkButton.fromItem(item, size: 18),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityBadge extends StatelessWidget {
  final String category;
  final DateTime date;
  const _CommunityBadge({required this.category, required this.date});

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat('MMMM d, yyyy').format(date);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Text(
            '✦ Community',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.accent,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          category.isNotEmpty ? '$category • $formatted' : formatted,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
            color: AppColors.secondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _InlineTag extends StatelessWidget {
  final String tag;
  const _InlineTag({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Text(
      '#$tag',
      style: GoogleFonts.inter(
        fontSize: 11,
        color: AppColors.primary.withValues(alpha: 0.6),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
