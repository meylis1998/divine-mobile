import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:url_launcher/url_launcher.dart';

class KeycastLoginButton extends ConsumerWidget {
  const KeycastLoginButton({super.key, required this.enabled});

  final bool enabled;

  Future<void> _handleKeycastLogin(BuildContext context, WidgetRef ref) async {
    try {
      final oauth = ref.read(oauthClientProvider);

      final (url, verifier) = await oauth.getAuthorizationUrl(
        scope: 'policy:social',
        defaultRegister: true,
      );

      if (Platform.isAndroid) {
        // Android: url_launcher + app_links
        // Store verifier for token exchange when the app resumes via deep link
        ref.read(pendingVerifierProvider.notifier).set(verifier);

        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch browser';
        }
      } else {
        // iOS: ASWebAuthenticationSession via flutter_web_auth_2
        final result = await FlutterWebAuth2.authenticate(
          url: url,
          callbackUrlScheme: 'https',
          options: const FlutterWebAuth2Options(
            httpsHost: 'divine.video',
            httpsPath: '/app/callback',
          ),
        );

        final callbackResult = oauth.parseCallback(result);
        if (callbackResult is CallbackSuccess) {
          final tokenResponse = await oauth.exchangeCode(
            code: callbackResult.code,
            verifier: verifier,
          );
          final session = KeycastSession.fromTokenResponse(tokenResponse);
          await session.save();
          await ref.read(authServiceProvider).signInWithKeycast(session);
        } else if (callbackResult is CallbackError) {
          throw 'OAuth error: ${callbackResult.error}';
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Keycast Error: $e'),
            backgroundColor: Colors.black.withValues(alpha: 0.8),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: const Icon(Icons.cloud_outlined),
        label: const Text(
          'Login with Keycast Account',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        onPressed: enabled ? () => _handleKeycastLogin(context, ref) : null,
        style:
            OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ).copyWith(
              side: WidgetStateProperty.resolveWith<BorderSide>((states) {
                if (states.contains(WidgetState.disabled)) {
                  return BorderSide(
                    color: Colors.white.withValues(alpha: 0.5),
                    width: 2,
                  );
                }
                return const BorderSide(color: Colors.white, width: 2);
              }),
            ),
      ),
    );
  }
}
