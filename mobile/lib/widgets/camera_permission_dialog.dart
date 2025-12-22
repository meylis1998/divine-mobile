import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Educational dialog shown before requesting camera/microphone permissions.
///
/// Returns `true` if user taps "Continue", `false` if dismissed.
class CameraMicrophonePrePermissionDialog extends StatelessWidget {
  const CameraMicrophonePrePermissionDialog({super.key});

  /// Shows the dialog and returns `true` if user taps "Continue".
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => const CameraMicrophonePrePermissionDialog(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: VineTheme.vineGreen, width: 2),
      ),
      child: Stack(
        children: [
          Padding(
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
              ],
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: IconButton(
              onPressed: () => context.pop(false),
              icon: const Icon(
                Icons.close,
                color: Colors.white70,
                semanticLabel: 'Close dialog',
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Blocking dialog shown when camera permissions are denied.
///
/// Shows "Go to Settings" button and close icon.
class CameraMicrophonePermissionRequiredDialog extends StatelessWidget {
  const CameraMicrophonePermissionRequiredDialog({
    required this.onOpenSettings,
    super.key,
  });

  /// Callback when user taps "Go to Settings".
  final VoidCallback onOpenSettings;

  /// Show the permission required dialog.
  ///
  /// [onOpenSettings] is called when user taps "Go to Settings".
  /// Returns `true` if user opened settings, `false` if dismissed.
  static Future<bool> show(
    BuildContext context, {
    required VoidCallback onOpenSettings,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return CameraMicrophonePermissionRequiredDialog(
          onOpenSettings: onOpenSettings,
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: VineTheme.vineGreen, width: 2),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Stack(
          children: [
            Padding(
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
                    style: textTheme.bodyMedium?.copyWith(
                      color: Colors.white54,
                    ),
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
                ],
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                onPressed: () => context.pop(false),
                icon: const Icon(
                  Icons.close,
                  color: Colors.white70,
                  semanticLabel: 'Close dialog',
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
