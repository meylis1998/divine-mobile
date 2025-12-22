import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Educational bottom sheet shown before requesting camera/microphone
/// permissions.
///
/// Returns `true` if user taps "Continue", `false` if user taps "Not now".
class CameraMicrophonePrePermissionSheet extends StatelessWidget {
  const CameraMicrophonePrePermissionSheet({super.key});

  /// Shows the bottom sheet and returns `true` if user taps "Continue".
  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const CameraMicrophonePrePermissionSheet(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF151616),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam,
                color: VineTheme.vineGreen,
                size: 64,
                semanticLabel: 'Camera icon',
              ),
              const SizedBox(height: 16),
              Text(
                'Allow camera and microphone access',
                style: textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'This allows you to capture and edit videos right here '
                'in the app, nothing more.',
                style: textTheme.bodyLarge?.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VineTheme.vineGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => context.pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Not now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Blocking bottom sheet shown when camera permissions are denied.
///
/// Shows "Go to Settings" button and "Not now" button.
class CameraMicrophonePermissionRequiredSheet extends StatelessWidget {
  const CameraMicrophonePermissionRequiredSheet({
    required this.onOpenSettings,
    super.key,
  });

  /// Callback when user taps "Go to Settings".
  final VoidCallback onOpenSettings;

  /// Show the permission required bottom sheet.
  ///
  /// [onOpenSettings] is called when user taps "Go to Settings".
  /// Returns `true` if user opened settings, `false` if user taps "Not now".
  static Future<bool> show(
    BuildContext context, {
    required VoidCallback onOpenSettings,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return CameraMicrophonePermissionRequiredSheet(
          onOpenSettings: onOpenSettings,
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xFF151616),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off,
                color: VineTheme.vineGreen,
                size: 64,
                semanticLabel: 'Camera disabled icon',
              ),
              const SizedBox(height: 16),
              Text(
                'Allow camera & microphone access',
                style: textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'This allows you to capture and edit videos right here '
                'in the app, nothing more.',
                style: textTheme.bodyLarge?.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please enable permissions in Settings to continue.',
                style: textTheme.bodyMedium?.copyWith(color: Colors.white54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    onOpenSettings();
                    context.pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VineTheme.vineGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Go to Settings'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => context.pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Not now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
