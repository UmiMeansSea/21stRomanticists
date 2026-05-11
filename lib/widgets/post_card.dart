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
import 'package:romanticists_app/providers/posts_provider.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        _ShareButton(floating: true, size: 28, title: post.cleanTitle, link: post.link),
                      const SizedBox(width: 8),
                      _BookmarkButton.fromPost(post, floating: true, size: 28),
                    ],
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _CommunityBadge(categoryLabel, post.publishedAt),
                  const SizedBox(height: 16),
                  Text(
                    post.cleanTitle,
                    style: GoogleFonts.ebGaramond(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                      letterSpacing: -0.5,
                      color: Theme.of(context).colorScheme.onSurface,
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                        onComment: () => context.push('/post/${post.id}?comment=true', extra: post),
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
    final hasImage = post.imageUrl.isNotEmpty;
    return GestureDetector(
      onTap: () => context.push('/post/${post.id}', extra: post),
      child: _CardShell(
        child: hasImage
            ? _WpEditorialLayout(post: post, categoryLabel: categoryLabel)
            : _WpTweetLayout(post: post, categoryLabel: categoryLabel),
      ),
    );
  }
}

class _WpEditorialLayout extends StatelessWidget {
  final Post post;
  final String categoryLabel;
  const _WpEditorialLayout({required this.post, required this.categoryLabel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            _PostImage(url: post.imageUrl, height: 220),
            Positioned(
              top: 12, right: 12,
              child: Row(
                children: [
                  _ShareButton(floating: true, size: 26, title: post.cleanTitle, link: post.link),
                  const SizedBox(width: 8),
                  _BookmarkButton.fromPost(post, floating: true, size: 26),
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateChip(date: post.publishedAt, category: categoryLabel),
              const SizedBox(height: 10),
              Text(
                post.cleanTitle,
                style: GoogleFonts.ebGaramond(
                  fontSize: 24, fontWeight: FontWeight.w600, height: 1.2,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                post.cleanExcerpt,
                style: GoogleFonts.ebGaramond(
                  fontSize: 16, height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.surfaceBright),
              const SizedBox(height: 12),
              Row(
                children: [
                  _AuthorRow(
                    authorName: post.author,
                    authorId: post.authorId.toString(),
                    small: true,
                  ),
                  const Spacer(),
                  _ShareButton(size: 20, title: post.cleanTitle, link: post.link),
                  const SizedBox(width: 12),
                  _BookmarkButton.fromPost(post, size: 22),
                  const SizedBox(width: 8),
                  _MoreOptionsButton(
                    id: post.id.toString(),
                    title: post.cleanTitle,
                    link: post.link,
                    author: post.author,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WpTweetLayout extends StatelessWidget {
  final Post post;
  final String categoryLabel;
  const _WpTweetLayout({required this.post, required this.categoryLabel});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? AppColors.romanticPrimary : AppColors.primary;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 4, color: accentColor),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AuthorRow(
                    authorName: post.author,
                    authorId: post.authorId.toString(),
                    small: true,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '\u201C',
                    style: GoogleFonts.ebGaramond(
                      fontSize: 56, height: 0.6,
                      color: accentColor.withValues(alpha: 0.3),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    post.cleanTitle,
                    style: GoogleFonts.ebGaramond(
                      fontSize: 22, fontWeight: FontWeight.w600, height: 1.2,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    post.cleanExcerpt,
                    style: GoogleFonts.ebGaramond(
                      fontSize: 17, height: 1.6, fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 6, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  _DateChip(date: post.publishedAt, category: categoryLabel),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.surfaceBright),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _AuthorRow(
                        authorName: post.author,
                        authorId: post.authorId.toString(),
                        small: true,
                      ),
                      const Spacer(),
                      _ShareButton(size: 20, title: post.cleanTitle, link: post.link),
                      const SizedBox(width: 12),
                      _BookmarkButton.fromPost(post, size: 22),
                      const SizedBox(width: 8),
                      _MoreOptionsButton(
                        id: post.id.toString(),
                        title: post.cleanTitle,
                        link: post.link,
                        author: post.author,
                      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final shadowColor = isDark 
        ? Colors.black.withValues(alpha: _hovered ? 0.6 : 0.4)
        : AppColors.primary.withValues(alpha: _hovered ? 0.15 : 0.08);
    
    final glowColor = isDark 
        ? AppColors.romanticPrimary.withValues(alpha: _hovered ? 0.1 : 0)
        : Colors.white.withValues(alpha: _hovered ? 0.2 : 0);

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()..translate(0.0, _hovered ? -4.0 : 0.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              // Main Shadow
              BoxShadow(
                color: shadowColor,
                blurRadius: _hovered ? 32 : 16,
                offset: Offset(0, _hovered ? 16 : 8),
                spreadRadius: _hovered ? 2 : 0,
              ),
              // Magnetic Glow
              BoxShadow(
                color: glowColor,
                blurRadius: 40,
                spreadRadius: _hovered ? 5 : -5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: widget.child,
          ),
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
        child: CachedNetworkImage(
          imageUrl: url,
          imageBuilder: (context, imageProvider) => Stack(
            fit: StackFit.expand,
            children: [
              // Blurred Background
              Image(
                image: imageProvider,
                fit: BoxFit.cover,
              ),
              ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.15),
                  ),
                ),
              ),
              // Main Image (Full)
              Image(
                image: imageProvider,
                fit: BoxFit.contain,
                alignment: Alignment.center,
              ),
            ],
          ),
          placeholder: (_, __) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary),
            ),
          ),
          errorWidget: (_, __, ___) => Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_stories_outlined,
                    color: Color(0x66000000), size: 40),
              ],
            ),
          ),
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
  final bool isAnonymous;

  const _AuthorRow({
    required this.authorName,
    required this.authorId,
    this.small = false,
    this.isAnonymous = false,
  });

  Future<Map<String, dynamic>?> _fetchUserInfo() async {
    if (isAnonymous) return null;
    try {
      return await FirebaseService.instance.getUserPublicInfo(authorId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isAnonymous ? null : () => context.push('/user/$authorId?name=$authorName'),
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _fetchUserInfo(),
        builder: (context, snapshot) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final info = snapshot.data;
          final username = isAnonymous ? 'Anonymous' : (info?['displayName'] as String? ?? authorName);
          final avatarUrl = info?['photoURL'] as String?;

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppColors.romanticPrimary.withValues(alpha: 0.3) : AppColors.primary.withValues(alpha: 0.1),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: small ? 16 : 24,
                  backgroundColor: isDark ? AppColors.romanticSurfaceContainer : AppColors.surfaceContainerHigh,
                  backgroundImage: (!isAnonymous && avatarUrl != null) ? CachedNetworkImageProvider(avatarUrl) : null,
                  child: (isAnonymous || avatarUrl == null)
                      ? Icon(
                          isAnonymous ? Icons.person_outline : Icons.person,
                          size: small ? 18 : 28,
                          color: isDark ? AppColors.romanticOnSurface : AppColors.primary,
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
                    isAnonymous ? 'Anonymous' : '@$username',
                    style: GoogleFonts.ebGaramond(
                      fontSize: small ? 15 : 18,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (!isAnonymous)
                    GestureDetector(
                      onTap: () async {
                        final auth = context.read<AuthProvider>();
                        if (auth.uid == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Sign in to subscribe.')));
                          return;
                        }
                        await FirebaseService.instance.subscribe(auth.uid!, authorId, targetName: username);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Subscribed to @$username')));
                        }
                      },
                      child: Text(
                        'SUBSCRIBE',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: Theme.of(context).colorScheme.primary,
                        ),
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
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onReshare;

  const _EngagementRow({
    required this.likeCount,
    required this.commentCount,
    required this.reshareCount,
    this.isLiked = false,
    this.isReshared = false,
    this.small = false,
    this.onLike,
    this.onComment,
    this.onReshare,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _EngagementItem(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          count: likeCount,
          color: isLiked ? Colors.redAccent : Theme.of(context).colorScheme.onSurfaceVariant,
          small: small,
          onTap: () {
            final auth = context.read<AuthProvider>();
            if (!auth.isAuthenticated) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Sign in to like posts', style: GoogleFonts.literata(color: Colors.white)),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }
            onLike?.call();
          },
        ),
        SizedBox(width: small ? 24 : 36),
        _EngagementItem(
          icon: Icons.chat_bubble_outline,
          count: commentCount,
          small: small,
          onTap: onComment,
        ),
        SizedBox(width: small ? 24 : 36),
        _EngagementItem(
          icon: Icons.repeat,
          count: reshareCount,
          color: isReshared ? Colors.greenAccent : Theme.of(context).colorScheme.onSurfaceVariant,
          small: small,
          onTap: () {
            final auth = context.read<AuthProvider>();
            if (!auth.isAuthenticated) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Sign in to reshare', style: GoogleFonts.literata(color: Colors.white)),
                  backgroundColor: AppColors.primary,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }
            onReshare?.call();
          },
        ),
      ],
    );
  }
}

class _EngagementItem extends StatefulWidget {
  final IconData icon;
  final int count;
  final String? label;
  final Color? color;
  final bool small;
  final VoidCallback? onTap;

  const _EngagementItem({
    required this.icon,
    required this.count,
    this.label,
    this.color,
    this.small = false,
    this.onTap,
  });

  @override
  State<_EngagementItem> createState() => _EngagementItemState();
}

class _EngagementItemState extends State<_EngagementItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.onTap == null) return;
    _controller.forward(from: 0);
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: widget.small ? 20 : 26,
                color: widget.color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 4),
              Text(
                widget.label ?? widget.count.toString(),
                style: GoogleFonts.inter(
                  fontSize: widget.small ? 10 : 13,
                  fontWeight: FontWeight.w700,
                  color: widget.color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
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
  final String authorFirebaseId;
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
    this.authorFirebaseId = '',
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
      authorFirebaseId: '', // WP posts don't have Firebase IDs
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
      authorFirebaseId: item.authorFirebaseId,
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
              authorFirebaseId: authorFirebaseId,
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

class _MoreOptionsButton extends StatelessWidget {
  final String id;
  final String title;
  final String link;
  final String author;

  const _MoreOptionsButton({
    required this.id,
    required this.title,
    required this.link,
    required this.author,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz),
      iconSize: 22,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 180),
      color: Theme.of(context).colorScheme.surfaceContainer,
      iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) async {
        switch (value) {
          case 'share':
            await Share.share('$title\n\nRead it on The 21st Romanticists:\n$link');
            break;
          case 'copy':
            await Clipboard.setData(ClipboardData(text: link));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Link copied to clipboard', style: GoogleFonts.inter()),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            break;
          case 'report':
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Report submitted. Thank you.', style: GoogleFonts.inter()),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'share',
          child: Row(
            children: [
              const Icon(Icons.share_outlined, size: 18),
              const SizedBox(width: 12),
              Text('Share Post', style: GoogleFonts.inter(fontSize: 14)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              const Icon(Icons.copy_outlined, size: 18),
              const SizedBox(width: 12),
              Text('Copy Link', style: GoogleFonts.inter(fontSize: 14)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              Icon(Icons.report_gmailerrorred_outlined, size: 18, color: Theme.of(context).colorScheme.error),
              const SizedBox(width: 12),
              Text(
                'Report Content', 
                style: GoogleFonts.inter(fontSize: 14, color: Theme.of(context).colorScheme.error),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShareButton extends StatelessWidget {
  final bool floating;
  final double size;
  final String title;
  final String link;

  const _ShareButton({
    this.floating = false,
    this.size = 20,
    this.title = '',
    this.link = '',
  });

  @override
  Widget build(BuildContext context) {
    Widget button = Container(
      padding: EdgeInsets.all(floating ? 10 : 0),
      decoration: floating ? BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ) : null,
      child: Icon(
        Icons.ios_share,
        size: size,
        color: floating ? Colors.white : AppColors.onSurfaceVariant,
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
      onTap: () {
        final shareText = title.isNotEmpty && link.isNotEmpty
            ? '$title\n\nRead it on The 21st Romanticists:\n$link'
            : title.isNotEmpty
                ? title
                : 'Check out this post on The 21st Romanticists!';
        Share.share(shareText);
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: button,
      ),
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
    // Community submission — single unified card
    return _UnifiedSubmissionCard(item: item);
  }
}

/// Single unified card for community submissions.
/// Shows tweet-style (no image) or editorial (with image).
class _UnifiedSubmissionCard extends StatelessWidget {
  final FeedItem item;
  const _UnifiedSubmissionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;
    final isAnon = item.submission?.isAnonymous ?? false;

    return GestureDetector(
      onTap: () => context.push('/submission/${item.uniqueId}', extra: item.submission),
      child: _CardShell(
        child: IntrinsicHeight(
          child: hasImage
              ? _EditorialLayout(item: item, isAnon: isAnon)
              : _TweetLayout(item: item, isAnon: isAnon),
        ),
      ),
    );
  }
}

/// Editorial layout — has hero image on top.
class _EditorialLayout extends StatelessWidget {
  final FeedItem item;
  final bool isAnon;
  const _EditorialLayout({required this.item, required this.isAnon});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            _PostImage(url: item.imageUrl!, height: 220),
            Positioned(
              top: 12,
              right: 12,
              child: Row(
                children: [
                  _ShareButton(floating: true, size: 26, title: item.title, link: item.submission?.id ?? ''),
                  const SizedBox(width: 8),
                  _BookmarkButton.fromItem(item, floating: true, size: 26),
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CommunityBadge(item.categoryLabel, item.publishedAt),
              const SizedBox(height: 10),
              Text(
                item.title,
                style: GoogleFonts.ebGaramond(
                  fontSize: 24, fontWeight: FontWeight.w600, height: 1.2,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                item.excerpt,
                style: GoogleFonts.ebGaramond(
                  fontSize: 16, height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 2, overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.surfaceBright),
              const SizedBox(height: 12),
              _BottomActionBar(item: item, isAnon: isAnon),
            ],
          ),
        ),
      ],
    );
  }
}

/// Tweet-style layout — no image, shows full text prominently.
class _TweetLayout extends StatelessWidget {
  final FeedItem item;
  final bool isAnon;
  const _TweetLayout({required this.item, required this.isAnon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? AppColors.romanticPrimary : AppColors.primary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left accent bar
          Container(width: 4, color: accentColor),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author row
                  _AuthorRow(
                    authorName: item.authorName,
                    authorId: item.authorFirebaseId,
                    small: true,
                    isAnonymous: isAnon,
                  ),
                  const SizedBox(height: 16),
                  // Decorative opening quote
                  Text(
                    '\u201C',
                    style: GoogleFonts.ebGaramond(
                      fontSize: 56, height: 0.6,
                      color: accentColor.withValues(alpha: 0.3),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Title
                  Text(
                    item.title,
                    style: GoogleFonts.ebGaramond(
                      fontSize: 22, fontWeight: FontWeight.w600, height: 1.2,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Content preview — show more lines since no image
                  Text(
                    item.excerpt,
                    style: GoogleFonts.ebGaramond(
                      fontSize: 17, height: 1.6, fontStyle: FontStyle.italic,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 6, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  _CommunityBadge(item.categoryLabel, item.publishedAt),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.surfaceBright),
                  const SizedBox(height: 12),
                  _BottomActionBar(item: item, isAnon: isAnon),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared bottom action bar for all submission card types.
class _BottomActionBar extends StatelessWidget {
  final FeedItem item;
  final bool isAnon;
  const _BottomActionBar({required this.item, required this.isAnon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _EngagementRow(
          likeCount: item.likeCount,
          commentCount: item.commentCount,
          reshareCount: item.reshareCount,
          isLiked: item.isLiked,
          isReshared: item.isReshared,
          small: true,
          onComment: () => context.push(
              '/submission/${item.uniqueId}?comment=true', extra: item.submission),
          onLike: () => context.read<PostsProvider>().toggleLike(item),
          onReshare: () => context.read<PostsProvider>().toggleReshare(item),
        ),
        const Spacer(),
        _ShareButton(size: 20, title: item.title, link: item.wpPost?.link ?? ''),
        const SizedBox(width: 12),
        _BookmarkButton.fromItem(item, size: 22),
        const SizedBox(width: 8),
        _MoreOptionsButton(
          id: item.uniqueId,
          title: item.title,
          link: item.wpPost?.link ?? '',
          author: item.authorName,
        ),
      ],
    );
  }
}


class _CommunityBadge extends StatelessWidget {
  final String category;
  final DateTime date;

  _CommunityBadge(this.category, this.date);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formatted = DateFormat('MMMM d, yyyy').format(date);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.romanticPrimary.withValues(alpha: 0.2)
                : AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark
                  ? AppColors.romanticPrimary.withValues(alpha: 0.3)
                  : AppColors.primary.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
          child: Text(
            'COMMUNITY',
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: isDark ? AppColors.romanticPrimary : AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          category.isNotEmpty ? '$category | $formatted' : formatted,
          style: GoogleFonts.ebGaramond(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _InlineTag extends StatelessWidget {
  final String tag;

  _InlineTag(this.tag);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Text(
        '#$tag',
        style: GoogleFonts.inter(
          fontSize: 11,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
