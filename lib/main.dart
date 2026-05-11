import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:romanticists_app/app_theme.dart';
import 'package:romanticists_app/providers/auth_provider.dart';
import 'package:romanticists_app/providers/bookmarks_provider.dart';
import 'package:romanticists_app/providers/posts_provider.dart';
import 'package:romanticists_app/providers/theme_provider.dart';
import 'package:romanticists_app/providers/collections_provider.dart';
import 'package:romanticists_app/providers/upload_provider.dart';
import 'package:romanticists_app/screens/bookmarks_screen.dart';
import 'package:romanticists_app/screens/home_screen.dart';
import 'package:romanticists_app/screens/notifications_screen.dart';
import 'package:romanticists_app/screens/post_detail.dart';
import 'package:romanticists_app/screens/category_screen.dart';
import 'package:romanticists_app/screens/login_screen.dart';
import 'package:romanticists_app/screens/settings_screen.dart';
import 'package:romanticists_app/screens/submit_screen.dart';
import 'package:romanticists_app/screens/profile_screen.dart';
import 'package:romanticists_app/screens/public_profile_screen.dart';
import 'package:romanticists_app/screens/edit_profile_screen.dart';
import 'package:romanticists_app/screens/collection_detail_screen.dart';
import 'package:romanticists_app/screens/submission_detail_screen.dart';
import 'package:romanticists_app/models/post.dart';
import 'package:romanticists_app/models/submission.dart';
import 'package:romanticists_app/services/notification_service.dart';
import 'package:romanticists_app/services/firebase_service.dart';
import 'package:romanticists_app/widgets/app_shell.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:romanticists_app/firebase_options.dart';

// ─── ANIMATION: Duration constants ──────────────────────────────────────────
// Centralised so every page transition shares the same timing.
const Duration _kPageTransitionDuration = Duration(milliseconds: 280);
const Duration _kTapAnimDuration        = Duration(milliseconds: 120);

// ─── ANIMATION: Custom page-transition builder ───────────────────────────────
// Replaces NoTransitionPage for full-screen routes.
// Combines a right-to-left SlideTransition with a FadeTransition for a
// native-feeling push animation at 60 fps.
CustomTransitionPage<T> _slideFadePage<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: _kPageTransitionDuration,
    reverseTransitionDuration: _kPageTransitionDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Slide from right edge (x=1.0) into place (x=0.0).
      final slide = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ));

      // Simultaneous fade (0.0 → 1.0) so the slide never feels abrupt.
      final fade = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
      );

      return FadeTransition(
        opacity: fade,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}

// ─── ANIMATION: Shell-tab transition ────────────────────────────────────────
// Bottom-nav tabs feel better with a simple cross-fade instead of a slide
// (avoids the "flying in from the side" effect inside the shell).
NoTransitionPage<T> _tabPage<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return NoTransitionPage<T>(key: state.pageKey, child: child);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.romanticSurface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await NotificationService.instance.init();
    debugPrint('[Firebase] initialized successfully');
  } catch (e) {
    debugPrint('[Firebase] init failed: $e');
  }

  runApp(const RomanticistsApp());
}

// ─── Root widget ────────────────────────────────────────────────────────────

