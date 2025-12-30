import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:permissions_service/permissions_service.dart';

class MockPermissionsService extends Mock implements PermissionsService {}

void main() {
  group('CameraPermissionBloc', () {
    late MockPermissionsService mockService;

    setUp(() {
      mockService = MockPermissionsService();
    });

    group('initial state', () {
      test('is CameraPermissionInitial', () {
        final bloc = CameraPermissionBloc(permissionsService: mockService);
        expect(bloc.state, isA<CameraPermissionInitial>());
      });
    });

    group('CameraPermissionRequest', () {
      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'does nothing when state is CameraPermissionInitial',
        build: () => CameraPermissionBloc(permissionsService: mockService),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        expect: () => <CameraPermissionState>[],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'does nothing when state is CameraPermissionLoading',
        build: () => CameraPermissionBloc(permissionsService: mockService),
        seed: () => const CameraPermissionLoading(),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        expect: () => <CameraPermissionState>[],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'does nothing when status is authorized',
        build: () => CameraPermissionBloc(permissionsService: mockService),
        seed: () =>
            const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        expect: () => <CameraPermissionState>[],
        verify: (_) {
          verifyNever(() => mockService.requestCameraPermission());
          verifyNever(() => mockService.requestMicrophonePermission());
        },
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'does nothing when status is requiresSettings',
        build: () => CameraPermissionBloc(permissionsService: mockService),
        seed: () => const CameraPermissionLoaded(
          CameraPermissionStatus.requiresSettings,
        ),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        expect: () => <CameraPermissionState>[],
        verify: (_) {
          verifyNever(() => mockService.requestCameraPermission());
          verifyNever(() => mockService.requestMicrophonePermission());
        },
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Loaded(authorized)] when both permissions granted',
        setUp: () {
          when(
            () => mockService.requestCameraPermission(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockService.requestMicrophonePermission(),
          ).thenAnswer((_) async => PermissionStatus.granted);
        },
        build: () => CameraPermissionBloc(permissionsService: mockService),
        seed: () =>
            const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        ],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Denied] when camera permission denied',
        setUp: () {
          when(
            () => mockService.requestCameraPermission(),
          ).thenAnswer((_) async => PermissionStatus.canRequest);
        },
        build: () => CameraPermissionBloc(permissionsService: mockService),
        seed: () =>
            const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        expect: () => [const CameraPermissionDenied()],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Denied] when microphone permission denied',
        setUp: () {
          when(
            () => mockService.requestCameraPermission(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockService.requestMicrophonePermission(),
          ).thenAnswer((_) async => PermissionStatus.canRequest);
        },
        build: () => CameraPermissionBloc(permissionsService: mockService),
        seed: () =>
            const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        expect: () => [const CameraPermissionDenied()],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Denied] when camera permission permanently denied',
        setUp: () {
          when(
            () => mockService.requestCameraPermission(),
          ).thenAnswer((_) async => PermissionStatus.requiresSettings);
        },
        build: () => CameraPermissionBloc(permissionsService: mockService),
        seed: () =>
            const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        expect: () => [const CameraPermissionDenied()],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Denied] when microphone permission permanently denied',
        setUp: () {
          when(
            () => mockService.requestCameraPermission(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockService.requestMicrophonePermission(),
          ).thenAnswer((_) async => PermissionStatus.requiresSettings);
        },
        build: () => CameraPermissionBloc(permissionsService: mockService),
        seed: () =>
            const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        expect: () => [const CameraPermissionDenied()],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Error] when camera request throws',
        setUp: () {
          when(
            () => mockService.requestCameraPermission(),
          ).thenThrow(Exception('Platform error'));
        },
        build: () => CameraPermissionBloc(permissionsService: mockService),
        seed: () =>
            const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        expect: () => [const CameraPermissionError()],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Error] when microphone request throws',
        setUp: () {
          when(
            () => mockService.requestCameraPermission(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockService.requestMicrophonePermission(),
          ).thenThrow(Exception('Platform error'));
        },
        build: () => CameraPermissionBloc(permissionsService: mockService),
        seed: () =>
            const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        act: (bloc) => bloc.add(const CameraPermissionRequest()),
        expect: () => [const CameraPermissionError()],
      );
    });

    group('CameraPermissionRefresh', () {
      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Loaded(canRequest)] when permissions can be requested',
        setUp: () {
          when(
            () => mockService.checkCameraStatus(),
          ).thenAnswer((_) async => PermissionStatus.canRequest);
          when(
            () => mockService.checkMicrophoneStatus(),
          ).thenAnswer((_) async => PermissionStatus.canRequest);
        },
        build: () => CameraPermissionBloc(permissionsService: mockService),
        act: (bloc) => bloc.add(const CameraPermissionRefresh()),
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        ],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Loaded(authorized)] when both permissions granted',
        setUp: () {
          when(
            () => mockService.checkCameraStatus(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockService.checkMicrophoneStatus(),
          ).thenAnswer((_) async => PermissionStatus.granted);
        },
        build: () => CameraPermissionBloc(permissionsService: mockService),
        act: (bloc) => bloc.add(const CameraPermissionRefresh()),
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        ],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Loaded(requiresSettings)] when permission permanently denied',
        setUp: () {
          when(
            () => mockService.checkCameraStatus(),
          ).thenAnswer((_) async => PermissionStatus.requiresSettings);
          when(
            () => mockService.checkMicrophoneStatus(),
          ).thenAnswer((_) async => PermissionStatus.granted);
        },
        build: () => CameraPermissionBloc(permissionsService: mockService),
        act: (bloc) => bloc.add(const CameraPermissionRefresh()),
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.requiresSettings),
        ],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'emits [Error] when checkPermissions throws',
        setUp: () {
          when(
            () => mockService.checkCameraStatus(),
          ).thenThrow(Exception('Platform error'));
          when(
            () => mockService.checkMicrophoneStatus(),
          ).thenAnswer((_) async => PermissionStatus.granted);
        },
        build: () => CameraPermissionBloc(permissionsService: mockService),
        act: (bloc) => bloc.add(const CameraPermissionRefresh()),
        expect: () => [const CameraPermissionError()],
      );
    });

    group('CameraPermissionOpenSettings', () {
      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'calls openAppSettings',
        setUp: () {
          when(
            () => mockService.openAppSettings(),
          ).thenAnswer((_) async => true);
        },
        build: () => CameraPermissionBloc(permissionsService: mockService),
        act: (bloc) => bloc.add(const CameraPermissionOpenSettings()),
        expect: () => <CameraPermissionState>[],
        verify: (_) {
          verify(() => mockService.openAppSettings()).called(1);
        },
      );
    });

    group('permission status mapping', () {
      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'maps granted + granted to authorized',
        setUp: () {
          when(
            () => mockService.checkCameraStatus(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockService.checkMicrophoneStatus(),
          ).thenAnswer((_) async => PermissionStatus.granted);
        },
        build: () => CameraPermissionBloc(permissionsService: mockService),
        act: (bloc) => bloc.add(const CameraPermissionRefresh()),
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.authorized),
        ],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'maps requiresSettings camera to requiresSettings',
        setUp: () {
          when(
            () => mockService.checkCameraStatus(),
          ).thenAnswer((_) async => PermissionStatus.requiresSettings);
          when(
            () => mockService.checkMicrophoneStatus(),
          ).thenAnswer((_) async => PermissionStatus.granted);
        },
        build: () => CameraPermissionBloc(permissionsService: mockService),
        act: (bloc) => bloc.add(const CameraPermissionRefresh()),
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.requiresSettings),
        ],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'maps requiresSettings microphone to requiresSettings',
        setUp: () {
          when(
            () => mockService.checkCameraStatus(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockService.checkMicrophoneStatus(),
          ).thenAnswer((_) async => PermissionStatus.requiresSettings);
        },
        build: () => CameraPermissionBloc(permissionsService: mockService),
        act: (bloc) => bloc.add(const CameraPermissionRefresh()),
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.requiresSettings),
        ],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'maps canRequest + canRequest to canRequest',
        setUp: () {
          when(
            () => mockService.checkCameraStatus(),
          ).thenAnswer((_) async => PermissionStatus.canRequest);
          when(
            () => mockService.checkMicrophoneStatus(),
          ).thenAnswer((_) async => PermissionStatus.canRequest);
        },
        build: () => CameraPermissionBloc(permissionsService: mockService),
        act: (bloc) => bloc.add(const CameraPermissionRefresh()),
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        ],
      );

      blocTest<CameraPermissionBloc, CameraPermissionState>(
        'maps granted + canRequest to canRequest',
        setUp: () {
          when(
            () => mockService.checkCameraStatus(),
          ).thenAnswer((_) async => PermissionStatus.granted);
          when(
            () => mockService.checkMicrophoneStatus(),
          ).thenAnswer((_) async => PermissionStatus.canRequest);
        },
        build: () => CameraPermissionBloc(permissionsService: mockService),
        act: (bloc) => bloc.add(const CameraPermissionRefresh()),
        expect: () => [
          const CameraPermissionLoaded(CameraPermissionStatus.canRequest),
        ],
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
