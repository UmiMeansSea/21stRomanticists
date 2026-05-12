import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:romanticists_app/app_theme.dart';
import 'package:romanticists_app/providers/auth_provider.dart';

class InteractionBar extends StatelessWidget {
  final int likeCount;
  final int commentCount;
  final int reshareCount;
  final bool isLiked;
  final bool isReshared;
  final bool isSaved;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onReshare;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final bool visible;

  const InteractionBar({
    super.key,
    required this.likeCount,
    required this.commentCount,
    required this.reshareCount,
    this.isLiked = false,
    this.isReshared = false,
    this.isSaved = false,
    required this.onLike,
    required this.onComment,
    required this.onReshare,
    required this.onSave,
    required this.onShare,
    this.visible = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 1.5),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
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
                icon: isLiked ? Icons.favorite : Icons.favorite_border,
                label: _formatCount(likeCount),
                color: isLiked ? Colors.redAccent : Colors.white,
                onTap: () => _guardedAction(context, onLike),
              ),
              const _Divider(),
              _InteractionItem(
                icon: Icons.chat_bubble_outline,
                label: _formatCount(commentCount),
                onTap: () => _guardedAction(context, onComment),
              ),
              const _Divider(),
              _InteractionItem(
                icon: Icons.repeat, 
                label: _formatCount(reshareCount),
                color: isReshared ? Colors.greenAccent : Colors.white,
                onTap: () => _guardedAction(context, onReshare),
              ),
              const _Divider(),
              _InteractionItem(
                icon: isSaved ? Icons.bookmark : Icons.bookmark_border_outlined,
                color: isSaved ? AppColors.accent : Colors.white,
                onTap: () => _guardedAction(context, onSave),
              ),
              const _Divider(),
              _InteractionItem(
                icon: Icons.share_outlined,
                onTap: onShare, // Sharing is usually allowed for guests
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

  // ─── AUTH GUARD ────────────────────────────────────────────────────────────
  
  /// Checks if the user is logged in before executing an engagement action.
  /// If not, shows a SnackBar prompting the user to login.
  void _guardedAction(BuildContext context, VoidCallback action) {
    final auth = context.read<AuthProvider>();
    if (auth.isAuthenticated) {
      action();
    } else {
      // User is a guest: Block action and show login prompt
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Login needed, sign up first.',
            style: GoogleFonts.literata(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'LOGIN',
            textColor: AppColors.accent,
            onPressed: () => context.push('/login'),
          ),
        ),
      );
    }
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