class RomanticistsApp extends StatelessWidget {
  const RomanticistsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, PostsProvider>(
          create: (_) => PostsProvider(),
          update: (_, auth, posts) {
            final p = posts ?? PostsProvider();
            p.updateUserId(auth.uid);
            return p;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, BookmarksProvider>(
          create: (ctx) => BookmarksProvider(ctx.read<AuthProvider>()),
          update: (ctx, auth, prev) => prev ?? BookmarksProvider(auth),
        ),
        ChangeNotifierProvider(create: (_) => CollectionsProvider()),
        ChangeNotifierProvider(create: (_) => UploadProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp.router(
            title: 'The 21st Romanticists',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.themeMode,
            routerConfig: _router,
            builder: (context, child) {
              return Stack(
                children: [
                  if (child != null) child,
                  const _GlobalUploadOverlay(),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ─── go_router configuration ────────────────────────────────────────────────

final GoRouter _router = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true,

  routes: [
    // ── Shell route — wraps screens that show the bottom nav bar ──────────
    // [ANIMATION] Bottom-nav tabs use NoTransitionPage (instant swap) so the
    // tab bar itself provides the navigation affordance without a slide.
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => _tabPage(state: state, child: const HomeScreen()),
        ),
        GoRoute(
          path: '/notifications',
          pageBuilder: (context, state) => _tabPage(state: state, child: const NotificationsScreen()),
        ),
        GoRoute(
          path: '/write',
          pageBuilder: (context, state) => _tabPage(state: state, child: const SubmitScreen()),
        ),
        GoRoute(
          path: '/bookmarks',
          pageBuilder: (context, state) => _tabPage(state: state, child: const BookmarksScreen()),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => _tabPage(state: state, child: const ProfileScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => _tabPage(state: state, child: const SettingsScreen()),
        ),
      ],
    ),

    // ── Full-screen routes — slide-fade transition ─────────────────────────
    // [ANIMATION] All detail/full-screen pages use _slideFadePage so pushing
    // them onto the stack feels native (slides in from the right).
    GoRoute(
      path: '/post/:id',
      pageBuilder: (context, state) {
        final postId = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        final post = state.extra as Post?;
        final scrollToComments = state.uri.queryParameters['comment'] == 'true';
        return _slideFadePage(
          context: context,
          state: state,
          child: PostDetailScreen(
            postId: postId,
            initialPost: post,
            scrollToComments: scrollToComments,
          ),
        );
      },
    ),

    GoRoute(
      path: '/submission/:id',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final submission = state.extra as Submission?;
        final scrollToComments = state.uri.queryParameters['comment'] == 'true';

        if (submission != null) {
          return _slideFadePage(
            context: context,
            state: state,
            child: SubmissionDetailScreen(
              submission: submission,
              scrollToComments: scrollToComments,
            ),
          );
        }

        // Fallback: fetch from Firestore for deep links / refresh.
        return _slideFadePage(
          context: context,
          state: state,
          child: FutureBuilder<Submission?>(
            future: FirebaseService.instance.getSubmissionById(
              id.replaceFirst('sub_', ''),
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: AppColors.background,
                  body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return Scaffold(
                  backgroundColor: AppColors.background,
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.search_off_outlined, size: 48, color: AppColors.outline),
                        const SizedBox(height: 16),
                        Text('Submission not found.', style: GoogleFonts.ebGaramond(fontSize: 18)),
                        TextButton(onPressed: () => context.go('/'), child: const Text('Go Home')),
                      ],
                    ),
                  ),
                );
              }
              return SubmissionDetailScreen(
                submission: snapshot.data!,
                scrollToComments: scrollToComments,
              );
            },
          ),
        );
      },
    ),

    GoRoute(
      path: '/category/:id',
      pageBuilder: (context, state) {
        final categoryId = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        final categoryName = state.uri.queryParameters['name'] ?? 'Category';
        return _slideFadePage(
          context: context,
          state: state,
          child: CategoryScreen(categoryId: categoryId, categoryName: categoryName),
        );
      },
    ),

    GoRoute(
      path: '/user/:id',
      pageBuilder: (context, state) {
        final userId = state.pathParameters['id'] ?? '';
        final name = state.uri.queryParameters['name'];
        return _slideFadePage(
          context: context,
          state: state,
          child: PublicProfileScreen(userId: userId, initialName: name),
        );
      },
    ),

    GoRoute(
      path: '/edit-profile',
      pageBuilder: (context, state) => _slideFadePage(
        context: context,
        state: state,
        child: const EditProfileScreen(),
      ),
    ),

