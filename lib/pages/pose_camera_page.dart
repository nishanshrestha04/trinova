import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import '../services/pose_service.dart';
import '../services/yoga_gesture_detector.dart'; // Changed to yoga gesture detector

class PoseCameraPage extends StatefulWidget {
  final String poseName;
  final String poseSanskrit;
  final Color themeColor;

  const PoseCameraPage({
    super.key,
    required this.poseName,
    required this.poseSanskrit,
    required this.themeColor,
  });

  @override
  State<PoseCameraPage> createState() => _PoseCameraPageState();
}

class _PoseCameraPageState extends State<PoseCameraPage> {
  CameraController? _cameraController;
  bool _isLoading = true;
  bool _isAnalyzing = false;
  bool _isLiveTracking = false;
  String? _errorMessage;
  Map<String, dynamic>? _analysisResult;
  final ImagePicker _picker = ImagePicker();
  Timer? _analysisTimer;
  DateTime? _lastAnalysisTime;

  // Store uploaded image
  Uint8List? _uploadedImageBytes;

  // Camera management
  List<CameraDescription> _availableCameras = [];
  int _currentCameraIndex = 0;

  // Yoga gesture control via server
  final YogaGestureDetector _gestureDetector = YogaGestureDetector();
  String _lastGesture = '';
  StreamSubscription? _gestureSubscription;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras found on this device';
          _isLoading = false;
        });
        return;
      }

      _availableCameras = cameras;

      // Use front camera if available, otherwise use first camera
      _currentCameraIndex = cameras.indexWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
      );
      if (_currentCameraIndex == -1) {
        _currentCameraIndex = 0;
      }

      _cameraController = CameraController(
        _availableCameras[_currentCameraIndex],
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      // Start gesture detection from camera stream
      _startGestureDetection();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize camera: $e';
        _isLoading = false;
      });
    }
  }

  void _startGestureDetection() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print('⚠️ Camera not ready for gesture detection');
      return;
    }

    // Check if gesture backend is available
    final isAvailable = await _gestureDetector.isServerAvailable();
    if (!isAvailable) {
      print('⚠️ Yoga gesture backend not available');
      print('💡 Make sure backend is running: ./start_backend.sh');
      print('💡 Backend URL: ${_gestureDetector.serverUrl}');
      return;
    }

    print('✅ Yoga gesture backend connected at ${_gestureDetector.serverUrl}!');
    print('📸 Sending camera frames to backend for gesture detection...');

    // Listen to gesture stream (now sending camera frames)
    _gestureSubscription = _gestureDetector
        .startGestureDetection(_cameraController!)
        .listen(
          (gesture) {
            if (gesture != null && mounted) {
              setState(() {
                _lastGesture = gesture == 'start'
                    ? 'Thumbs Up'
                    : gesture == 'stop'
                    ? 'Open Palm'
                    : 'Point';
              });

              _handleGesture(gesture);
            }
          },
          onError: (error) {
            print('Gesture detection error: $error');
          },
        );
  }

  void _handleGesture(String gesture) {
    print('🎮 Handling gesture: $gesture (isLiveTracking: $_isLiveTracking)');

    if (gesture == 'start' && !_isLiveTracking) {
      _startLiveTracking();
      _showGestureFeedback('TRACKING STARTED by gesture');
    } else if (gesture == 'stop' && _isLiveTracking) {
      _stopLiveTracking();
      _showGestureFeedback('TRACKING STOPPED by gesture');
    }
  }

  void _showGestureFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startLiveTracking() {
    if (_isLiveTracking) return;

    setState(() {
      _isLiveTracking = true;
      _analysisResult = null;
    });

    // Analyze pose every 2 seconds
    _analysisTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_isLiveTracking || _cameraController == null) {
        timer.cancel();
        return;
      }
      _analyzeLiveFrame();
    });
  }

  void _stopLiveTracking() {
    setState(() {
      _isLiveTracking = false;
      _analysisResult = null;
    });
    _analysisTimer?.cancel();
    _analysisTimer = null;
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No other camera available'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Dispose current controller
    await _cameraController?.dispose();
    _gestureSubscription?.cancel();

    // Switch to next camera
    _currentCameraIndex = (_currentCameraIndex + 1) % _availableCameras.length;

    // Initialize new camera
    _cameraController = CameraController(
      _availableCameras[_currentCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await _cameraController!.initialize();

    // Restart gesture detection
    _startGestureDetection();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _analyzeLiveFrame() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isAnalyzing) {
      return;
    }

    // Prevent too frequent analysis
    if (_lastAnalysisTime != null) {
      final timeSinceLastAnalysis = DateTime.now().difference(
        _lastAnalysisTime!,
      );
      if (timeSinceLastAnalysis.inMilliseconds < 1500) {
        return;
      }
    }

    setState(() {
      _isAnalyzing = true;
    });

    try {
      // Take picture for pose analysis
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();

      // Get pose ID from name
      String poseId = widget.poseName.toLowerCase();
      if (poseId.contains('tree')) {
        poseId = 'tree';
      } else if (poseId.contains('cobra')) {
        poseId = 'cobra';
      } else if (poseId.contains('warrior')) {
        poseId = 'warrior';
      }

      final result = await PoseService.analyzePoseImage(poseId, bytes);

      if (mounted && _isLiveTracking) {
        setState(() {
          _analysisResult = result;
          _lastAnalysisTime = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        print('Live analysis error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    setState(() {
      _isAnalyzing = true;
      _analysisResult = null;
      _uploadedImageBytes = null; // Clear previous image
    });

    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

      if (image == null) {
        setState(() => _isAnalyzing = false);
        return;
      }

      final bytes = await image.readAsBytes();

      // Get pose ID from name
      String poseId = widget.poseName.toLowerCase();
      if (poseId.contains('tree')) {
        poseId = 'tree';
      } else if (poseId.contains('cobra')) {
        poseId = 'cobra';
      } else if (poseId.contains('warrior')) {
        poseId = 'warrior';
      }

      final result = await PoseService.analyzePoseImage(poseId, bytes);

      setState(() {
        _analysisResult = result;
        _uploadedImageBytes = bytes; // Store the image
        _isAnalyzing = false;
      });

      // Don't show dialog - result will be displayed in the overlay
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _uploadedImageBytes = null;
      });
      _showErrorDialog('Analysis failed: $e');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Stop live tracking
    _analysisTimer?.cancel();
    _analysisTimer = null;

    // Stop gesture detection
    _gestureSubscription?.cancel();
    _gestureDetector.dispose();

    // Dispose camera controller
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (bool didPop) {
        // Cleanup when back button is pressed
        if (didPop) {
          _analysisTimer?.cancel();
          _cameraController?.dispose();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Quick exit without waiting
              _analysisTimer?.cancel();
              _cameraController?.dispose();
              Navigator.of(context).pop();
            },
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.poseName, style: const TextStyle(fontSize: 18)),
              Text(
                widget.poseSanskrit,
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          backgroundColor: widget.themeColor,
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: 64,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      // Hide Pick from Gallery button when tracking is active
                      if (!_isLiveTracking) ...[
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _pickFromGallery,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Pick from Gallery'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.themeColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            : Stack(
                children: [
                  // Display uploaded image OR camera preview
                  if (_uploadedImageBytes != null)
                    // Show uploaded image
                    SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: Image.memory(_uploadedImageBytes!),
                      ),
                    )
                  else
                    // Show Camera Preview - Fullscreen
                    SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _cameraController!.value.previewSize!.height,
                          height: _cameraController!.value.previewSize!.width,
                          child: CameraPreview(_cameraController!),
                        ),
                      ),
                    ),

                  // Pose skeleton overlay
                  if (_analysisResult != null &&
                      _analysisResult!['landmarks'] != null)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: PoseSkeletonPainter(
                          landmarks: _analysisResult!['landmarks'],
                        ),
                      ),
                    ),

                  // Error indicators overlay (red circles showing what's wrong)
                  if (_analysisResult != null &&
                      _analysisResult!['issues'] != null &&
                      (_analysisResult!['issues'] as List).isNotEmpty)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: PoseIssuesPainter(
                          issues: _analysisResult!['issues'],
                          imageWidth: _uploadedImageBytes != null
                              ? (_analysisResult!['image_width'] ?? 640)
                              : _cameraController!.value.previewSize!.height
                                    .toInt(),
                          imageHeight: _uploadedImageBytes != null
                              ? (_analysisResult!['image_height'] ?? 480)
                              : _cameraController!.value.previewSize!.width
                                    .toInt(),
                        ),
                      ),
                    ),

                  // Instructions overlay - Hidden when tracking is active or when analysis result is shown
                  if (!_isLiveTracking && _analysisResult == null)
                    Positioned(
                      top: 20,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Position yourself',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Make sure your full body is visible',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            // Gesture control indicator
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.greenAccent,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.pan_tool,
                                        color: Colors.greenAccent,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Hand Gesture Control',
                                        style: const TextStyle(
                                          color: Colors.greenAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_lastGesture.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Last: $_lastGesture',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    'Thumbs Up = START  •  Open Palm = STOP',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Analysis result overlay
                  if (_analysisResult != null)
                    Positioned(
                      bottom: 120,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: widget.themeColor.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Status and Score - compact single row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _analysisResult!['is_correct']
                                          ? Icons.check_circle
                                          : Icons.warning_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _analysisResult!['is_correct']
                                          ? 'Correct'
                                          : 'Adjust',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${((_analysisResult!['score'] ?? 0.0) * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            // Issues count - only if there are problems
                            if (!_analysisResult!['is_correct'] &&
                                _analysisResult!['issues'] != null &&
                                (_analysisResult!['issues'] as List)
                                    .isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                '${(_analysisResult!['issues'] as List).length} areas marked',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                  // Bottom controls
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Back to Camera button - Shown when uploaded image is displayed
                            if (_uploadedImageBytes != null)
                              FloatingActionButton.extended(
                                onPressed: () {
                                  setState(() {
                                    _uploadedImageBytes = null;
                                    _analysisResult = null;
                                  });
                                },
                                backgroundColor: Colors.white,
                                icon: Icon(
                                  Icons.camera_alt,
                                  color: widget.themeColor,
                                ),
                                label: Text(
                                  'Back to Camera',
                                  style: TextStyle(
                                    color: widget.themeColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                            // Gallery button - Hidden when tracking is active or image is uploaded
                            if (!_isLiveTracking && _uploadedImageBytes == null)
                              FloatingActionButton(
                                onPressed: _pickFromGallery,
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.photo_library,
                                  color: widget.themeColor,
                                ),
                              ),

                            // Camera flip button - Shown when tracking is active and no uploaded image
                            if (_isLiveTracking &&
                                _availableCameras.length > 1 &&
                                _uploadedImageBytes == null)
                              FloatingActionButton(
                                onPressed: _switchCamera,
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.flip_camera_android,
                                  color: widget.themeColor,
                                ),
                              ),

                            // Live tracking toggle button - Hidden when uploaded image is shown
                            if (_uploadedImageBytes == null)
                              FloatingActionButton.extended(
                                onPressed: _isLiveTracking
                                    ? _stopLiveTracking
                                    : _startLiveTracking,
                                backgroundColor: _isLiveTracking
                                    ? Colors.red
                                    : widget.themeColor,
                                icon: Icon(
                                  _isLiveTracking
                                      ? Icons.stop
                                      : Icons.play_arrow,
                                  color: Colors.white,
                                ),
                                label: Text(
                                  _isLiveTracking
                                      ? 'Stop Tracking'
                                      : 'Start Tracking',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                            // Tips button
                            if (_uploadedImageBytes == null)
                              FloatingActionButton(
                                onPressed: () => _showTipsDialog(),
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.lightbulb_outline,
                                  color: widget.themeColor,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _showTipsDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        title: Text('${widget.poseName} Tips'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Camera Setup:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Position camera at chest height'),
              const Text('• Ensure full body is visible'),
              const Text('• Use good lighting'),
              const SizedBox(height: 16),
              const Text(
                'Pose Tips:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (widget.poseName.toLowerCase().contains('tree'))
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Stand on one leg firmly'),
                    Text('• Place foot on inner thigh'),
                    Text('• Keep hips level'),
                    Text('• Bring hands overhead'),
                  ],
                )
              else if (widget.poseName.toLowerCase().contains('cobra'))
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Lie face down'),
                    Text('• Place hands under shoulders'),
                    Text('• Lift chest gently'),
                    Text('• Keep elbows slightly bent'),
                  ],
                )
              else
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Stand with feet wide apart'),
                    Text('• Bend front knee to 90°'),
                    Text('• Extend arms parallel'),
                    Text('• Look over front hand'),
                  ],
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

// Custom painter for drawing pose skeleton overlay
class PoseSkeletonPainter extends CustomPainter {
  final List<dynamic> landmarks;

  PoseSkeletonPainter({required this.landmarks});

  @override
  void paint(Canvas canvas, Size size) {
    if (landmarks.isEmpty) return;

    final paint = Paint()
      ..color = Colors.greenAccent
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 8.0
      ..style = PaintingStyle.fill;

    // MediaPipe pose connections (same as Python script)
    final connections = [
      // Face
      [0, 1], [1, 2], [2, 3], [3, 7], [0, 4], [4, 5], [5, 6], [6, 8],
      // Torso
      [9, 10], [11, 12], [11, 13], [13, 15], [12, 14], [14, 16],
      [11, 23], [12, 24], [23, 24],
      // Left arm
      [11, 13], [13, 15], [15, 17], [15, 19], [15, 21], [17, 19],
      // Right arm
      [12, 14], [14, 16], [16, 18], [16, 20], [16, 22], [18, 20],
      // Left leg
      [23, 25], [25, 27], [27, 29], [27, 31], [29, 31],
      // Right leg
      [24, 26], [26, 28], [28, 30], [28, 32], [30, 32],
    ];

    // Draw connections
    for (var connection in connections) {
      if (connection[0] < landmarks.length &&
          connection[1] < landmarks.length) {
        final start = landmarks[connection[0]];
        final end = landmarks[connection[1]];

        // Check visibility
        if ((start['visibility'] ?? 0) > 0.5 &&
            (end['visibility'] ?? 0) > 0.5) {
          final startPoint = Offset(
            start['x'] * size.width,
            start['y'] * size.height,
          );
          final endPoint = Offset(
            end['x'] * size.width,
            end['y'] * size.height,
          );

          canvas.drawLine(startPoint, endPoint, paint);
        }
      }
    }

    // Draw landmark points
    for (var landmark in landmarks) {
      if ((landmark['visibility'] ?? 0) > 0.5) {
        final point = Offset(
          landmark['x'] * size.width,
          landmark['y'] * size.height,
        );
        canvas.drawCircle(point, 4, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

// Custom painter for drawing error indicators (red circles)
class PoseIssuesPainter extends CustomPainter {
  final List<dynamic> issues;
  final int imageWidth;
  final int imageHeight;

  PoseIssuesPainter({
    required this.issues,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (issues.isEmpty) return;

    // Paint for error circles - thick red outline with transparency
    final paint = Paint()
      ..color = Colors.red.withValues(alpha: 0.8)
      ..strokeWidth = 10.0
      ..style = PaintingStyle.stroke;

    // Draw each issue marker
    for (var issue in issues) {
      final x = issue['x'] as int;
      final y = issue['y'] as int;
      final radius = issue['radius'] as int;

      // Convert from image coordinates to screen coordinates
      final screenX = (x / imageWidth) * size.width;
      final screenY = (y / imageHeight) * size.height;
      final screenRadius = (radius / imageWidth) * size.width;

      // Draw red circle indicator
      canvas.drawCircle(Offset(screenX, screenY), screenRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
