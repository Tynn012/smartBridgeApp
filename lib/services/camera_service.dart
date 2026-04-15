import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

/// CameraService manages all camera-related operations for the sign language translator app.
///
/// This service handles:
/// - Camera initialization and lifecycle management
/// - Video feed streaming
/// - Frame capture for model inference
/// - Error handling and recovery
///
/// The service is designed to work with the hand-landmarker pipeline for real-time gesture recognition.
class CameraService {
  static final CameraService _instance = CameraService._internal();

  // Singleton pattern ensures only one camera instance at a time
  factory CameraService() {
    return _instance;
  }

  CameraService._internal();

  // Camera controller manages the camera hardware
  CameraController? _cameraController;

  // List of available cameras on the device (front and rear)
  List<CameraDescription> _cameras = [];

  // Callback function that receives each camera frame for processing
  Function(CameraImage)? _frameProcessor;

  /// Indicates if the camera is currently initialized and ready
  bool get isInitialized => _cameraController?.value.isInitialized ?? false;

  /// Gets the current camera controller instance
  CameraController? get cameraController => _cameraController;

  /// Gets the list of available cameras on the device
  List<CameraDescription> get cameras => _cameras;

  /// Initializes the camera service and gets available cameras
  /// This must be called before any other camera operations
  ///
  /// Throws Exception if no cameras are available on device
  ///
  /// Usage Example:
  /// ```dart
  /// await cameraService.initializeCamera();
  /// ```
  Future<void> initializeCamera() async {
    try {
      // Get list of available cameras (usually front and rear)
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        throw Exception('No cameras available on this device');
      }

      if (kDebugMode) {
        print('Available cameras: ${_cameras.length}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing camera: $e');
      }
      rethrow;
    }
  }

  /// Starts camera stream with the specified camera (front or rear)
  /// Sets up continuous frame streaming for real-time processing
  ///
  /// Parameters:
  /// - cameraIndex: Index of camera to use (0 for rear, 1 for front typically)
  /// - frameProcessor: Callback function that processes each frame
  ///
  /// Usage Example:
  /// ```dart
  /// await cameraService.startCameraStream(
  ///   cameraIndex: 0,
  ///   frameProcessor: (frame) {
  ///     // Process frame with model
  ///   }
  /// );
  /// ```
  Future<void> startCameraStream({
    required int cameraIndex,
    required Function(CameraImage) frameProcessor,
  }) async {
    try {
      // Validate camera index
      if (cameraIndex < 0 || cameraIndex >= _cameras.length) {
        throw Exception(
          'Invalid camera index: $cameraIndex. Available cameras: ${_cameras.length}',
        );
      }

      // Store the frame processor function
      _frameProcessor = frameProcessor;

      final ImageFormatGroup formatGroup =
          defaultTargetPlatform == TargetPlatform.iOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420;

      // Create camera controller with the selected camera
      _cameraController = CameraController(
        _cameras[cameraIndex],
        // ResolutionPreset affects performance vs quality trade-off
        ResolutionPreset
            .low, // Lower resolution helps reduce noisy pixel variance
        enableAudio: false, // audio not needed for video analysis
        imageFormatGroup: formatGroup,
      );

      // Wait for camera to initialize
      await _cameraController!.initialize();

      // Start streaming frames and processing them
      await _cameraController!.startImageStream((CameraImage image) {
        // Call the frame processor for each frame
        // This runs in a separate isolate to avoid UI blocking
        _frameProcessor?.call(image);
      });

      if (kDebugMode) {
        print('Camera stream started successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error starting camera stream: $e');
      }
      rethrow;
    }
  }

  /// Stops the camera stream and releases resources
  /// Should be called when exiting the camera screen
  ///
  /// Usage Example:
  /// ```dart
  /// await cameraService.stopCameraStream();
  /// ```
  Future<void> stopCameraStream() async {
    try {
      if (_cameraController != null) {
        // Stop the image stream
        await _cameraController!.stopImageStream();
        // Clear frame processor
        _frameProcessor = null;

        if (kDebugMode) {
          print('Camera stream stopped');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping camera stream: $e');
      }
    }
  }

  /// Disposes of the camera controller and frees all resources
  /// This permanently closes the camera and should be called during app cleanup
  ///
  /// Usage Example:
  /// ```dart
  /// await cameraService.dispose();
  /// ```
  Future<void> dispose() async {
    try {
      await stopCameraStream();
      if (_cameraController != null) {
        await _cameraController!.dispose();
        _cameraController = null;
        if (kDebugMode) {
          print('Camera controller disposed');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error disposing camera: $e');
      }
    }
  }

  /// Switches between front and rear cameras during runtime
  ///
  /// Parameters:
  /// - cameraIndex: Index of the camera to switch to
  /// - frameProcessor: Callback for processing frames from new camera
  ///
  /// Returns: bool - True if switch was successful
  ///
  /// Usage Example:
  /// ```dart
  /// bool switched = await cameraService.switchCamera(
  ///   cameraIndex: 1,
  ///   frameProcessor: myFrameProcessor
  /// );
  /// ```
  Future<bool> switchCamera({
    required int cameraIndex,
    required Function(CameraImage) frameProcessor,
  }) async {
    try {
      await stopCameraStream();
      await startCameraStream(
        cameraIndex: cameraIndex,
        frameProcessor: frameProcessor,
      );
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error switching camera: $e');
      }
      return false;
    }
  }

  /// Captures a single image from the camera
  /// Useful for gallery-like functionality
  ///
  /// Returns: XFile? - The captured image file, or null if capture fails
  ///
  /// Usage Example:
  /// ```dart
  /// final image = await cameraService.captureImage();
  /// if (image != null) {
  ///   // Use image
  /// }
  /// ```
  Future<XFile?> captureImage() async {
    try {
      if (_cameraController == null ||
          !_cameraController!.value.isInitialized) {
        throw Exception('Camera is not initialized');
      }

      return await _cameraController!.takePicture();
    } catch (e) {
      if (kDebugMode) {
        print('Error capturing image: $e');
      }
      return null;
    }
  }
}
