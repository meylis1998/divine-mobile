part of 'camera_permission_bloc.dart';

/// Base event for camera permission actions.
sealed class CameraPermissionEvent extends Equatable {
  const CameraPermissionEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize permission status on app start.
class CameraPermissionInitialize extends CameraPermissionEvent {
  const CameraPermissionInitialize();
}

/// Request camera and microphone permissions from the OS.
class CameraPermissionRequest extends CameraPermissionEvent {
  const CameraPermissionRequest();
}

/// Refresh permission status (e.g., when returning from background).
class CameraPermissionRefresh extends CameraPermissionEvent {
  const CameraPermissionRefresh();
}

/// Open app settings for manual permission grant.
class CameraPermissionOpenSettings extends CameraPermissionEvent {
  const CameraPermissionOpenSettings();
}
