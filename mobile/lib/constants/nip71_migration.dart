// ABOUTME: App-level extensions for NIP-71 video kinds
// ABOUTME: Adds live video support and permissive kind checking for curated lists
// ABOUTME: Re-exports base NIP-71 kinds from nostr_sdk package

import 'package:nostr_sdk/nostr_sdk.dart' as sdk;

/// NIP-71 compliant video event kinds with app-specific extensions
class NIP71VideoKinds {
  // Re-export base kinds from nostr_sdk
  static const int shortVideo = sdk.NIP71VideoKinds.shortVideo;
  static const int normalVideo = sdk.NIP71VideoKinds.normalVideo;
  static const int addressableShortVideo =
      sdk.NIP71VideoKinds.addressableShortVideo;
  static const int addressableNormalVideo =
      sdk.NIP71VideoKinds.addressableNormalVideo;
  static const int repost = sdk.NIP71VideoKinds.repost;

  // App-specific extension: live video support
  static const int liveVideo = 34237; // Live video streams

  /// Get all NIP-71 video kinds that OpenVine subscribes to for discovery
  /// Delegates to nostr_sdk implementation
  static List<int> getAllVideoKinds() {
    return sdk.NIP71VideoKinds.getAllVideoKinds();
  }

  /// Get ALL video kinds that should be accepted when reading from external sources
  /// like curated lists created by other clients. More permissive than getAllVideoKinds().
  static List<int> getAllAcceptableVideoKinds() {
    return [
      shortVideo, // 22 - legacy short video
      normalVideo, // 21 - legacy normal video
      addressableShortVideo, // 34236 - addressable short (our primary)
      addressableNormalVideo, // 34235 - addressable normal/horizontal
      liveVideo, // 34237 - live streams
    ];
  }

  /// Get primary kinds for new video events
  /// Delegates to nostr_sdk implementation
  static List<int> getPrimaryVideoKinds() {
    return sdk.NIP71VideoKinds.getPrimaryVideoKinds();
  }

  /// Check if a kind is a video event (strict - for discovery feeds)
  /// Delegates to nostr_sdk implementation
  static bool isVideoKind(int kind) {
    return sdk.NIP71VideoKinds.isVideoKind(kind);
  }

  /// Check if a kind is any acceptable video event (permissive - for curated lists)
  static bool isAcceptableVideoKind(int kind) {
    return getAllAcceptableVideoKinds().contains(kind);
  }

  /// Get the preferred addressable kind for new events
  /// Delegates to nostr_sdk implementation
  static int getPreferredAddressableKind() {
    return sdk.NIP71VideoKinds.getPreferredAddressableKind();
  }

  /// Get the preferred kind for new events (same as addressable)
  /// Delegates to nostr_sdk implementation
  static int getPreferredKind() {
    return sdk.NIP71VideoKinds.getPreferredKind();
  }
}
