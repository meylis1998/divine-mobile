// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_liked_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(profileLikedVideos)
const profileLikedVideosProvider = ProfileLikedVideosFamily._();

final class ProfileLikedVideosProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<VideoEvent>>,
          List<VideoEvent>,
          FutureOr<List<VideoEvent>>
        >
    with $FutureModifier<List<VideoEvent>>, $FutureProvider<List<VideoEvent>> {
  const ProfileLikedVideosProvider._({
    required ProfileLikedVideosFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'profileLikedVideosProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$profileLikedVideosHash();

  @override
  String toString() {
    return r'profileLikedVideosProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<VideoEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<VideoEvent>> create(Ref ref) {
    final argument = this.argument as String;
    return profileLikedVideos(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProfileLikedVideosProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$profileLikedVideosHash() =>
    r'9edd7906db09597d85bde2e0d419a0f5f96f6e8d';

final class ProfileLikedVideosFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<VideoEvent>>, String> {
  const ProfileLikedVideosFamily._()
    : super(
        retry: null,
        name: r'profileLikedVideosProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProfileLikedVideosProvider call(String userIdHex) =>
      ProfileLikedVideosProvider._(argument: userIdHex, from: this);

  @override
  String toString() => r'profileLikedVideosProvider';
}
