// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'username_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Controller for managing username availability checking and registration
///
/// Provides debounced availability checking to avoid excessive API calls
/// and handles the full registration flow including reserved name detection.

@ProviderFor(UsernameController)
const usernameControllerProvider = UsernameControllerProvider._();

/// Controller for managing username availability checking and registration
///
/// Provides debounced availability checking to avoid excessive API calls
/// and handles the full registration flow including reserved name detection.
final class UsernameControllerProvider
    extends $NotifierProvider<UsernameController, UsernameState> {
  /// Controller for managing username availability checking and registration
  ///
  /// Provides debounced availability checking to avoid excessive API calls
  /// and handles the full registration flow including reserved name detection.
  const UsernameControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'usernameControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$usernameControllerHash();

  @$internal
  @override
  UsernameController create() => UsernameController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UsernameState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UsernameState>(value),
    );
  }
}

String _$usernameControllerHash() =>
    r'0b7872db99408da64a69e41dcbd8bfedb25e6181';

/// Controller for managing username availability checking and registration
///
/// Provides debounced availability checking to avoid excessive API calls
/// and handles the full registration flow including reserved name detection.

abstract class _$UsernameController extends $Notifier<UsernameState> {
  UsernameState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<UsernameState, UsernameState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UsernameState, UsernameState>,
              UsernameState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
