import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:romanticists_app/models/post.dart';
import 'package:romanticists_app/providers/auth_provider.dart';
import 'package:romanticists_app/providers/bookmarks_provider.dart';
import 'package:romanticists_app/services/wp_api.dart';
import 'package:romanticists_app/app_theme.dart';

// ─── Route entry-point ────────────────────────────────────────────────────────

/// Entry-point widget for /post/:id.
///
/// If [initialPost] is supplied (navigation from the feed via `extra`), it is
/// displayed immediately — no network round-trip.
/// If [initialPost] is null (deep-link), the post is fetched from the API.
class PostDetailScreen extends StatefulWidget {
  final int postId;
  final Post? initialPost;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.initialPost,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  Post? _post;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialPost != null) {
      _post = widget.initialPost;
    } else {
      _fetchPost();
    }
  }

  Future<void> _fetchPost() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final post = await WpApiService.instance.fetchPost(widget.postId);
      if (mounted) setState(() { _post = post; _loading = false; });
    } on WpApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load post. Please try again.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: _BackArrow(),
          backgroundColor: AppColors.background,
        ),
        body: const Center(
          child: SizedBox(
            width: 28, height: 28,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(leading: _BackArrow(), backgroundColor: AppColors.background),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_outlined, size: 56,
                    color: AppColors.outline.withValues(alpha: 0.5)),
                const SizedBox(height: 20),
                Text('Could not load post',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(_error!, style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                OutlinedButton(onPressed: _fetchPost, child: const Text('Try Again')),
                const SizedBox(height: 12),
                TextButton(onPressed: () => context.go('/'), child: const Text('Browse Posts')),
              ],
            ),
          ),
        ),
      );
    }

    if (_post == null) return const SizedBox.shrink();
    return _PostDetailBody(post: _post!);
  }
}

// ─── Body with scroll tracking ────────────────────────────────────────────────

class _PostDetailBody extends StatefulWidget {
  final Post post;
  const _PostDetailBody({required this.post});

  @override
  State<_PostDetailBody> createState() => _PostDetailBodyState();
}

