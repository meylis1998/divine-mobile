// ABOUTME: Integration test for NostrServiceV2 event reception
// ABOUTME: Tests actual connection to relay and event subscription

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('NostrServiceV2 Integration', () {
    test('receives events from relay', () async {
      // Create real key manager
      final keyManager = NostrKeyManager();
      await keyManager.initialize();
      
      if (!keyManager.hasKeys) {
        await keyManager.generateKeys();
      }
      
      // Create service
      final service = NostrService(keyManager);
      
      try {
        // Initialize service
        await service.initialize();
        
        expect(service.isInitialized, true);
        expect(service.connectedRelays.isNotEmpty, true);
        
        // Create subscription for video events
        final filter = Filter(
          kinds: [22], // Video events
          limit: 5,
        );
        
        final eventStream = service.subscribeToEvents(filters: [filter]);
        
        // Collect events with timeout
        final events = <dynamic>[];
        final completer = Completer<void>();
        final subscription = eventStream.listen((event) {
          events.add(event);
          Log.debug('Received event: ${event.kind} - ${event.id.substring(0, 8)}...');
          // Complete when we get at least one event
          if (!completer.isCompleted && events.isNotEmpty) {
            completer.complete();
          }
        });
        
        // Wait for at least one event or timeout after 10 seconds
        await completer.future.timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            // Timeout is acceptable - we'll check if we got any events below
          },
        );
        
        // Cancel subscription
        await subscription.cancel();
        
        // Should have received at least one event
        expect(events.isNotEmpty, true,
            reason: 'Should receive at least one event from relay');
        
        if (events.isNotEmpty) {
          Log.debug('✅ Received ${events.length} events');
        }
        
      } finally {
        service.dispose();
      }
    });
  });
}
