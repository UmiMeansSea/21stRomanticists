import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:romanticists_app/models/post.dart';
import 'package:romanticists_app/services/wp_api.dart';
import 'package:romanticists_app/app_theme.dart';

// ─── Route entry-point (StatefulWidget) ─────────────────────────────────────

/// Entry-point widget for /post/:id.
///
/// If [initialPost] is supplied (navigation from the feed via `extra`), it is
/// displayed immediately — no network round-trip.
/// If [initialPost] is null (deep-link or browser refresh), the post is
/// fetched from the WordPress REST API by [postId].
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
      if (mounted) {
        setState(() {
          _post = post;
          _loading = false;
        });
      }
    } on WpApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Could not load post. Please try again.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ── Loading ──
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.pop()),
          backgroundColor: AppColors.background,
        ),
        body: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
        ),
      );
    }

    // ── Error ──
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: BackButton(onPressed: () => context.pop()),
          backgroundColor: AppColors.background,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 56,
                  color: AppColors.outline.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 20),
                Text(
                  'Could not load post',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: _fetchPost,
                  child: const Text('Try Again'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Browse Posts'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Content ──
    if (_post == null) return const SizedBox.shrink();
    return _PostDetailBody(post: _post!);
  }
}

// ─── Pure-display body (no async) ────────────────────────────────────────────

class _PostDetailBody extends StatelessWidget {
  final Post post;
  const _PostDetailBody({required this.post});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMeta(context),
                  const SizedBox(height: 16),
                  _buildTitle(context),
                  const SizedBox(height: 20),
                  const Divider(thickness: 0.4),
                  const SizedBox(height: 20),
                  _buildContent(context),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    if (post.imageUrl.isNotEmpty) {
      return SliverAppBar(
        expandedHeight: 260,
        pinned: true,
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        leading: const _BackButton(),
        flexibleSpace: FlexibleSpaceBar(
          background: CachedNetworkImage(
            imageUrl: post.imageUrl,
            fit: BoxFit.cover,
            color: Colors.black.withValues(alpha: 0.25),
            colorBlendMode: BlendMode.darken,
          ),
        ),
      );
    }
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.primary,
      leading: const _BackButton(),
    );
  }

  Widget _buildMeta(BuildContext context) {
    final formatted = DateFormat('MMMM d, yyyy').format(post.publishedAt);
    return Text(
      '${post.author}  ·  $formatted',
      style: GoogleFonts.inter(
        fontSize: 12,
        color: AppColors.secondary,
        fontStyle: FontStyle.italic,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Text(
      post.cleanTitle,
      style: GoogleFonts.ebGaramond(
        fontSize: 36,
        fontWeight: FontWeight.w500,
        height: 1.15,
        color: AppColors.onSurface,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Html(
      data: post.content,
      style: {
        'body': Style(
          fontFamily: 'Literata',
          fontSize: FontSize(17),
          lineHeight: LineHeight(1.75),
          color: AppColors.onSurface,
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
        ),
        'p': Style(margin: Margins.only(bottom: 20)),
        'h1': Style(fontFamily: 'EB Garamond', color: AppColors.onSurface),
        'h2': Style(fontFamily: 'EB Garamond', color: AppColors.onSurface),
        'h3': Style(fontFamily: 'EB Garamond', color: AppColors.onSurface),
        'blockquote': Style(
          border: const Border(
            left: BorderSide(color: AppColors.outlineVariant, width: 3),
          ),
          padding: HtmlPaddings.only(left: 16),
          fontStyle: FontStyle.italic,
          color: AppColors.onSurfaceVariant,
        ),
        'em': Style(fontStyle: FontStyle.italic),
        'i': Style(fontStyle: FontStyle.italic),
        'a': Style(
          color: AppColors.secondary,
          textDecoration: TextDecoration.underline,
        ),
      },
    );
  }
}

// ─── Back button ─────────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => context.pop(),
    );
  }
}
