// ABOUTME: Result model for NIP-17 encrypted message sending operations
// ABOUTME: Indicates success/failure with message event ID and recipient info

/// Result of NIP-17 encrypted message sending
class NIP17SendResult {
  const NIP17SendResult({
    required this.success,
    this.rumorEventId,
    this.giftWrapEventId,
    this.recipientPubkey,
    this.error,
    this.timestamp,
  });

  /// Create success result
  factory NIP17SendResult.success({
    required String rumorEventId,
    required String giftWrapEventId,
    required String recipientPubkey,
  }) => NIP17SendResult(
    success: true,
    rumorEventId: rumorEventId,
    giftWrapEventId: giftWrapEventId,
    recipientPubkey: recipientPubkey,
    timestamp: DateTime.now(),
  );

  /// Create failure result
  factory NIP17SendResult.failure(String error) =>
      NIP17SendResult(success: false, error: error);

  final bool success;
  final String? rumorEventId; // Kind 14 rumor event ID (for deduplication)
  final String? giftWrapEventId; // Kind 1059 gift wrap event ID (published)
  final String? recipientPubkey;
  final String? error;
  final DateTime? timestamp;

  @override
  String toString() {
    if (success) {
      return 'NIP17SendResult(success: true, '
          'rumorEventId: $rumorEventId, '
          'giftWrapEventId: $giftWrapEventId, '
          'recipient: $recipientPubkey)';
    } else {
      return 'NIP17SendResult(success: false, error: $error)';
    }
  }
}
