// ABOUTME: Riverpod provider for shake detection service
// ABOUTME: Enables headless auth feature flag when shake is detected

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:riverpod/riverpod.dart';
import 'package:openvine/services/shake_detector_service.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';

/// Controller that broadcasts when headless auth is enabled via shake
final _headlessAuthEnabledController = StreamController<void>.broadcast();

/// Stream that emits when headless auth is newly enabled via shake.
/// UI can listen to this to show visual feedback (e.g., snackbar).
Stream<void> get headlessAuthEnabledStream =>
    _headlessAuthEnabledController.stream;

/// Provider for the shake detector service
final shakeDetectorProvider = Provider<ShakeDetectorService>((ref) {
  final service = ShakeDetectorService();

  // Listen for shakes and enable headless auth
  service.onShake.listen((_) {
    final featureFlagService = ref.read(featureFlagServiceProvider);
    final isEnabled = featureFlagService.isEnabled(FeatureFlag.headlessAuth);

    if (!isEnabled) {
      featureFlagService.setFlag(FeatureFlag.headlessAuth, true);
      debugPrint('🔓 Headless auth enabled via shake!');
      // Notify listeners that headless auth was just enabled
      _headlessAuthEnabledController.add(null);
    }
  });

  // Start listening
  service.start();

  // Cleanup on dispose
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});
