import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Callback type for gesture detection
typedef GestureCallback = void Function(GestureData gesture);

/// Service for communicating with the hand gesture recognition server
class GestureService {
  static const String _baseUrl = 'http://localhost:8080';
  static const Duration _pollInterval = Duration(milliseconds: 500);

  Timer? _pollTimer;
  GestureCallback? _onGestureDetected;
  String _lastAction = '';

  /// Start polling for gesture updates
  void startListening(GestureCallback onGestureDetected) {
    _onGestureDetected = onGestureDetected;
    _lastAction = '';

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollGestureStatus());

    print('👋 Started listening for hand gestures');
  }

  /// Stop polling for gesture updates
  void stopListening() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _onGestureDetected = null;

    print('🛑 Stopped listening for hand gestures');
  }

  /// Poll the gesture server for current status
  Future<void> _pollGestureStatus() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/gesture/status'))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final gestureData = GestureData.fromJson(data);

        // Only trigger callback if action changed
        if (gestureData.action != _lastAction && gestureData.action != 'none') {
          _lastAction = gestureData.action;
          _onGestureDetected?.call(gestureData);
        }
      }
    } catch (e) {
      // Silently fail - server might not be running
      // print('Gesture service error: $e');
    }
  }

  /// Check if the gesture server is available
  Future<bool> isServerAvailable() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/gesture/status'))
          .timeout(const Duration(seconds: 2));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    stopListening();
  }
}

/// Data model for gesture information
class GestureData {
  final String gesture;
  final String action;
  final bool isTracking;
  final double timestamp;

  GestureData({
    required this.gesture,
    required this.action,
    required this.isTracking,
    required this.timestamp,
  });

  factory GestureData.fromJson(Map<String, dynamic> json) {
    return GestureData(
      gesture: json['gesture'] as String? ?? 'Unknown',
      action: json['action'] as String? ?? 'none',
      isTracking: json['is_tracking'] as bool? ?? false,
      timestamp: (json['timestamp'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  String toString() {
    return 'GestureData(gesture: $gesture, action: $action, isTracking: $isTracking)';
  }
}
