import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:romanticists_app/models/post.dart';
import 'package:romanticists_app/models/category.dart';
import 'package:romanticists_app/providers/auth_provider.dart';
import 'package:romanticists_app/providers/bookmarks_provider.dart';
import 'package:romanticists_app/services/firebase_service.dart';
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
            // Image hero
            if (post.imageUrl.isNotEmpty)
              _PostImage(url: post.imageUrl, height: 220),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DateChip(date: post.publishedAt, category: categoryLabel),
                  const SizedBox(height: 10),
                  Text(
                    post.cleanTitle,
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontStyle: FontStyle.normal,
                          height: 1.15,
                        ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    post.cleanExcerpt,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _AuthorRow(
                        authorName: post.author,
                        authorId: post.authorId.toString(),
                      ),
                      const Spacer(),
                      _BookmarkButton(post: post),
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
                  topLeft: Radius.circular(2),
                  bottomLeft: Radius.circular(2),
                ),
                child: CachedNetworkImage(
                  imageUrl: post.imageUrl,
                  width: 100,
                  height: 120,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 100,
                    height: 120,
                    color: AppColors.surfaceContainerHigh,
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 100,
                    height: 120,
                    color: AppColors.surfaceContainerHigh,
                    child: const Icon(Icons.image_not_supported_outlined,
                        color: AppColors.outline, size: 24),
                  ),
                ),
              ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DateChip(date: post.publishedAt, category: categoryLabel),
                    const SizedBox(height: 6),
                    Text(
                      post.cleanTitle,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            height: 1.2,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _AuthorRow(
                          authorName: post.author,
                          authorId: post.authorId.toString(),
                          small: true,
                        ),
                        const Spacer(),
                        _BookmarkButton(post: post, size: 18),
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
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          border: Border.all(
            color: _hovered
                ? AppColors.outlineVariant.withValues(alpha: 0.5)
                : Colors.transparent,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        child: widget.child,
      ),
    );
  }
}

class _PostImage extends StatelessWidget {
  final String url;
  final double height;
  const _PostImage({required this.url, required this.height});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
      child: CachedNetworkImage(
        imageUrl: url,
        width: double.infinity,
        height: height,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: double.infinity,
          height: height,
          color: AppColors.surfaceContainerHigh,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          width: double.infinity,
          height: height,
          color: AppColors.surfaceContainerHigh,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_stories_outlined,
                  color: AppColors.outline.withValues(alpha: 0.4), size: 40),
            ],
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

  const _AuthorRow({
    required this.authorName,
    required this.authorId,
    this.small = false,
  });

  Future<String?> _fetchUsername() async {
    try {
      final info = await FirebaseService.instance.getUserPublicInfo(authorId);
      return info?['username'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/user/$authorId?name=$authorName'),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: small ? 10 : 12,
            backgroundColor: AppColors.surfaceContainerHigh,
            child: Text(
              authorName[0].toUpperCase(),
              style: GoogleFonts.ebGaramond(
                fontSize: small ? 10 : 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FutureBuilder<String?>(
            future: _fetchUsername(),
            builder: (context, snapshot) {
              final display = snapshot.hasData && (snapshot.data?.isNotEmpty ?? false)
                  ? '@${snapshot.data}'
                  : authorName;
              return Text(
                display,
                style: GoogleFonts.inter(
                  fontSize: small ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Bookmark button ─────────────────────────────────────────────────────────

class _BookmarkButton extends StatelessWidget {
  final Post post;
  final double size;
  const _BookmarkButton({required this.post, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Consumer<BookmarksProvider>(
      builder: (context, bm, _) {
        final saved = bm.isBookmarked(post.id);
        return GestureDetector(
          onTap: () {
            final auth = context.read<AuthProvider>();
            if (!auth.isAuthenticated) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Sign in to save posts.',
                    style: GoogleFonts.literata(color: Colors.white),
                  ),
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
            bm.toggle(post);
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
            _block(double.infinity, 220),
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
