import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:romanticists_app/app_theme.dart';
import 'package:romanticists_app/providers/posts_provider.dart';
import 'package:romanticists_app/screens/home_screen.dart';
import 'package:romanticists_app/screens/post_detail.dart';
import 'package:romanticists_app/screens/category_screen.dart';
import 'package:romanticists_app/screens/login_screen.dart';
import 'package:romanticists_app/screens/submit_screen.dart';
import 'package:romanticists_app/screens/profile_screen.dart';
import 'package:romanticists_app/models/post.dart';
import 'package:romanticists_app/widgets/app_shell.dart';

// ─── NOTE ──────────────────────────────────────────────────────────────────
// Firebase is NOT initialised yet — that happens on Day 2 once you add the
// google-services.json / GoogleService-Info.plist to the project.
// Uncomment the lines below after running `flutterfire configure`.
//
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';
// ───────────────────────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait — typical for a reading app.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style — transparent so our background shows through.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.surfaceContainerLow,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // ── Firebase init (uncomment on Day 2) ──
  // await Firebase.initializeApp(
  //   options: DefaultFirebaseOptions.currentPlatform,
  // );

  runApp(const RomanticistsApp());
}

// ─── Root widget ────────────────────────────────────────────────────────────

class RomanticistsApp extends StatelessWidget {
  const RomanticistsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PostsProvider()),
        // Day 3 — add AuthProvider here.
        // Day 5 — add BookmarksProvider here.
      ],
      child: MaterialApp.router(
        title: 'The 21st Romanticists',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
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
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/read',
          pageBuilder: (context, state) => const NoTransitionPage(
            // "Read" tab = same feed, could be a curated list later.
            child: HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/write',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SubmitScreen(),
          ),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ProfileScreen(),
          ),
        ),
      ],
    ),

    // ── Full-screen routes — no bottom nav ────────────────────────────────
    GoRoute(
      path: '/post/:id',
      builder: (context, state) {
        final postId = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        final post = state.extra as Post?;
        return PostDetailScreen(postId: postId, initialPost: post);
      },
    ),

    GoRoute(
      path: '/category/:id',
      builder: (context, state) {
        final categoryId =
            int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        final categoryName =
            state.uri.queryParameters['name'] ?? 'Category';
        return CategoryScreen(
          categoryId: categoryId,
          categoryName: categoryName,
        );
      },
    ),

    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
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
          Text(
            'Page not found',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
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