    GoRoute(
      path: '/collection/:uid/:id',
      pageBuilder: (context, state) {
        final uid   = state.pathParameters['uid'] ?? '';
        final colId = state.pathParameters['id'] ?? '';
        final name  = state.uri.queryParameters['name'] ?? 'Collection';
        return _slideFadePage(
          context: context,
          state: state,
          child: CollectionDetailScreen(uid: uid, collectionId: colId, collectionName: name),
        );
      },
    ),

    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => _slideFadePage(
        context: context,
        state: state,
        child: const LoginScreen(),
      ),
    ),
  ],

  // Global error page
  errorBuilder: (context, state) => Scaffold(
    backgroundColor: AppColors.background,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 56, color: AppColors.outline),
          const SizedBox(height: 16),
          Text('Page not found', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => context.go('/'),
            child: const Text('Go Home'),
          ),
        ],
      ),
    ),
  ),
);

// ─── ANIMATION: AnimatedTapButton ────────────────────────────────────────────
//
// A reusable wrapper that gives any child a 60 fps scale-down micro-interaction
// on press plus the standard ink ripple.  Drop it around any button, list tile,
// card, or icon you want to feel tappable.
//
// Usage:
//   AnimatedTapButton(
//     onTap: () => doSomething(),
//     child: MyWidget(),
//   );
class AnimatedTapButton extends StatefulWidget {
  const AnimatedTapButton({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    // How far to scale down (0.95 = 5% shrink — matches iOS feel).
    this.scaleFactor = 0.95,
    this.borderRadius = BorderRadius.zero,
    this.splashColor,
    this.highlightColor,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleFactor;
  final BorderRadius borderRadius;
  final Color? splashColor;
  final Color? highlightColor;
  final bool enabled;

  @override
  State<AnimatedTapButton> createState() => _AnimatedTapButtonState();
}

class _AnimatedTapButtonState extends State<AnimatedTapButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _kTapAnimDuration,
      // Immediately snaps back on release without blocking user input.
      reverseDuration: const Duration(milliseconds: 180),
      lowerBound: 0.0,
      upperBound: 1.0,
      value: 1.0,
    );

    _scale = Tween<double>(
      begin: 1.0,
      end: widget.scaleFactor,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (!widget.enabled) return;
    // Drive controller forward (scale down).
    _controller.animateTo(0.0);
  }

  void _onTapUp(TapUpDetails _) {
    if (!widget.enabled) return;
    // Animate back to 1.0 (full size).
    _controller.animateTo(1.0);
  }

  void _onTapCancel() {
    if (!widget.enabled) return;
    _controller.animateTo(1.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scale,
        child: Material(
          color: Colors.transparent,
          borderRadius: widget.borderRadius,
          child: InkWell(
            onTap: widget.enabled ? widget.onTap : null,
            onLongPress: widget.enabled ? widget.onLongPress : null,
            borderRadius: widget.borderRadius,
            // [ANIMATION] Splash colour inherits theme primary with low opacity
            // so it works in both light and dark mode automatically.
            splashColor: widget.splashColor
                ?? theme.colorScheme.primary.withValues(alpha: 0.12),
            highlightColor: widget.highlightColor
                ?? theme.colorScheme.primary.withValues(alpha: 0.06),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _GlobalUploadOverlay extends StatelessWidget {
  const _GlobalUploadOverlay();

  @override
  Widget build(BuildContext context) {
    return Consumer<UploadProvider>(
      builder: (context, provider, child) {
        if (provider.status == UploadStatus.idle) return const SizedBox.shrink();

        final bool isError = provider.status == UploadStatus.error;
        final bool isSuccess = provider.status == UploadStatus.success;

        return Positioned(
          top: MediaQuery.of(context).padding.top + 16,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isError ? Colors.red.shade800 : (isSuccess ? Colors.green.shade800 : AppColors.surfaceContainerHigh),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  if (provider.status == UploadStatus.uploading)
                    const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  else if (isSuccess)
                    const Icon(Icons.check_circle, color: Colors.white, size: 20)
                  else if (isError)
                    const Icon(Icons.error, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isError ? 'Upload failed: ${provider.errorMessage}' : (isSuccess ? 'Published successfully!' : 'Uploading...'),
                      style: GoogleFonts.inter(
                        color: isError || isSuccess ? Colors.white : AppColors.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
