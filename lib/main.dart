import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:romanticists_app/app_theme.dart';
import 'package:romanticists_app/providers/auth_provider.dart';
import 'package:romanticists_app/providers/bookmarks_provider.dart';
import 'package:romanticists_app/providers/posts_provider.dart';
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

// ─── NOTE ──────────────────────────────────────────────────────────────────
// Firebase is NOT initialised yet — that happens on Day 2 once you add the
// google-services.json / GoogleService-Info.plist to the project.
// Uncomment the lines below after running `flutterfire configure`.
//
import 'package:firebase_core/firebase_core.dart';
import 'package:romanticists_app/firebase_options.dart';
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
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.romanticSurface,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // ── Firebase init — guarded so a slow/failing init never blocks the app ──
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await NotificationService.instance.init();
    debugPrint('[Firebase] initialized successfully');
  } catch (e) {
    // Firebase failed or timed out — the app still loads.
    // Firestore calls in FirebaseService will throw FirebaseServiceException
    // which is handled gracefully in the UI.
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
      ],
      child: MaterialApp.router(
        title: 'The 21st Romanticists',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        themeMode: ThemeMode.dark,
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
          path: '/notifications',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: NotificationsScreen(),
          ),
        ),
        GoRoute(
          path: '/write',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SubmitScreen(),
          ),
        ),
        GoRoute(
          path: '/bookmarks',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: BookmarksScreen(),
          ),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ProfileScreen(),
          ),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsScreen(),
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
      path: '/submission/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final submission = state.extra as Submission?;
        
        if (submission != null) {
          return SubmissionDetailScreen(submission: submission);
        }

        // Fallback for direct links or refreshes
        return FutureBuilder<Submission?>(
          future: FirebaseService.instance.getSubmissionById(id.replaceFirst('sub_', '')),
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
            return SubmissionDetailScreen(submission: snapshot.data!);
          },
        );
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
      path: '/user/:id',
      builder: (context, state) {
        final userId = state.pathParameters['id'] ?? '';
        final name = state.uri.queryParameters['name'];
        return PublicProfileScreen(userId: userId, initialName: name);
      },
    ),

    GoRoute(
      path: '/edit-profile',
      builder: (context, state) => const EditProfileScreen(),
    ),

    GoRoute(
      path: '/collection/:uid/:id',
      builder: (context, state) {
        final uid = state.pathParameters['uid'] ?? '';
        final colId = state.pathParameters['id'] ?? '';
        final name = state.uri.queryParameters['name'] ?? 'Collection';
        return CollectionDetailScreen(
          uid: uid,
          collectionId: colId,
          collectionName: name,
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

