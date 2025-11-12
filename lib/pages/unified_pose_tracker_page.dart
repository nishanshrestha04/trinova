import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/pose_service.dart';
import '../services/yoga_gesture_detector.dart';

class UnifiedPoseTrackerPage extends StatefulWidget {
  const UnifiedPoseTrackerPage({super.key});

  @override
  State<UnifiedPoseTrackerPage> createState() => _UnifiedPoseTrackerPageState();
}

class _UnifiedPoseTrackerPageState extends State<UnifiedPoseTrackerPage> {
  // Unified color theme
  static const Color primaryColor = Color(0xFF6366F1); // Indigo
  static const Color secondaryColor = Color(0xFF8B5CF6); // Purple
  static const Color accentColor = Color(0xFF10B981); // Green
  static const Color errorColor = Color(0xFFEF4444); // Red
  static const Color warningColor = Color(0xFFF59E0B); // Amber

  CameraController? _cameraController;
  bool _isLoading = true;
  bool _isAnalyzing = false;
  bool _isLiveTracking = false;
  bool _isPaused = false; // Track if tracking is paused
  String? _errorMessage;
  Map<String, dynamic>? _analysisResult;
  Timer? _analysisTimer;
  DateTime? _lastAnalysisTime;

  // Timer for pose duration
  Timer? _poseTimer;
  int _poseSeconds = 0;

  // Rest period between poses
  bool _isResting = false;
  Timer? _restTimer;
  int _restSeconds = 0;
  int _currentRestDuration = 30; // Dynamic rest duration (starts at 30s)
  static const int restDuration = 30; // Default 30 seconds rest

  // Available poses with recommended durations
  final List<Map<String, dynamic>> _availablePoses = [
    {
      'id': 'tree',
      'name': 'Tree Pose',
      'sanskrit': 'Vrikshasana',
      'icon': Icons.park,
      'duration': 60, // 60 seconds recommended
    },
    {
      'id': 'cobra',
      'name': 'Cobra Pose',
      'sanskrit': 'Bhujangasana',
      'icon': Icons.pets,
      'duration': 45, // 45 seconds recommended
    },
    {
      'id': 'warrior1',
      'name': 'Warrior I',
      'sanskrit': 'Virabhadrasana I',
      'icon': Icons.fitness_center,
      'duration': 60, // 60 seconds recommended
    },
    {
      'id': 'warrior',
      'name': 'Warrior II',
      'sanskrit': 'Virabhadrasana II',
      'icon': Icons.fitness_center,
      'duration': 60, // 60 seconds recommended
    },
    {
      'id': 'warrior3',
      'name': 'Warrior III',
      'sanskrit': 'Virabhadrasana III',
      'icon': Icons.fitness_center,
      'duration': 60, // 60 seconds recommended
    },
  ];

  int _currentPoseIndex = 0;
  String? _selectedPoseId;
  Map<String, dynamic>? _selectedPose;

  // Camera management
  List<CameraDescription> _availableCameras = [];
  int _currentCameraIndex = 0;

