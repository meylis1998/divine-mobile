import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _MockPermissionHandlerPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PermissionHandlerPlatform {}

void main() {
  group('CameraPermissionBloc', () {
    late _MockPermissionHandlerPlatform mockPlatform;

    setUp(() {
      mockPlatform = _MockPermissionHandlerPlatform();
      PermissionHandlerPlatform.instance = mockPlatform;
    });

    group('initial state', () {
      test('is CameraPermissionInitial', () {
        final bloc = CameraPermissionBloc();
        expect(bloc.state, isA<CameraPermissionInitial>());
      });
    });

    group('CameraPermissionRequest', () {
      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Loaded(authorized)] when both permissions granted',
        setUp: () {
          // Set up initial state as canRequest
          when(
            () => mockPlatform.checkPermissionStatus(Permission.camera),
          ).thenAnswer((_) async => PermissionStatus.denied);
          when(
            () => mockPlatform.checkPermissionStatus(Permission.microphone),
          ).thenAnswer((_) async => PermissionStatus.denied);
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
        },
        build: () => CameraPermissionBloc(),
        act: (bloc) async {
          bloc.add(const CameraPermissionRefresh());
          await bloc.stream.firstWhere((s) => s is CameraPermissionLoaded);
          bloc.add(const CameraPermissionRequest());
        },
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
          const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        ],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Denied] when camera permission denied',
        setUp: () {
          // Set up initial state as canRequest
          when(
            () => mockPlatform.checkPermissionStatus(Permission.camera),
          ).thenAnswer((_) async => PermissionStatus.denied);
          when(
            () => mockPlatform.checkPermissionStatus(Permission.microphone),
          ).thenAnswer((_) async => PermissionStatus.denied);
          // Set up request - camera denied
          when(
            () => mockPlatform.requestPermissions([Permission.camera]),
          ).thenAnswer(
            (_) async => {Permission.camera: PermissionStatus.denied},
          );
        },
        build: () => CameraPermissionBloc(),
        act: (bloc) async {
          bloc.add(const CameraPermissionRefresh());
          await bloc.stream.firstWhere((s) => s is CameraPermissionLoaded);
          bloc.add(const CameraPermissionRequest());
        },
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
          const CameraPermissionDenied(),
        ],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Denied] when microphone permission denied',
        setUp: () {
          // Set up initial state as canRequest
          when(
            () => mockPlatform.checkPermissionStatus(Permission.camera),
          ).thenAnswer((_) async => PermissionStatus.denied);
          when(
            () => mockPlatform.checkPermissionStatus(Permission.microphone),
          ).thenAnswer((_) async => PermissionStatus.denied);
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
        },
        build: () => CameraPermissionBloc(),
        act: (bloc) async {
          bloc.add(const CameraPermissionRefresh());
          await bloc.stream.firstWhere((s) => s is CameraPermissionLoaded);
          bloc.add(const CameraPermissionRequest());
        },
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
          const CameraPermissionDenied(),
        ],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Error] when request throws',
        setUp: () {
          // Set up initial state as canRequest
          when(
            () => mockPlatform.checkPermissionStatus(Permission.camera),
          ).thenAnswer((_) async => PermissionStatus.denied);
          when(
            () => mockPlatform.checkPermissionStatus(Permission.microphone),
          ).thenAnswer((_) async => PermissionStatus.denied);
          // Request throws
          when(
            () => mockPlatform.requestPermissions([Permission.camera]),
          ).thenThrow(Exception('Platform error'));
        },
        build: () => CameraPermissionBloc(),
        act: (bloc) async {
          bloc.add(const CameraPermissionRefresh());
          await bloc.stream.firstWhere(
            (s) =>
                s is CameraPermissionLoaded &&
                s.status == CameraPermissionStatus.canRequest,
          );
          bloc.add(const CameraPermissionRequest());
        },
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
          const CameraPermissionError(),
        ],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'does nothing if status is not canRequest',
        setUp: () {
          // Set up initial state as authorized
          when(
            () => mockPlatform.checkPermissionStatus(Permission.camera),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockPlatform.checkPermissionStatus(Permission.microphone),
          ).thenAnswer((_) async => PermissionStatus.granted);
        },
        build: () => CameraPermissionBloc(),
        act: (bloc) async {
          bloc.add(const CameraPermissionRefresh());
          await bloc.stream.firstWhere((s) => s is CameraPermissionLoaded);
          bloc.add(const CameraPermissionRequest());
        },
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        ],
        verify: (_) {
          verifyNever(() => mockPlatform.requestPermissions(any()));
        },
      );
    });

    group('CameraPermissionRefresh', () {
      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Loaded] with updated status',
        setUp: () {
          // Track how many times camera has been checked to determine refresh count
          var cameraCallCount = 0;
          when(
            () => mockPlatform.checkPermissionStatus(Permission.camera),
          ).thenAnswer((_) async {
            cameraCallCount++;
            // First call is first refresh (denied), second call is second refresh (granted)
            return cameraCallCount == 1
                ? PermissionStatus.denied
                : PermissionStatus.granted;
          });
          var micCallCount = 0;
          when(
            () => mockPlatform.checkPermissionStatus(Permission.microphone),
          ).thenAnswer((_) async {
            micCallCount++;
            // First call is first refresh (denied), second call is second refresh (granted)
            return micCallCount == 1
                ? PermissionStatus.denied
                : PermissionStatus.granted;
          });
        },
        build: () => CameraPermissionBloc(),
        act: (bloc) async {
          bloc.add(const CameraPermissionRefresh());
          await bloc.stream.firstWhere((s) => s is CameraPermissionLoaded);
          bloc.add(const CameraPermissionRefresh());
        },
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
          const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        ],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'does not emit error state when refresh throws',
        setUp: () {
          var callCount = 0;
          // First call succeeds, second call throws
          when(
            () => mockPlatform.checkPermissionStatus(Permission.camera),
          ).thenAnswer((_) async {
            callCount++;
            if (callCount > 2) throw Exception('Platform error');
            return PermissionStatus.denied;
          });
          when(
            () => mockPlatform.checkPermissionStatus(Permission.microphone),
          ).thenAnswer((_) async => PermissionStatus.denied);
        },
        build: () => CameraPermissionBloc(),
        act: (bloc) async {
          bloc.add(const CameraPermissionRefresh());
          await bloc.stream.firstWhere((s) => s is CameraPermissionLoaded);
          bloc.add(const CameraPermissionRefresh());
          // Wait a bit for the second refresh to process
          await Future<void>.delayed(const Duration(milliseconds: 50));
        },
        expect: () => [
          // Only the first Loaded state, no error emitted
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        ],
      );
    });

    group('CameraPermissionOpenSettings', () {
      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'calls openAppSettings',
        setUp: () {
          when(
            () => mockPlatform.openAppSettings(),
          ).thenAnswer((_) async => true);
        },
        build: () => CameraPermissionBloc(),
        act: (bloc) => bloc.add(const CameraPermissionOpenSettings()),
        expect: () => <CameraPermissionState>[],
        verify: (_) {
          verify(() => mockPlatform.openAppSettings()).called(1);
        },
      );
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

          final bloc = CameraPermissionBloc();
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

          final bloc = CameraPermissionBloc();
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

          final bloc = CameraPermissionBloc();
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

        final bloc = CameraPermissionBloc();
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

        final bloc = CameraPermissionBloc();
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

          final bloc = CameraPermissionBloc();
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

          final bloc = CameraPermissionBloc();
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
