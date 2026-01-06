// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(database)
const databaseProvider = DatabaseProvider._();

final class DatabaseProvider
    extends
        $FunctionalProvider<
          AsyncValue<AppDatabase>,
          AppDatabase,
          FutureOr<AppDatabase>
        >
    with $FutureModifier<AppDatabase>, $FutureProvider<AppDatabase> {
  const DatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'databaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$databaseHash();

  @$internal
  @override
  $FutureProviderElement<AppDatabase> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AppDatabase> create(Ref ref) {
    return database(ref);
  }
}

String _$databaseHash() => r'423947fc955d6b8d75a6615b1815f2dc34258976';

/// AppDbClient wrapping the database for NostrClient integration.
/// Enables optimistic caching of Nostr events in the local database.

@ProviderFor(appDbClient)
const appDbClientProvider = AppDbClientProvider._();

/// AppDbClient wrapping the database for NostrClient integration.
/// Enables optimistic caching of Nostr events in the local database.

final class AppDbClientProvider
    extends
        $FunctionalProvider<
          AsyncValue<AppDbClient>,
          AppDbClient,
          FutureOr<AppDbClient>
        >
    with $FutureModifier<AppDbClient>, $FutureProvider<AppDbClient> {
  /// AppDbClient wrapping the database for NostrClient integration.
  /// Enables optimistic caching of Nostr events in the local database.
  const AppDbClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDbClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDbClientHash();

  @$internal
  @override
  $FutureProviderElement<AppDbClient> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<AppDbClient> create(Ref ref) {
    return appDbClient(ref);
  }
}

String _$appDbClientHash() => r'e70cbbff72ff84631c6681c3fb3c29423192bc64';
