import 'package:permission_handler/permission_handler.dart' as permissions;

/// PermissionHandler class manages app permissions for camera and microphone access.
/// This handler is critical for accessing device hardware on Android and iOS platforms.
///
/// Features:
/// - Request camera permission for video capture
/// - Request microphone permission for speech recording
/// - Check current permission status
/// - Handle permission denial scenarios
class PermissionHandler {
  /// Requests camera permission from the user
  /// Returns true if permission is granted, false otherwise
  ///
  /// Parameters: None
  /// Returns: bool - True if camera permission is granted
  ///
  /// Usage Example:
  /// ```dart
  /// bool cameraGranted = await PermissionHandler.requestCameraPermission();
  /// if (cameraGranted) {
  ///   // Initialize camera
  /// }
  /// ```
  static Future<bool> requestCameraPermission() async {
    final permissions.PermissionStatus status = await permissions
        .Permission
        .camera
        .request();
    return status.isGranted;
  }

  /// Requests microphone permission from the user
  /// Returns true if permission is granted, false otherwise
  ///
  /// Parameters: None
  /// Returns: bool - True if microphone permission is granted
  ///
  /// Usage Example:
  /// ```dart
  /// bool micGranted = await PermissionHandler.requestMicrophonePermission();
  /// if (micGranted) {
  ///   // Initialize speech-to-text
  /// }
  /// ```
  static Future<bool> requestMicrophonePermission() async {
    final permissions.PermissionStatus status = await permissions
        .Permission
        .microphone
        .request();
    return status.isGranted;
  }

  /// Requests both camera and microphone permissions simultaneously
  /// Returns true only if both permissions are granted
  ///
  /// Parameters: None
  /// Returns: bool - True if both camera and microphone permissions are granted
  ///
  /// This is the primary method used in the app during initialization
  static Future<bool> requestAllPermissions() async {
    final Map<permissions.Permission, permissions.PermissionStatus> statuses =
        await [
          permissions.Permission.camera,
          permissions.Permission.microphone,
        ].request();

    // Check if both permissions are granted
    bool cameraGranted =
        statuses[permissions.Permission.camera] ==
        permissions.PermissionStatus.granted;
    bool microphoneGranted =
        statuses[permissions.Permission.microphone] ==
        permissions.PermissionStatus.granted;

    return cameraGranted && microphoneGranted;
  }

  /// Checks if camera permission is already granted without requesting
  /// Returns true if permission is already granted
  ///
  /// Parameters: None
  /// Returns: bool - True if camera permission is already granted
  ///
  /// Usage in initialization phase to avoid permission dialogs on every app start
  static Future<bool> checkCameraPermission() async {
    final permissions.PermissionStatus status =
        await permissions.Permission.camera.status;
    return status.isGranted;
  }

  /// Checks if microphone permission is already granted without requesting
  /// Returns true if permission is already granted
  ///
  /// Parameters: None
  /// Returns: bool - True if microphone permission is already granted
  static Future<bool> checkMicrophonePermission() async {
    final permissions.PermissionStatus status =
        await permissions.Permission.microphone.status;
    return status.isGranted;
  }

  /// Opens the app settings page if permissions are denied
  /// User can manually grant permissions from app settings
  ///
  /// This function should be called when user taps on a "Grant Permissions" button
  static Future<void> openAppSettingsPage() async {
    await permissions.openAppSettings();
  }
}
