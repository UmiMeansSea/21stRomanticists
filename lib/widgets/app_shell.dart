import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:romanticists_app/app_theme.dart';
import 'package:romanticists_app/providers/posts_provider.dart';
import 'package:romanticists_app/providers/upload_provider.dart';

/// The root shell widget that owns the bottom navigation bar.
/// go_router's ShellRoute renders child screens inside this.
class AppShell extends StatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  DateTime? _lastPressedTime;

  static const _tabs = [
    _TabItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home', path: '/'),
    _TabItem(icon: Icons.notifications_none_outlined, activeIcon: Icons.notifications, label: 'Activity', path: '/notifications'),
    _TabItem(icon: Icons.edit_note_outlined, activeIcon: Icons.edit_note, label: 'Write', path: '/write'),
    _TabItem(icon: Icons.bookmark_border_outlined, activeIcon: Icons.bookmark, label: 'Saved', path: '/bookmarks'),
    _TabItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile', path: '/profile'),
  ];

  int _currentIndex(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    if (loc.startsWith('/notifications')) return 1;
    if (loc.startsWith('/write')) return 2;
    if (loc.startsWith('/bookmarks')) return 3;
    if (loc.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);

    return PopScope(
      canPop: false, // Always intercept to handle double-back logic
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // FIX 4: Double Back-Button to Exit
        if (idx != 0) {
          // If not on Home tab, switch to Home tab first
          context.go('/');
          return;
        }

        // We are on the Home tab (idx == 0)
        final now = DateTime.now();
        if (_lastPressedTime == null || 
            now.difference(_lastPressedTime!) > const Duration(seconds: 2)) {
          _lastPressedTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Press back again to exit',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          // Second press within 2 seconds, exit the app
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Stack(
          children: [
            widget.child,
            // ── Background Upload Overlay ───────────────────────────────────
            const _UploadOverlay(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            border: Border(
              top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 0.4),
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_tabs.length, (i) {
                  final tab = _tabs[i];
                  final selected = i == idx;
                  return _NavItem(
                    tab: tab,
                    selected: selected,
                    onTap: () {
                      if (selected) {
                        // If already on Home, refresh, clear filters and scroll to top
                        if (i == 0) {
                          final provider = context.read<PostsProvider>();
                          provider.clearFilters();
                          provider.refresh();
                          provider.requestScrollToTop();
                        }
                      } else {
                        context.go(tab.path);
                      }
                    },
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });
}

class _NavItem extends StatelessWidget {
  final _TabItem tab;
  final bool selected;
  final VoidCallback onTap;
  const _NavItem({required this.tab, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            top: selected
                ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
                : BorderSide.none,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? tab.activeIcon : tab.icon,
              color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              tab.label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadOverlay extends StatelessWidget {
  const _UploadOverlay();

  @override
  Widget build(BuildContext context) {
    final upload = context.watch<UploadProvider>();
    if (upload.status == UploadStatus.idle) return const SizedBox.shrink();

    final isUploading = upload.status == UploadStatus.uploading;
    final isSuccess = upload.status == UploadStatus.success;
    final isError = upload.status == UploadStatus.error;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isError ? Theme.of(context).colorScheme.errorContainer : Colors.black,
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isUploading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else if (isSuccess)
                const Icon(Icons.check_circle, color: Colors.green, size: 20)
              else if (isError)
                Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isUploading
                      ? 'Publishing your work...'
                      : isSuccess
                          ? 'Work published successfully'
                          : upload.errorMessage ?? 'Upload failed',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isError ? Theme.of(context).colorScheme.error : Colors.white,
                  ),
                ),
              ),
              if (!isUploading)
                GestureDetector(
                  onTap: () => context.read<UploadProvider>().reset(),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: isError ? Theme.of(context).colorScheme.error : Colors.white70,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
