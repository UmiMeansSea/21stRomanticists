import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:romanticists_app/app_theme.dart';
import 'package:romanticists_app/providers/auth_provider.dart';
import 'package:romanticists_app/services/engagement_service.dart';

class InteractionBar extends StatefulWidget {
  final String postId;
  final String? authorUid;
  final int likeCount;
  final int commentCount;
  final int reshareCount;
  final bool isLiked;
  final bool isReshared;
  final bool isSaved;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final bool visible;

  const InteractionBar({
    super.key,
    required this.postId,
    this.authorUid,
    required this.likeCount,
    required this.commentCount,
    required this.reshareCount,
    this.isLiked = false,
    this.isReshared = false,
    this.isSaved = false,
    required this.onComment,
    required this.onSave,
    required this.onShare,
    this.visible = true,
  });

  @override
  State<InteractionBar> createState() => _InteractionBarState();
}

class _InteractionBarState extends State<InteractionBar> {
  late int _localLikeCount;
  late int _localReshareCount;
  late bool _localIsLiked;
  late bool _localIsReshared;

  @override
  void initState() {
    super.initState();
    _localLikeCount = widget.likeCount;
    _localReshareCount = widget.reshareCount;
    _localIsLiked = widget.isLiked;
    _localIsReshared = widget.isReshared;
  }

  @override
  void didUpdateWidget(InteractionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync if external state changes (e.g. after a refresh)
    if (oldWidget.likeCount != widget.likeCount) _localLikeCount = widget.likeCount;
    if (oldWidget.reshareCount != widget.reshareCount) _localReshareCount = widget.reshareCount;
    if (oldWidget.isLiked != widget.isLiked) _localIsLiked = widget.isLiked;
    if (oldWidget.isReshared != widget.isReshared) _localIsReshared = widget.isReshared;
  }

  // ─── OPTIMISTIC HANDLERS ───────────────────────────────────────────────────

  Future<void> _handleLike() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return _showLoginPrompt();

    final prevIsLiked = _localIsLiked;
    final prevCount = _localLikeCount;

    setState(() {
      _localIsLiked = !_localIsLiked;
      _localLikeCount += _localIsLiked ? 1 : -1;
    });

    try {
      await EngagementService.instance.toggleLike(auth.uid!, widget.postId, prevIsLiked);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _localIsLiked = prevIsLiked;
        _localLikeCount = prevCount;
      });
      _showError('Failed to update like. Please try again.');
    }
  }

  Future<void> _handleReshare() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return _showLoginPrompt();

    final prevIsReshared = _localIsReshared;
    final prevCount = _localReshareCount;

    setState(() {
      _localIsReshared = !_localIsReshared;
      _localReshareCount += _localIsReshared ? 1 : -1;
    });

    try {
      await EngagementService.instance.toggleRepost(auth.uid!, widget.postId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _localIsReshared = prevIsReshared;
        _localReshareCount = prevCount;
      });
      _showError('Failed to update repost. Please try again.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showLoginPrompt() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Login needed, sign up first.', style: GoogleFonts.literata(color: Colors.white)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'LOGIN',
          textColor: AppColors.accent,
          onPressed: () => context.push('/login'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: widget.visible ? Offset.zero : const Offset(0, 1.5),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: widget.visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          margin: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1B1C19).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _InteractionItem(
                icon: _localIsLiked ? Icons.favorite : Icons.favorite_border,
                label: _formatCount(_localLikeCount),
                color: _localIsLiked ? Colors.redAccent : Colors.white,
                onTap: _handleLike,
              ),
              const _Divider(),
              _InteractionItem(
                icon: Icons.chat_bubble_outline,
                label: _formatCount(widget.commentCount),
                onTap: widget.onComment,
              ),
              const _Divider(),
              _InteractionItem(
                icon: Icons.repeat, 
                label: _formatCount(_localReshareCount),
                color: _localIsReshared ? Colors.greenAccent : Colors.white,
                onTap: _handleReshare,
              ),
              const _Divider(),
              _InteractionItem(
                icon: widget.isSaved ? Icons.bookmark : Icons.bookmark_border_outlined,
                color: widget.isSaved ? AppColors.accent : Colors.white,
                onTap: widget.onSave,
              ),
              const _Divider(),
              _InteractionItem(
                icon: Icons.share_outlined,
                onTap: widget.onShare,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}

class _InteractionItem extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Color color;
  final VoidCallback onTap;

  const _InteractionItem({
    required this.icon,
    this.label,
    this.color = Colors.white,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(
                label!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: Colors.white24,
    );
  }
}
