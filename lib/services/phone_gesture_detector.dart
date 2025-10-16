import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Simple phone-based gesture detector for START/STOP tracking
/// Uses ML Kit Pose Detection to recognize hand gestures
class PhoneGestureDetector {
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream),
  );

  bool _isProcessing = false;
  DateTime? _lastGestureTime;
  static const Duration _gestureCooldown = Duration(milliseconds: 1500);

  /// Detect gesture from camera image
  /// Returns: 'start', 'stop', or null
  Future<String?> detectGesture(CameraImage image) async {
    if (_isProcessing) return null;

    // Cooldown to prevent rapid detection
    if (_lastGestureTime != null &&
        DateTime.now().difference(_lastGestureTime!) < _gestureCooldown) {
      return null;
    }

    _isProcessing = true;

    try {
      // Convert CameraImage to InputImage for ML Kit
      final inputImage = _convertCameraImage(image);
      if (inputImage == null) {
        _isProcessing = false;
        return null;
      }

      // Detect poses
      final poses = await _poseDetector.processImage(inputImage);

      if (poses.isEmpty) {
        _isProcessing = false;
        return null;
      }

      // Get the first detected pose
      final pose = poses.first;

      // Detect gestures based on pose landmarks
      final gesture = _recognizeGesture(pose);

      if (gesture != null) {
        _lastGestureTime = DateTime.now();
      }

      _isProcessing = false;
      return gesture;
    } catch (e) {
      _isProcessing = false;
      return null;
    }
  }

  /// Detect gesture from file path
  Future<String?> detectGestureFromFile(InputImage inputImage) async {
    if (_isProcessing) return null;

    // Cooldown to prevent rapid detection
    if (_lastGestureTime != null &&
        DateTime.now().difference(_lastGestureTime!) < _gestureCooldown) {
      return null;
    }

    _isProcessing = true;

    try {
      // Detect poses
      final poses = await _poseDetector.processImage(inputImage);

      print('📸 Poses detected: ${poses.length}');

      if (poses.isEmpty) {
        _isProcessing = false;
        return null;
      }

      // Get the first detected pose
      final pose = poses.first;

      // Detect gestures based on pose landmarks
      final gesture = _recognizeGesture(pose);

      if (gesture != null) {
        _lastGestureTime = DateTime.now();
      }

      _isProcessing = false;
      return gesture;
    } catch (e) {
      print('❌ Pose detection error: $e');
      _isProcessing = false;
      return null;
    }
  }

  /// Recognize gesture from pose landmarks
  String? _recognizeGesture(Pose pose) {
    final landmarks = pose.landmarks;

    // Get key points
    final leftWrist = landmarks[PoseLandmarkType.leftWrist];
    final rightWrist = landmarks[PoseLandmarkType.rightWrist];
    final leftElbow = landmarks[PoseLandmarkType.leftElbow];
    final rightElbow = landmarks[PoseLandmarkType.rightElbow];
    final leftShoulder = landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = landmarks[PoseLandmarkType.rightShoulder];

    if (leftWrist == null ||
        rightWrist == null ||
        leftElbow == null ||
        rightElbow == null ||
        leftShoulder == null ||
        rightShoulder == null) {
      print('⚠️ Missing landmarks - cannot detect gesture');
      return null;
    }

    // Debug: Print landmark positions (in image coordinates, higher Y = lower on screen)
    final leftDiff =
        leftShoulder.y -
        leftWrist.y; // POSITIVE = wrist is ABOVE shoulder (hand UP)
    final rightDiff =
        rightShoulder.y -
        rightWrist.y; // POSITIVE = wrist is ABOVE shoulder (hand UP)

    print(
      '📍 Left hand diff: ${leftDiff.toStringAsFixed(1)} (wrist: ${leftWrist.y.toStringAsFixed(0)}, shoulder: ${leftShoulder.y.toStringAsFixed(0)})',
    );
    print(
      '📍 Right hand diff: ${rightDiff.toStringAsFixed(1)} (wrist: ${rightWrist.y.toStringAsFixed(0)}, shoulder: ${rightShoulder.y.toStringAsFixed(0)})',
    );

    // SIMPLE GESTURE: Just raise ANY hand significantly above shoulder
    // POSITIVE diff = Hand is raised UP (wrist Y < shoulder Y)
    final leftHandUp = leftDiff > 100; // Hand needs to be 100px above shoulder
    final rightHandUp = rightDiff > 100;

    print(
      '✋ Left hand UP (diff > 100): $leftHandUp, Right hand UP (diff > 100): $rightHandUp',
    );

    if (leftHandUp || rightHandUp) {
      print('🎯 GESTURE DETECTED: START (Hand raised high!)');
      return 'start'; // 👍 Hand raised = START
    }

    // OPEN PALM detection (STOP gesture)
    // Both hands at shoulder level, extended to sides
    final bothHandsAtShoulderLevel =
        _isNearShoulderHeight(leftWrist, leftShoulder) &&
        _isNearShoulderHeight(rightWrist, rightShoulder);

    final handsExtended =
        _getDistance(leftWrist, rightWrist) >
        _getDistance(leftShoulder, rightShoulder) * 1.3; // More lenient

    if (bothHandsAtShoulderLevel && handsExtended) {
      print('🎯 GESTURE DETECTED: STOP (T-pose)');
      return 'stop'; // ✋ Open palm (T-pose) = STOP
    }

    return null;
  }

  /// Check if point is near shoulder height
  bool _isNearShoulderHeight(PoseLandmark point, PoseLandmark shoulder) {
    return (point.y - shoulder.y).abs() < 150; // More lenient range
  }

  /// Calculate distance between two points
  double _getDistance(PoseLandmark p1, PoseLandmark p2) {
    return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2));
  }

  /// Convert CameraImage to InputImage
  InputImage? _convertCameraImage(CameraImage image) {
    try {
      // Get image metadata
      final allBytes = BytesBuilder();
      for (final Plane plane in image.planes) {
        allBytes.add(plane.bytes);
      }
      final bytes = allBytes.toBytes();

      final Size imageSize = Size(
        image.width.toDouble(),
        image.height.toDouble(),
      );

      const InputImageRotation imageRotation = InputImageRotation.rotation0deg;

      final InputImageFormat inputImageFormat =
          InputImageFormatValue.fromRawValue(image.format.raw) ??
          InputImageFormat.nv21;

      final metadata = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes.first.bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _poseDetector.close();
  }
}
