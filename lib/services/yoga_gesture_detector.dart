import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:camera/camera.dart';

/// Yoga gesture detector using MediaPipe Hands via Django backend
/// Sends camera images to backend for hand gesture recognition
class YogaGestureDetector {
  final String serverUrl;
  CameraController? _cameraController;
  bool _isRunning = false;
  DateTime? _lastGestureTime;
  static const Duration _gestureCooldown = Duration(milliseconds: 1500);

  YogaGestureDetector({String? serverUrl})
    : serverUrl = serverUrl ?? _getDefaultUrl();

  /// Get default URL based on platform
  /// For Android emulator: http://10.0.2.2:8000
  /// For real device: http://192.168.18.6:8000 (your computer's local IP)
  /// You can override by passing custom URL
  static String _getDefaultUrl() {
    // For real Android device, use your computer's local IP
    // Change this to your computer's IP address
    return 'http://192.168.18.6:8000';

    // For Android emulator, uncomment this:
    // return 'http://10.0.2.2:8000';
  }

  /// Start gesture detection by sending camera frames to backend
  /// Requires a camera controller from the calling page
  Stream<String?> startGestureDetection(
    CameraController cameraController,
  ) async* {
    _cameraController = cameraController;
    _isRunning = true;

    while (_isRunning && _cameraController != null) {
      try {
        final gesture = await _detectGestureFromCamera();
        if (gesture != null) {
          yield gesture;
        }
        await Future.delayed(
          const Duration(seconds: 2),
        ); // Check every 2 seconds
      } catch (e) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  /// Detect gesture by sending current camera frame to backend
  Future<String?> _detectGestureFromCamera() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return null;
    }

    // Cooldown to prevent rapid detection
    if (_lastGestureTime != null &&
        DateTime.now().difference(_lastGestureTime!) < _gestureCooldown) {
      return null;
    }

    try {
      // Capture image from camera
      final XFile image = await _cameraController!.takePicture();
      final Uint8List imageBytes = await image.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      // Send to backend for gesture detection
      final response = await http
          .post(
            Uri.parse('$serverUrl/api/poses/gesture/detect/'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'image': base64Image}),
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final action = data['action'] as String?;

        if (action != null && action != 'none') {
          _lastGestureTime = DateTime.now();

          // Map actions to our START/STOP commands
          switch (action) {
            case 'resume': // Thumbs up
              return 'start';
            case 'pause': // Open palm
              return 'stop';
            case 'next': // Point
              return 'next';
            default:
              return null;
          }
        }
      }
    } catch (e) {
      return null;
    }

    return null;
  }

  /// Check if backend is available
  Future<bool> isServerAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('$serverUrl/api/poses/gesture/status/'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Stop gesture detection
  void dispose() {
    _isRunning = false;
    _cameraController = null;
  }
}
