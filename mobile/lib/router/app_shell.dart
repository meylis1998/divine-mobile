// ABOUTME: AppShell widget providing bottom navigation and dynamic header
// ABOUTME: Header title changes based on route with Pacifico font, includes camera button

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'page_context_provider.dart';
import 'route_utils.dart';
import 'nav_extensions.dart';
import 'last_tab_position_provider.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  final Widget child;
  final int currentIndex;

  String _titleFor(WidgetRef ref) {
    final ctx = ref.watch(pageContextProvider).asData?.value;
    switch (ctx?.type) {
      case RouteType.home:
        return 'diVine';
      case RouteType.explore:
        return 'Explore';
      case RouteType.notifications:
        return 'Notifications';
      case RouteType.hashtag:
        final raw = ctx?.hashtag ?? '';
        return raw.isEmpty ? '#—' : '#$raw';
      case RouteType.profile:
        final npub = ctx?.npub ?? '';
        return (npub == 'me') ? 'My Profile' : 'Profile';
      default:
        return '';
    }
  }

  /// Maps tab index to RouteType
  RouteType _routeTypeForTab(int index) {
    switch (index) {
      case 0:
        return RouteType.home;
      case 1:
        return RouteType.explore;
      case 2:
        return RouteType.notifications;
      case 3:
        return RouteType.profile;
      default:
        return RouteType.home;
    }
  }

  /// Handles tab tap - navigates to last known position in that tab
  void _handleTabTap(BuildContext context, WidgetRef ref, int tabIndex) {
    final routeType = _routeTypeForTab(tabIndex);
    final lastIndex = ref.read(lastTabPositionProvider.notifier).getPosition(routeType);

    // Navigate to last position in that tab
    switch (tabIndex) {
      case 0:
        context.goHome(lastIndex);
        break;
      case 1:
        context.goExplore(lastIndex);
        break;
      case 2:
        context.goNotifications(lastIndex);
        break;
      case 3:
        // For profile, need current npub - default to 'me'
        final ctx = ref.read(pageContextProvider).asData?.value;
        final npub = ctx?.npub ?? 'me';
        context.goProfile(npub, lastIndex);
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = _titleFor(ref);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        title: Text(
          title,
          // Pacifico font, with sane fallbacks if font isn't available yet.
          style: GoogleFonts.pacifico(
            textStyle: const TextStyle(
              fontSize: 24,
              letterSpacing: 0.2,
              // AppBar handles color via theme; no explicit color needed.
            ),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Open camera',
            icon: const Icon(Icons.photo_camera_outlined),
            onPressed: () => context.pushCamera(),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        onTap: (index) => _handleTabTap(context, ref, index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home),          label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.explore),       label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: 'Notifications'),
          BottomNavigationBarItem(icon: Icon(Icons.person),        label: 'Profile'),
        ],
      ),
    );
  }
}
