// ABOUTME: GoRouter configuration for OpenVine app
// ABOUTME: Defines all routes and their URL patterns

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/screens/explore_screen_router.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/home_screen_router.dart';
import 'package:openvine/screens/profile_screen_router.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home/0',
    routes: [
      GoRoute(
        path: '/home/:index',
        builder: (context, state) {
          return const HomeScreenRouter();
        },
      ),
      GoRoute(
        path: '/explore/:index',
        builder: (context, state) {
          return const ExploreScreenRouter();
        },
      ),
      GoRoute(
        path: '/profile/:npub/:index',
        builder: (context, state) {
          return const ProfileScreenRouter();
        },
      ),
      GoRoute(
        path: '/hashtag/:tag/:index',
        builder: (context, state) {
          return const HashtagScreenRouter();
        },
      ),
      GoRoute(
        path: '/camera',
        builder: (context, state) => const _PlaceholderScreen(title: 'Camera', index: 0),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const _PlaceholderScreen(title: 'Settings', index: 0),
      ),
    ],
  );
});

/// Placeholder widget for testing router functionality
class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title, required this.index});

  final String title;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('$title - Page $index')),
    );
  }
}
