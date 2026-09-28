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
import 'core/widgets/motion.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/news',
    routes: [
      StatefulShellRoute(
        builder: (context, state, shell) => shell,
        navigatorContainerBuilder: (context, shell, children) => AppShell(shell: shell, children: children),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/news', builder: (_, _) => const NewsFeedScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/menu', builder: (_, _) => const MenuScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/card', builder: (_, _) => const LoyaltyScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/contacts', builder: (_, _) => const ContactsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen())],
          ),
        ],
      ),
      GoRoute(
        path: '/news/:id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, state) => _page(state, NewsDetailScreen(id: state.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, state) => _page(state, const PhoneScreen(), modal: true),
      ),
      GoRoute(
        path: '/login/code',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (_, state) => state.extra is CodeScreenArgs ? null : '/login',
        pageBuilder: (_, state) => _page(state, CodeScreen(args: state.extra! as CodeScreenArgs)),
      ),
      GoRoute(
        path: '/feedback/new',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, state) => _page(
          state,
          FeedbackFormScreen(initialType: FeedbackType.fromCode(state.uri.queryParameters['type'] ?? 'complaint')),
        ),
      ),
      GoRoute(
        path: '/feedback/mine',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, state) => _page(state, const MyFeedbackScreen()),
      ),
      GoRoute(
        path: '/privacy',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, state) => _page(state, const PrivacyScreen()),
      ),
    ],
  );
});

/// Единый переход между экранами: новый экран проявляется со сдвигом
/// (справа — для обычных, снизу — для модальных вроде входа), предыдущий
/// слегка отступает и тускнеет.
Page<void> _page(GoRouterState state, Widget child, {bool modal = false}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    fullscreenDialog: modal,
    transitionDuration: Motion.slow,
    reverseTransitionDuration: Motion.medium,
    child: child,
    transitionsBuilder: (context, animation, secondary, child) {
      if (Motion.reduced(context)) return child;
      final inCurve = CurvedAnimation(parent: animation, curve: Motion.emphasized, reverseCurve: Curves.easeInCubic);
      final outCurve = CurvedAnimation(parent: secondary, curve: Motion.curve);
      final begin = modal ? const Offset(0, 0.08) : const Offset(0.08, 0);
      return FadeTransition(
        opacity: Tween(begin: 1.0, end: 0.6).animate(outCurve),
        child: SlideTransition(
          position: Tween(begin: Offset.zero, end: const Offset(-0.04, 0)).animate(outCurve),
          child: FadeTransition(
            opacity: inCurve,
            child: SlideTransition(
              position: Tween(begin: begin, end: Offset.zero).animate(inCurve),
              child: child,
            ),
          ),
        ),
      );
    },
  );
}
