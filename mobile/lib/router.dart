import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/code_screen.dart';
import 'features/auth/phone_screen.dart';
import 'features/auth/privacy_screen.dart';
import 'features/contacts/contacts_screen.dart';
import 'features/feedback/feedback.dart';
import 'features/feedback/feedback_form_screen.dart';
import 'features/feedback/my_feedback_screen.dart';
import 'features/loyalty/loyalty_screen.dart';
import 'features/menu/menu_screen.dart';
import 'features/news/news_detail_screen.dart';
import 'features/news/news_feed_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/shell/app_shell.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/news',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/news', builder: (_, _) => const NewsFeedScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/menu', builder: (_, _) => const MenuScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/card', builder: (_, _) => const LoyaltyScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/contacts', builder: (_, _) => const ContactsScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())]),
        ],
      ),
      GoRoute(
        path: '/news/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => NewsDetailScreen(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, _) => const MaterialPage(fullscreenDialog: true, child: PhoneScreen()),
      ),
      GoRoute(
        path: '/login/code',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (_, state) => state.extra is CodeScreenArgs ? null : '/login',
        builder: (_, state) => CodeScreen(args: state.extra! as CodeScreenArgs),
      ),
      GoRoute(
        path: '/feedback/new',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, state) => FeedbackFormScreen(
          initialType: FeedbackType.fromCode(state.uri.queryParameters['type'] ?? 'complaint'),
        ),
      ),
      GoRoute(
        path: '/feedback/mine',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const MyFeedbackScreen(),
      ),
      GoRoute(
        path: '/privacy',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const PrivacyScreen(),
      ),
    ],
  );
});