  // Yoga gesture control via server
  final YogaGestureDetector _gestureDetector = YogaGestureDetector();
  StreamSubscription? _gestureSubscription;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    // Start with tree pose automatically
    _selectPose(_availablePoses[0]);
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
              _handleGesture(gesture);
            }
          },
          onError: (error) {
            print('Gesture detection error: $error');
          },
        );
  }

  void _handleGesture(String gesture) {
    print(
      '🎮 Handling gesture: $gesture (isLiveTracking: $_isLiveTracking, isPaused: $_isPaused)',
    );

    if (gesture == 'start' &&
        (!_isLiveTracking || _isPaused) &&
        _selectedPoseId != null) {
      if (_isPaused) {
        _resumeLiveTracking();
        _showGestureFeedback('TRACKING RESUMED by gesture');
      } else {
        _startLiveTracking();
        _showGestureFeedback('TRACKING STARTED by gesture');
      }
    } else if (gesture == 'stop' && _isLiveTracking && !_isPaused) {
      _pauseLiveTracking();
      _showGestureFeedback('TRACKING PAUSED by gesture');
    } else if (gesture == 'next' && _isLiveTracking) {
      // Handle next pose gesture
      if (_isResting) {
        // If resting, skip the rest period
        _skipRestPeriod();
        _showGestureFeedback('REST SKIPPED by gesture');
      } else if (_currentPoseIndex < _availablePoses.length - 1) {
        // Move to next pose
        _goToNextPose();
        _showGestureFeedback('NEXT POSE by gesture');
      } else {
        // Already on last pose
        _showGestureFeedback('Already on last pose');
      }
    }
  }

  void _showGestureFeedback(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.touch_app, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.black87,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80, left: 20, right: 20),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _startLiveTracking() {
    if (_selectedPoseId == null) return;

    // If already tracking, don't restart timers
    if (_isLiveTracking && !_isPaused) return;

    setState(() {
      _isLiveTracking = true;
      _isPaused = false;
      _analysisResult = null;
    });

    // Only create new timers if they don't exist
    if (_poseTimer == null || !_poseTimer!.isActive) {
      // Start pose duration timer
      _poseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!_isLiveTracking || _isPaused) {
          return; // Don't cancel, just pause
        }
        setState(() {
          _poseSeconds++;
        });

        // Auto-advance to next pose after recommended duration
        final recommendedDuration = _selectedPose?['duration'] ?? 60;
        if (_poseSeconds >= recommendedDuration) {
          if (_currentPoseIndex < _availablePoses.length - 1) {
            _goToNextPose();
          } else {
            // Completed last pose - show completion and navigate back
            _completeAllPoses();
          }
        }
      });
    }

    // Only create analysis timer if it doesn't exist
    if (_analysisTimer == null || !_analysisTimer!.isActive) {
      // Analyze pose every 2 seconds
      _analysisTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (!_isLiveTracking || _isPaused || _cameraController == null) {
          return; // Don't cancel, just pause
        }
        _analyzeLiveFrame();
      });
    }
  }

  void _pauseLiveTracking() {
    setState(() {
      _isPaused = true;
    });
  }

  void _resumeLiveTracking() {
    setState(() {
      _isPaused = false;
    });
  }

  void _stopLiveTracking() {
    setState(() {
      _isLiveTracking = false;
      _isPaused = false;
      _analysisResult = null;
      _poseSeconds = 0; // Reset timer when completely stopping
    });
    _analysisTimer?.cancel();
    _analysisTimer = null;
    _poseTimer?.cancel();
    _poseTimer = null;
  }

  void _startRestPeriod() {
    setState(() {
      _isResting = true;
      _restSeconds = restDuration;
      _currentRestDuration = restDuration; // Reset to base duration
    });

    _stopLiveTracking();

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSeconds > 0) {
        setState(() {
          _restSeconds--;
        });
      } else {
        timer.cancel();
        _endRestPeriod();
      }
    });
  }

  void _skipRestPeriod() {
    _restTimer?.cancel();
    _restTimer = null;
    _endRestPeriod();
  }

  void _endRestPeriod() {
    setState(() {
      _isResting = false;
      _restSeconds = 0;
    });
    // Auto-start tracking for new pose
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _startLiveTracking();
      }
    });
  }

  Future<void> _switchCamera() async {
    if (_availableCameras.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.info_outline, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                'No other camera',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.black87,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 80, left: 20, right: 20),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        _isAnalyzing ||
        _selectedPoseId == null) {
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

      final result = await PoseService.analyzePoseImage(
        _selectedPoseId!,
        bytes,
      );

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

  void _selectPose(Map<String, dynamic> pose) {
    final poseIndex = _availablePoses.indexWhere((p) => p['id'] == pose['id']);

    setState(() {
      _currentPoseIndex = poseIndex;
      _selectedPoseId = pose['id'];
      _selectedPose = pose;
      _analysisResult = null;
      _poseSeconds = 0; // Reset timer when changing pose
    });

    // Don't auto-start if this is initial selection
    if (_isLiveTracking) {
      // If currently tracking, start rest period before new pose
      _startRestPeriod();
    }
  }

  void _goToNextPose() {
    if (_currentPoseIndex < _availablePoses.length - 1) {
      final nextPose = _availablePoses[_currentPoseIndex + 1];
      _selectPose(nextPose);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(nextPose['icon'], color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                nextPose['name'],
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: secondaryColor.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(bottom: 80, left: 20, right: 20),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } else {
      // Completed all poses - call dedicated completion method
      _completeAllPoses();
    }
  }

  void _completeAllPoses() {
    _stopLiveTracking();

    // Show beautiful completion dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryColor, secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events,
                  size: 64,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Congratulations!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'You\'ve completed all poses',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '${_availablePoses.length} poses mastered! 🧘‍♀️',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Go back to poses section
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Back to Poses',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _analysisTimer?.cancel();
    _poseTimer?.cancel();
    _restTimer?.cancel();
    _gestureSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          _selectedPose != null ? _selectedPose!['name'] : 'Yoga Pose Tracker',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          if (_cameraController != null &&
              _cameraController!.value.isInitialized)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios),
              onPressed: _switchCamera,
              tooltip: 'Switch Camera',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Stack(
              children: [
                // Full screen camera preview
                if (_cameraController != null &&
                    _cameraController!.value.isInitialized)
                  SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _cameraController!.value.previewSize!.height,
                        height: _cameraController!.value.previewSize!.width,
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
                  )
                else
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),

                // Semi-transparent overlay for better text visibility
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.6),
                      ],
                      stops: const [0.0, 0.2, 0.8, 1.0],
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
                        imageWidth: _cameraController!.value.previewSize!.height
                            .toInt(),
                        imageHeight: _cameraController!.value.previewSize!.width
                            .toInt(),
                      ),
                    ),
                  ),

                // Top overlay - Current pose and timer
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Show timer and pause/resume button when tracking
                        if (_isResting)
                          _buildRestTimerDisplay()
                        else if (_isLiveTracking || _isPaused)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (!_isPaused) _buildPoseTimerDisplay(),
                                  if (_isPaused)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.pause_circle,
                                          color: Colors.white,
                                          size: 20,
                                          shadows: [
                                            Shadow(
                                              color: Colors.black,
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'PAUSED',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                            shadows: [
                                              Shadow(
                                                color: Colors.black,
                                                blurRadius: 8,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(width: 12),
                                  _buildStartButton(),
                                ],
                              ),
                            ],
                          )
                        else
                          _buildStartButton(),

                        const Spacer(),

                        // Bottom controls - Next pose button and score
                        if (_isLiveTracking && !_isResting && !_isPaused)
                          _buildBottomControls(),

                        if (_isResting) _buildRestControls(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStartButton() {
    // Show pause button when tracking and not paused
    if (_isLiveTracking && !_isPaused) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [warningColor, Colors.orange.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: warningColor.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextButton.icon(
          onPressed: _pauseLiveTracking,
          icon: const Icon(Icons.pause, size: 18, color: Colors.white),
          label: const Text(
            'Pause',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      );
    }

    // Show resume button when paused
    if (_isPaused) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accentColor, Colors.green.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextButton.icon(
          onPressed: _resumeLiveTracking,
          icon: const Icon(Icons.play_arrow, size: 18, color: Colors.white),
          label: const Text(
            'Resume',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      );
    }

    // Show start button when not tracking
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextButton.icon(
        onPressed: _startLiveTracking,
        icon: const Icon(Icons.play_arrow, size: 18, color: Colors.white),
        label: const Text(
          'Start Tracking',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildPoseTimerDisplay() {
    final recommendedDuration = _selectedPose?['duration'] ?? 60;
    final String formattedTime =
        '${(_poseSeconds ~/ 60).toString().padLeft(2, '0')}:${(_poseSeconds % 60).toString().padLeft(2, '0')}';
    final String recommendedTime =
        '${(recommendedDuration ~/ 60).toString().padLeft(2, '0')}:${(recommendedDuration % 60).toString().padLeft(2, '0')}';
    final progress = _poseSeconds / recommendedDuration;

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Icon(
          Icons.timer,
          color: Colors.white,
          size: 16,
          shadows: [Shadow(color: Colors.black, blurRadius: 8)],
        ),
        const SizedBox(width: 4),
        Text(
          formattedTime,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black, blurRadius: 8)],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '/ $recommendedTime',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.9),
            shadows: const [Shadow(color: Colors.black, blurRadius: 8)],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: LinearProgressIndicator(
            value: progress > 1.0 ? 1.0 : progress,
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildRestTimerDisplay() {
    final String formattedTime =
        '${(_restSeconds ~/ 60).toString().padLeft(2, '0')}:${(_restSeconds % 60).toString().padLeft(2, '0')}';

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Icon(
          Icons.hotel,
          color: Colors.white,
          size: 16,
          shadows: [Shadow(color: Colors.black, blurRadius: 8)],
        ),
        const SizedBox(width: 4),
        Text(
          formattedTime,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black, blurRadius: 8)],
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          'Rest',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white,
            shadows: [Shadow(color: Colors.black, blurRadius: 8)],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: LinearProgressIndicator(
            value: 1.0 - (_restSeconds / _currentRestDuration),
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    final score = _analysisResult?['score'] ?? 0.0;
    final hasNextPose = _currentPoseIndex < _availablePoses.length - 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Score display (if available)
        if (_analysisResult != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.star,
                color: warningColor,
                size: 18,
                shadows: [Shadow(color: Colors.black, blurRadius: 8)],
              ),
              const SizedBox(width: 4),
              Text(
                '${score.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                ),
              ),
            ],
          ),

        // Next pose button
        if (hasNextPose)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [secondaryColor, primaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: secondaryColor.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextButton.icon(
              onPressed: _goToNextPose,
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: Text(
                'Next: ${_availablePoses[_currentPoseIndex + 1]['name']}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRestControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Extend rest button
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [warningColor, primaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: warningColor.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextButton.icon(
            onPressed: _extendRestPeriod,
            icon: const Icon(Icons.add, size: 16, color: Colors.white),
            label: const Text(
              '+5s',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
        ),

        // Skip rest button
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [accentColor, primaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextButton.icon(
            onPressed: _skipRestPeriod,
            icon: const Icon(Icons.skip_next, size: 16, color: Colors.white),
            label: const Text(
              'Skip Rest',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
        ),
      ],
    );
  }

  void _extendRestPeriod() {
    setState(() {
      _restSeconds += 5; // Add 5 more seconds
      _currentRestDuration += 5; // Extend total duration for progress bar
    });
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
      ..color =
          const Color(0xFF10B981) // accentColor - Green
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color =
          const Color(0xFF8B5CF6) // secondaryColor - Purple
      ..strokeWidth = 8.0
      ..style = PaintingStyle.fill;

    // MediaPipe pose connections (same as Python script)
    final connections = [
      // Face
      [0, 1], [1, 2], [2, 3], [3, 7],
      [0, 4], [4, 5], [5, 6], [6, 8],
      // Upper body
      [9, 10],
      [11, 12], [11, 13], [13, 15], [15, 17], [15, 19], [15, 21], [17, 19],
      [12, 14], [14, 16], [16, 18], [16, 20], [16, 22], [18, 20],
      // Torso
      [11, 23], [12, 24], [23, 24],
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
      ..color = const Color(0xFFEF4444)
          .withOpacity(0.85) // errorColor - Red
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
