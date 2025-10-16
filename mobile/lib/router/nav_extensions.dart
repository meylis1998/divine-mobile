// ABOUTME: Navigation extension helpers for clean GoRouter call-sites
// ABOUTME: Provides goHome/goExplore/goNotifications/goProfile/pushCamera/pushSettings (hashtag available via goHashtag)

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'route_utils.dart';

extension NavX on BuildContext {
  // Tab bases
  void goHome([int index = 0]) => go(buildRoute(
        RouteContext(type: RouteType.home, videoIndex: index),
      ));

  void goExplore([int index = 0]) => go(buildRoute(
        RouteContext(type: RouteType.explore, videoIndex: index),
      ));

  void goNotifications([int index = 0]) => go(buildRoute(
        RouteContext(type: RouteType.notifications, videoIndex: index),
      ));

  void goHashtag(String tag, [int index = 0]) => go(buildRoute(
        RouteContext(
          type: RouteType.hashtag,
          hashtag: tag,
          videoIndex: index,
        ),
      ));

  void goProfile(String npub, [int index = 0]) => go(buildRoute(
        RouteContext(
          type: RouteType.profile,
          npub: npub,
          videoIndex: index,
        ),
      ));

  // Optional pushes (non-tab routes)
  Future<void> pushCamera() => push('/camera');
  Future<void> pushSettings() => push('/settings');
}
