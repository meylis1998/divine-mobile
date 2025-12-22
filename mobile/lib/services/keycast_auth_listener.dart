import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service to listen for Keycast OAuth redirects and finalize authentication.
class KeycastAuthListener {
  KeycastAuthListener(this.ref);
  final Ref ref;

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;

  /// Initialize listeners for both cold starts and background resumes
  void initialize() {
    Log.info('🔑 Initializing Keycast auth listener...', name: 'KeycastAuth');

    // Handle link that launches the app from a closed state
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleUri(uri);
    });

    // Handle links while app is running in background
    _subscription = _appLinks.uriLinkStream.listen(_handleUri);
  }

  Future<void> _handleUri(Uri uri) async {
    Log.info(
      '🔑 callback from host ${uri.host} path: ${uri.path}',
      name: 'KeycastAuth',
    );

    if (uri.host != 'login.divine.video' ||
        !uri.path.startsWith('/app/callback')) {
      return;
    }

    Log.info('🔑 Keycast callback detected: $uri', name: 'KeycastAuth');

    try {
      final oauth = ref.read(oauthClientProvider);
      final result = oauth.parseCallback(uri.toString());

      if (result case CallbackSuccess(code: var resultCode)) {
        // Retrieve the verifier we saved when the button was pressed
        final verifier = ref.read(pendingVerifierProvider);
        if (verifier == null) {
          Log.error(
            '❌ OAuth Error: No pending verifier found. Handshake failed.',
            name: 'KeycastAuth',
          );
          return;
        }

        // Finalize the OAuth Handshake
        final tokenResponse = await oauth.exchangeCode(
          code: resultCode,
          verifier: verifier,
        );

        final session = KeycastSession.fromTokenResponse(tokenResponse);
        await session.save();

        Log.info(
          '✅ Keycast session obtained, finalizing in AuthService',
          name: 'KeycastAuth',
        );

        // Finalize login in AuthService
        await ref.read(authServiceProvider).signInWithKeycast(session);

        // Success: Clear the verifier state
        ref.read(pendingVerifierProvider.notifier).set(null);

        Log.info('✅ Keycast authentication complete', name: 'KeycastAuth');
      } else {
        Log.error('❌ Unexpected result $result', name: 'KeycastAuth');
      }
    } catch (e) {
      Log.error('❌ Keycast finalization failed: $e', name: 'KeycastAuth');
    }
  }

  void dispose() {
    _subscription?.cancel();
    Log.info('🔑 Keycast auth listener disposed', name: 'KeycastAuth');
  }
}
