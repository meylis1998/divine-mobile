import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockPermissionHandlerPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PermissionHandlerPlatform {}

void main() {
  late CameraPermissionBloc bloc;
  late MockPermissionHandlerPlatform mockPlatform;

  setUp(() {
    mockPlatform = MockPermissionHandlerPlatform();
    PermissionHandlerPlatform.instance = mockPlatform;
    bloc = CameraPermissionBloc();
  });

  tearDown(() {
    bloc.close();
  });

  group('CameraPermissionBloc', () {
    group('initial state', () {
      test('is CameraPermissionInitial', () {
        expect(bloc.state, isA<CameraPermissionInitial>());
      });
    });

    group('CameraPermissionRequest', () {
      test(
        'emits [Loaded(authorized)] when both permissions granted',
        () async {
          // Set up initial state as canRequest
          when(
            () => mockPlatform.checkPermissionStatus(Permission.camera),
          ).thenAnswer((_) async => PermissionStatus.denied);
          when(
            () => mockPlatform.checkPermissionStatus(Permission.microphone),
          ).thenAnswer((_) async => PermissionStatus.denied);

          bloc.add(const CameraPermissionRefresh());
          await bloc.stream.firstWhere((s) => s is CameraPermissionLoaded);

          // Set up request responses
          when(
            () => mockPlatform.requestPermissions([Permission.camera]),
          ).thenAnswer(
            (_) async => {Permission.camera: PermissionStatus.granted},
          );
          when(
            () => mockPlatform.requestPermissions([Permission.microphone]),
          ).thenAnswer(
            (_) async => {Permission.microphone: PermissionStatus.granted},
          );

          bloc.add(const CameraPermissionRequest());

          await expectLater(
            bloc.stream,
            emits(
              isA<CameraPermissionLoaded>().having(
                (s) => s.status,
                'status',
                CameraPermissionStatus.authorized,
              ),
            ),
          );
        },
      );

      test('emits [Denied] when camera permission denied', () async {
        // Set up initial state as canRequest
        when(
          () => mockPlatform.checkPermissionStatus(Permission.camera),
        ).thenAnswer((_) async => PermissionStatus.denied);
        when(
          () => mockPlatform.checkPermissionStatus(Permission.microphone),
        ).thenAnswer((_) async => PermissionStatus.denied);

        bloc.add(const CameraPermissionRefresh());
        await bloc.stream.firstWhere((s) => s is CameraPermissionLoaded);

        // Set up request - camera denied
        when(
          () => mockPlatform.requestPermissions([Permission.camera]),
        ).thenAnswer((_) async => {Permission.camera: PermissionStatus.denied});

        bloc.add(const CameraPermissionRequest());

        await expectLater(bloc.stream, emits(isA<CameraPermissionDenied>()));
      });

      test('emits [Denied] when microphone permission denied', () async {
        // Set up initial state as canRequest
        when(
          () => mockPlatform.checkPermissionStatus(Permission.camera),
        ).thenAnswer((_) async => PermissionStatus.denied);
        when(
          () => mockPlatform.checkPermissionStatus(Permission.microphone),
        ).thenAnswer((_) async => PermissionStatus.denied);

        bloc.add(const CameraPermissionRefresh());
        await bloc.stream.firstWhere((s) => s is CameraPermissionLoaded);

        // Camera granted but microphone denied
        when(
          () => mockPlatform.requestPermissions([Permission.camera]),
        ).thenAnswer(
          (_) async => {Permission.camera: PermissionStatus.granted},
        );
        when(
          () => mockPlatform.requestPermissions([Permission.microphone]),
        ).thenAnswer(
          (_) async => {Permission.microphone: PermissionStatus.denied},
        );

        bloc.add(const CameraPermissionRequest());

        await expectLater(bloc.stream, emits(isA<CameraPermissionDenied>()));
      });

      test('emits [Error] when request throws', () async {
        // Set up initial state as canRequest
        when(
          () => mockPlatform.checkPermissionStatus(Permission.camera),
        ).thenAnswer((_) async => PermissionStatus.denied);
        when(
          () => mockPlatform.checkPermissionStatus(Permission.microphone),
        ).thenAnswer((_) async => PermissionStatus.denied);

        bloc.add(const CameraPermissionRefresh());
        await bloc.stream.firstWhere((s) => s is CameraPermissionLoaded);

        // Request throws
        when(
          () => mockPlatform.requestPermissions([Permission.camera]),
        ).thenThrow(Exception('Platform error'));

        bloc.add(const CameraPermissionRequest());

        await expectLater(bloc.stream, emits(isA<CameraPermissionError>()));
      });

      test('does nothing if status is not canRequest', () async {
        // Set up initial state as authorized
        when(
          () => mockPlatform.checkPermissionStatus(Permission.camera),
        ).thenAnswer((_) async => PermissionStatus.granted);
        when(
          () => mockPlatform.checkPermissionStatus(Permission.microphone),
        ).thenAnswer((_) async => PermissionStatus.granted);

        bloc.add(const CameraPermissionRefresh());
        await bloc.stream.firstWhere((s) => s is CameraPermissionLoaded);

        final stateBeforeRequest = bloc.state;

        bloc.add(const CameraPermissionRequest());

        // Allow some time for potential state change
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // State should remain unchanged
        expect(bloc.state, equals(stateBeforeRequest));
        verifyNever(() => mockPlatform.requestPermissions(any()));
      });
    });

    group('CameraPermissionRefresh', () {
      test('emits [Loaded] with updated status', () async {
        // Initial state
        when(
          () => mockPlatform.checkPermissionStatus(Permission.camera),
        ).thenAnswer((_) async => PermissionStatus.denied);
        when(
          () => mockPlatform.checkPermissionStatus(Permission.microphone),
        ).thenAnswer((_) async => PermissionStatus.denied);

        bloc.add(const CameraPermissionRefresh());
        await bloc.stream.firstWhere((s) => s is CameraPermissionLoaded);

        // Now permissions are granted (user enabled in settings)
        when(
          () => mockPlatform.checkPermissionStatus(Permission.camera),
        ).thenAnswer((_) async => PermissionStatus.granted);
        when(
          () => mockPlatform.checkPermissionStatus(Permission.microphone),
        ).thenAnswer((_) async => PermissionStatus.granted);

        bloc.add(const CameraPermissionRefresh());

        await expectLater(
          bloc.stream,
          emits(
            isA<CameraPermissionLoaded>().having(
              (s) => s.status,
              'status',
              CameraPermissionStatus.authorized,
            ),
          ),
        );
      });

      test('does not emit error state when refresh throws', () async {
        // Initial state
        when(
          () => mockPlatform.checkPermissionStatus(Permission.camera),
        ).thenAnswer((_) async => PermissionStatus.denied);
        when(
          () => mockPlatform.checkPermissionStatus(Permission.microphone),
        ).thenAnswer((_) async => PermissionStatus.denied);

        bloc.add(const CameraPermissionRefresh());
        await bloc.stream.firstWhere((s) => s is CameraPermissionLoaded);

        final stateBeforeRefresh = bloc.state;

        // Refresh throws
        when(
          () => mockPlatform.checkPermissionStatus(Permission.camera),
        ).thenThrow(Exception('Platform error'));

        bloc.add(const CameraPermissionRefresh());

        // Allow some time for potential state change
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // State should remain unchanged (error is silently caught)
        expect(bloc.state, equals(stateBeforeRefresh));
      });
    });

    group('CameraPermissionOpenSettings', () {
      test('calls openAppSettings', () async {
        when(
          () => mockPlatform.openAppSettings(),
        ).thenAnswer((_) async => true);

        bloc.add(const CameraPermissionOpenSettings());

        // Allow event to be processed
        await Future<void>.delayed(const Duration(milliseconds: 50));

        verify(() => mockPlatform.openAppSettings()).called(1);
      });
    });

    group('checkPermissions', () {
      test(
        'returns authorized when both camera and microphone are granted',
        () async {
          when(
            () => mockPlatform.checkPermissionStatus(Permission.camera),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockPlatform.checkPermissionStatus(Permission.microphone),
          ).thenAnswer((_) async => PermissionStatus.granted);

          final result = await bloc.checkPermissions();

          expect(result, CameraPermissionStatus.authorized);
        },
      );

      test(
        'returns requiresSettings when camera is permanently denied',
        () async {
          when(
            () => mockPlatform.checkPermissionStatus(Permission.camera),
          ).thenAnswer((_) async => PermissionStatus.permanentlyDenied);
          when(
            () => mockPlatform.checkPermissionStatus(Permission.microphone),
          ).thenAnswer((_) async => PermissionStatus.granted);

          final result = await bloc.checkPermissions();

          expect(result, CameraPermissionStatus.requiresSettings);
        },
      );

      test(
        'returns requiresSettings when microphone is permanently denied',
        () async {
          when(
            () => mockPlatform.checkPermissionStatus(Permission.camera),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockPlatform.checkPermissionStatus(Permission.microphone),
          ).thenAnswer((_) async => PermissionStatus.permanentlyDenied);

          final result = await bloc.checkPermissions();

          expect(result, CameraPermissionStatus.requiresSettings);
        },
      );

      test('returns requiresSettings when camera is restricted', () async {
        when(
          () => mockPlatform.checkPermissionStatus(Permission.camera),
        ).thenAnswer((_) async => PermissionStatus.restricted);
        when(
          () => mockPlatform.checkPermissionStatus(Permission.microphone),
        ).thenAnswer((_) async => PermissionStatus.granted);

        final result = await bloc.checkPermissions();

        expect(result, CameraPermissionStatus.requiresSettings);
      });

      test('returns requiresSettings when microphone is restricted', () async {
        when(
          () => mockPlatform.checkPermissionStatus(Permission.camera),
        ).thenAnswer((_) async => PermissionStatus.granted);
        when(
          () => mockPlatform.checkPermissionStatus(Permission.microphone),
        ).thenAnswer((_) async => PermissionStatus.restricted);

        final result = await bloc.checkPermissions();

        expect(result, CameraPermissionStatus.requiresSettings);
      });

      test(
        'returns canRequest when permissions are denied but not permanently',
        () async {
          when(
            () => mockPlatform.checkPermissionStatus(Permission.camera),
          ).thenAnswer((_) async => PermissionStatus.denied);
          when(
            () => mockPlatform.checkPermissionStatus(Permission.microphone),
          ).thenAnswer((_) async => PermissionStatus.denied);

          final result = await bloc.checkPermissions();

          expect(result, CameraPermissionStatus.canRequest);
        },
      );

      test(
        'returns canRequest when one permission granted and other denied',
        () async {
          when(
            () => mockPlatform.checkPermissionStatus(Permission.camera),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockPlatform.checkPermissionStatus(Permission.microphone),
          ).thenAnswer((_) async => PermissionStatus.denied);

          final result = await bloc.checkPermissions();

          expect(result, CameraPermissionStatus.canRequest);
        },
      );
    });
  });

  group('CameraPermissionState equality', () {
    test('CameraPermissionInitial instances are equal', () {
      expect(
        const CameraPermissionInitial(),
        equals(const CameraPermissionInitial()),
      );
    });

    test('CameraPermissionLoading instances are equal', () {
      expect(
        const CameraPermissionLoading(),
        equals(const CameraPermissionLoading()),
      );
    });

    test('CameraPermissionLoaded instances with same status are equal', () {
      expect(
        const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        equals(const CameraPermissionLoaded(CameraPermissionStatus.authorized)),
      );
    });

    test(
      'CameraPermissionLoaded instances with different status are not equal',
      () {
        expect(
          const CameraPermissionLoaded(CameraPermissionStatus.authorized),
          isNot(
            equals(
              const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
            ),
          ),
        );
      },
    );

    test('CameraPermissionDenied instances are equal', () {
      expect(
        const CameraPermissionDenied(),
        equals(const CameraPermissionDenied()),
      );
    });

    test('CameraPermissionError instances are equal', () {
      expect(
        const CameraPermissionError(),
        equals(const CameraPermissionError()),
      );
    });
  });

  group('CameraPermissionEvent equality', () {
    test('CameraPermissionRequest instances are equal', () {
      expect(
        const CameraPermissionRequest(),
        equals(const CameraPermissionRequest()),
      );
    });

    test('CameraPermissionRefresh instances are equal', () {
      expect(
        const CameraPermissionRefresh(),
        equals(const CameraPermissionRefresh()),
      );
    });

    test('CameraPermissionOpenSettings instances are equal', () {
      expect(
        const CameraPermissionOpenSettings(),
        equals(const CameraPermissionOpenSettings()),
      );
    });
  });
}