class _PostDetailBodyState extends State<_PostDetailBody> {
  final ScrollController _scroll = ScrollController();
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    final max = _scroll.position.maxScrollExtent;
    if (max == 0) return;
    final p = (_scroll.offset / max).clamp(0.0, 1.0);
    if ((p - _progress).abs() > 0.005) {
      setState(() => _progress = p);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  int get _readingMinutes {
    final words = widget.post.content.split(RegExp(r'\s+')).length;
    return ((words / 200).ceil()).clamp(1, 99);
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scroll,
            slivers: [
              _buildSliverAppBar(context, post),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MetaRow(post: post, readingMinutes: _readingMinutes),
                      const SizedBox(height: 18),
                      _Title(text: post.cleanTitle),
                      const SizedBox(height: 24),
                      const Divider(thickness: 0.4),
                      const SizedBox(height: 24),
                      _Content(html: post.content),
                      const SizedBox(height: 40),
                      _ArticleFooter(post: post),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Reading progress bar ──
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 2,
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.transparent,
                  color: AppColors.secondary,
                  minHeight: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, Post post) {
    final hasImage = post.imageUrl.isNotEmpty;

    return SliverAppBar(
      expandedHeight: hasImage ? 280 : 0,
      pinned: true,
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.primary,
      leading: _BackArrow(),
      actions: [
        _BookmarkAction(post: post),
        _ShareAction(post: post),
        const SizedBox(width: 4),
      ],
      flexibleSpace: hasImage
          ? FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: post.imageUrl,
                    fit: BoxFit.cover,
                  ),
                  // Gradient overlay so AppBar icons stay readable
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x88000000),
                          Colors.transparent,
                          Color(0xCCFBF9F3),
                        ],
                        stops: [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _MetaRow extends StatelessWidget {
  final Post post;
  final int readingMinutes;
  const _MetaRow({required this.post, required this.readingMinutes});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('MMMM d, yyyy').format(post.publishedAt);
    return Row(
      children: [
        // Author avatar
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.secondary,
          child: Text(
            post.author.isNotEmpty ? post.author[0].toUpperCase() : 'A',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.author,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              Text(
                '$date  ·  $readingMinutes min read',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.ebGaramond(
        fontSize: 36,
        fontWeight: FontWeight.w500,
        height: 1.15,
        color: AppColors.onSurface,
        letterSpacing: -0.5,
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final String html;
  const _Content({required this.html});

  @override
  Widget build(BuildContext context) {
    return Html(
      data: html,
      style: {
        'body': Style(
          fontFamily: 'Literata',
          fontSize: FontSize(17),
          lineHeight: LineHeight(1.8),
          color: AppColors.onSurface,
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
        ),
        'p': Style(margin: Margins.only(bottom: 22)),
        'h1': Style(fontFamily: 'EB Garamond', fontSize: FontSize(28),
            color: AppColors.onSurface, margin: Margins.only(top: 28, bottom: 10)),
        'h2': Style(fontFamily: 'EB Garamond', fontSize: FontSize(24),
            color: AppColors.onSurface, margin: Margins.only(top: 24, bottom: 8)),
        'h3': Style(fontFamily: 'EB Garamond', fontSize: FontSize(20),
            color: AppColors.onSurface, margin: Margins.only(top: 20, bottom: 6)),
        'blockquote': Style(
          border: const Border(
            left: BorderSide(color: AppColors.secondary, width: 3),
          ),
          padding: HtmlPaddings.only(left: 18),
          margin: Margins.only(left: 0, top: 16, bottom: 16),
          fontStyle: FontStyle.italic,
          fontSize: FontSize(18),
          color: AppColors.onSurfaceVariant,
        ),
        'em': Style(fontStyle: FontStyle.italic),
        'i': Style(fontStyle: FontStyle.italic),
        'strong': Style(fontWeight: FontWeight.w600, color: AppColors.onSurface),
        'a': Style(
          color: AppColors.secondary,
          textDecoration: TextDecoration.underline,
        ),
        'img': Style(
          margin: Margins.symmetric(vertical: 16),
        ),
      },
    );
  }
}

// ─── End-of-article footer ────────────────────────────────────────────────────

class _ArticleFooter extends StatelessWidget {
  final Post post;
  const _ArticleFooter({required this.post});

  @override
  Widget build(BuildContext context) {
    return Consumer<BookmarksProvider>(
      builder: (context, bm, _) {
        final saved = bm.isBookmarked(post.id);
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            border: Border.all(color: AppColors.outlineVariant, width: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Column(
            children: [
              Text(
                '— fin —',
                style: GoogleFonts.ebGaramond(
                  fontSize: 18,
                  fontStyle: FontStyle.italic,
                  color: AppColors.outline,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Did this piece move you?',
                style: GoogleFonts.ebGaramond(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Save it to your collection or share it with a fellow romanticist.',
                textAlign: TextAlign.center,
                style: GoogleFonts.literata(
                  fontSize: 13,
                  color: AppColors.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: Icon(
                        saved ? Icons.bookmark : Icons.bookmark_border_outlined,
                        size: 16,
                      ),
                      label: Text(saved ? 'Saved' : 'Save'),
                      onPressed: () {
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
                        bm.toggle(post);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: saved ? AppColors.secondary : AppColors.primary,
                        side: BorderSide(
                          color: saved ? AppColors.secondary : AppColors.primary,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.share_outlined, size: 16),
                      label: const Text('Share'),
                      onPressed: () => _sharePost(post),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(2)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _sharePost(Post post) {
    Share.share(
      '${post.cleanTitle}\n\nRead it on The 21st Romanticists:\n${post.link}',
      subject: post.cleanTitle,
    );
  }
}

// ─── AppBar action buttons ────────────────────────────────────────────────────

class _BookmarkAction extends StatelessWidget {
  final Post post;
  const _BookmarkAction({required this.post});

  @override
  Widget build(BuildContext context) {
    return Consumer<BookmarksProvider>(
      builder: (context, bm, _) {
        final saved = bm.isBookmarked(post.id);
        return IconButton(
          tooltip: saved ? 'Remove bookmark' : 'Save post',
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              saved ? Icons.bookmark : Icons.bookmark_border_outlined,
              key: ValueKey(saved),
              color: saved ? AppColors.secondary : AppColors.primary,
            ),
          ),
          onPressed: () {
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
            bm.toggle(post);
          },
        );
      },
    );
  }
}

class _ShareAction extends StatelessWidget {
  final Post post;
  const _ShareAction({required this.post});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Share',
      icon: const Icon(Icons.share_outlined),
      onPressed: () {
        Share.share(
          '${post.cleanTitle}\n\nRead it on The 21st Romanticists:\n${post.link}',
          subject: post.cleanTitle,
        );
      },
    );
  }
}

// ─── Back arrow ───────────────────────────────────────────────────────────────

class _BackArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => context.pop(),
    );
  }
}
