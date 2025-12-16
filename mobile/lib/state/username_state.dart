// ABOUTME: State class for username availability checking and registration
// ABOUTME: Used by UsernameController to track check/register status

/// Status of username availability check
enum UsernameCheckStatus {
  /// No username entered or cleared
  idle,

  /// Currently checking availability with backend
  checking,

  /// Username is available for registration
  available,

  /// Username already registered by another user (409)
  taken,

  /// Username is reserved - user can contact support to claim (403)
  reserved,

  /// Network or validation error
  error,
}

/// Immutable state for username availability checking and registration
class UsernameState {
  const UsernameState({
    this.username = '',
    this.status = UsernameCheckStatus.idle,
    this.errorMessage,
  });

  /// The username being checked/registered
  final String username;

  /// Current status of the username check
  final UsernameCheckStatus status;

  /// Error message if status is error, taken, or reserved
  final String? errorMessage;

  /// Whether the username is available for registration
  bool get isAvailable => status == UsernameCheckStatus.available;

  /// Whether the username is reserved (can contact support to claim)
  bool get isReserved => status == UsernameCheckStatus.reserved;

  /// Whether the username is taken by another user
  bool get isTaken => status == UsernameCheckStatus.taken;

  /// Whether we're currently checking availability
  bool get isChecking => status == UsernameCheckStatus.checking;

  /// Whether there was an error checking availability
  bool get hasError => status == UsernameCheckStatus.error;

  /// Whether the username can be registered (available and non-empty)
  bool get canRegister => isAvailable && username.isNotEmpty;

  /// Create a copy with updated fields
  UsernameState copyWith({
    String? username,
    UsernameCheckStatus? status,
    String? errorMessage,
  }) =>
      UsernameState(
        username: username ?? this.username,
        status: status ?? this.status,
        // Allow clearing errorMessage by not using ?? operator
        errorMessage: errorMessage,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UsernameState &&
          runtimeType == other.runtimeType &&
          username == other.username &&
          status == other.status &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(username, status, errorMessage);

  @override
  String toString() =>
      'UsernameState(username: $username, status: $status, errorMessage: $errorMessage)';
}
