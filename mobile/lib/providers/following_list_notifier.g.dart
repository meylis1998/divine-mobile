// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'following_list_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Notifier for managing a user's following list

@ProviderFor(FollowingListNotifier)
const followingListProvider = FollowingListNotifierFamily._();

/// Notifier for managing a user's following list
final class FollowingListNotifierProvider
    extends $AsyncNotifierProvider<FollowingListNotifier, List<String>> {
  /// Notifier for managing a user's following list
  const FollowingListNotifierProvider._({
    required FollowingListNotifierFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'followingListProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$followingListNotifierHash();

  @override
  String toString() {
    return r'followingListProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  FollowingListNotifier create() => FollowingListNotifier();

  @override
  bool operator ==(Object other) {
    return other is FollowingListNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$followingListNotifierHash() =>
    r'ac74ea75ef44927ba3d39426d92c56463739fa68';

/// Notifier for managing a user's following list

final class FollowingListNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          FollowingListNotifier,
          AsyncValue<List<String>>,
          List<String>,
          FutureOr<List<String>>,
          String
        > {
  const FollowingListNotifierFamily._()
    : super(
        retry: null,
        name: r'followingListProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Notifier for managing a user's following list

  FollowingListNotifierProvider call(String pubkey) =>
      FollowingListNotifierProvider._(argument: pubkey, from: this);

  @override
  String toString() => r'followingListProvider';
}

/// Notifier for managing a user's following list

abstract class _$FollowingListNotifier extends $AsyncNotifier<List<String>> {
  late final _$args = ref.$arg as String;
  String get pubkey => _$args;

  FutureOr<List<String>> build(String pubkey);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<List<String>>, List<String>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<String>>, List<String>>,
              AsyncValue<List<String>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
