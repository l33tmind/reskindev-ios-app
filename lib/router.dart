import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/gig_detail_screen.dart';
import 'screens/order_form_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/appearance_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/quick_replies_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/seller_profile_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/earnings_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/my_orders_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/seller_dashboard_screen.dart';
import 'screens/dynamic_page_screen.dart';
import 'screens/mobile_shell.dart';
import 'models/gig_model.dart';
import 'screens/gig_editor_screen.dart';
import 'screens/all_services_screen.dart';
import 'screens/login_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Page transition helper
// ─────────────────────────────────────────────────────────────────────────────
CustomTransitionPage<T> buildPageWithDefaultTransition<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 0.02);
      const end = Offset.zero;
      const curve = Curves.easeOutCubic;
      var slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: animation.drive(slideTween),
          child: child,
        ),
      );
    },
  );
}

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

// ─────────────────────────────────────────────────────────────────────────────
// Router
//
//  Web   → plain routes, no MobileShell / bottom nav
//  Mobile → ShellRoute wraps main pages with bottom nav + offline banner
// ─────────────────────────────────────────────────────────────────────────────
final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: kIsWeb ? '/' : '/splash',
  routes: [
    // ── Splash Screen ──────────────────────────────
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/splash',
      builder: (_, __) => const SplashScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/onboarding',
      builder: (_, __) => const OnboardingScreen(),
    ),

    // ── Mobile-only: bottom nav shell ──────────────────────────────
    if (!kIsWeb)
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) => MobileShell(
          currentPath: state.uri.path,
          child: child,
        ),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
          GoRoute(
            path: '/all-services', 
            builder: (_, state) => AllServicesScreen(
              initialCategory: state.uri.queryParameters['category'],
          autoFocusSearch: state.uri.queryParameters['search'] == 'true',
            )
          ),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(path: '/my-orders', builder: (_, __) => const MyOrdersScreen()),
          GoRoute(path: '/inbox', builder: (_, __) => const InboxScreen()),
        ],
      ),
    // ── Web-only: plain top-level routes ───────────────────────────
    if (kIsWeb) ...[
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/all-services', 
        builder: (_, state) => AllServicesScreen(
          initialCategory: state.uri.queryParameters['category'],
          autoFocusSearch: state.uri.queryParameters['search'] == 'true',
        )
      ),
      GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/my-orders', builder: (_, __) => const MyOrdersScreen()),
      GoRoute(path: '/inbox', builder: (_, __) => const InboxScreen()),
    ],

    // ── Shared routes (both web & mobile) ──────────────────────────
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/chat/:chatId',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return ChatScreen(
          chatId: state.pathParameters['chatId']!,
          targetUserId: extra['targetUserId'] ?? '',
          targetUserName: extra['targetUserName'] ?? 'Unknown',
          targetUserAvatar: extra['targetUserAvatar'] ?? '',
        );
      },
    ),

    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/favorites',
      builder: (_, __) => const FavoritesScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/appearance',
      builder: (_, __) => const AppearanceScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/login',
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/notification',
      builder: (_, __) => const NotificationsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/notifications',
      builder: (_, __) => const NotificationsScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/gig/:id',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context,
        state: state,
        child: GigDetailScreen(gigId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/gig/:id/:title',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context,
        state: state,
        child: GigDetailScreen(gigId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/order/:gigId/:pkg',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context,
        state: state,
        child: OrderFormScreen(
          gigId: state.pathParameters['gigId']!,
          packageName: state.pathParameters['pkg']!,
        ),
      ),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/admin',
      builder: (_, __) => const AdminDashboardScreen(),
      routes: [
        GoRoute(
          path: 'edit-gig',
          builder: (context, state) => GigEditorScreen(gig: state.extra as GigModel?),
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/quick-replies',
      builder: (_, __) => const QuickRepliesScreen(),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/seller',
      pageBuilder: (context, state) => buildPageWithDefaultTransition(
        context: context,
        state: state,
        child: const SellerDashboardScreen(),
      ),
      routes: [
        GoRoute(
          path: 'edit-gig',
          builder: (context, state) => GigEditorScreen(gig: state.extra as GigModel?),
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/page/:id',
      builder: (context, state) => DynamicPageScreen(pageIdOrSlug: state.pathParameters['id']!),
    ),
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/seller-profile/:id',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return SellerProfileScreen(
          sellerId: state.pathParameters['id']!,
          fallbackName: extra['fallbackName'] as String?,
          fallbackImage: extra['fallbackImage'] as String?,
        );
      },
    ),
    // Fallback route for dynamic pages by slug
    GoRoute(
      parentNavigatorKey: rootNavigatorKey,
      path: '/:slug',
      builder: (context, state) => DynamicPageScreen(pageIdOrSlug: state.pathParameters['slug']!),
    ),
  ],
);
