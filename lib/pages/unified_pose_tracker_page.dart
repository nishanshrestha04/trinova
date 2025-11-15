import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/pose_service.dart';
import '../services/yoga_gesture_detector.dart';
import '../services/user_stats_service.dart';

class UnifiedPoseTrackerPage extends StatefulWidget {
  const UnifiedPoseTrackerPage({super.key});

  @override
  State<UnifiedPoseTrackerPage> createState() => _UnifiedPoseTrackerPageState();
}

class _UnifiedPoseTrackerPageState extends State<UnifiedPoseTrackerPage> {
  // Carbon Design System color palette
  static const Color primaryColor = Color(0xFF0F62FE); // IBM Blue 60
  static const Color secondaryColor = Color(0xFF393939); // Gray 80
  static const Color accentColor = Color(0xFF198038); // Green 60
  static const Color errorColor = Color(0xFFDA1E28); // Red 60
  static const Color warningColor = Color(0xFFF1C21B); // Yellow
  static const Color backgroundColor = Color(
    0xFF161616,
  ); // Gray 100 (Carbon dark theme)
  static const Color surfaceColor = Color(0xFF262626); // Gray 90
  static const Color textPrimary = Color(0xFFFFFFFF); // White
  static const Color textSecondary = Color(0xFFC6C6C6); // Gray 30
  static const Color borderColor = Color(0xFF393939); // Gray 80

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

  // Available poses with recommended durations and difficulty
  final List<Map<String, dynamic>> _allPoses = [
    {
      'id': 'tree',
      'name': 'Tree Pose',
      'sanskrit': 'Vrikshasana',
      'icon': Icons.park,
      'duration': 60,
      'difficulty': 'Beginner',
    },
    {
      'id': 'cobra',
      'name': 'Cobra Pose',
      'sanskrit': 'Bhujangasana',
      'icon': Icons.pets,
      'duration': 45,
      'difficulty': 'Beginner',
    },
    {
      'id': 'chair',
      'name': 'Chair Pose',
      'sanskrit': 'Utkatasana',
      'icon': Icons.event_seat,
      'duration': 45,
      'difficulty': 'Beginner',
    },
    {
      'id': 'downwarddog',
      'name': 'Downward Dog',
      'sanskrit': 'Adho Mukha Svanasana',
      'icon': Icons.pets,
      'duration': 60,
      'difficulty': 'Beginner',
    },
    {
      'id': 'warrior1',
      'name': 'Warrior I',
      'sanskrit': 'Virabhadrasana I',
      'icon': Icons.fitness_center,
      'duration': 60,
      'difficulty': 'Intermediate',
    },
    {
      'id': 'warrior',
      'name': 'Warrior II',
      'sanskrit': 'Virabhadrasana II',
      'icon': Icons.fitness_center,
      'duration': 60,
      'difficulty': 'Intermediate',
    },
    {
      'id': 'triangle',
      'name': 'Triangle Pose',
      'sanskrit': 'Trikonasana',
      'icon': Icons.change_history,
      'duration': 60,
      'difficulty': 'Intermediate',
    },
    {
      'id': 'warrior3',
      'name': 'Warrior III',
      'sanskrit': 'Virabhadrasana III',
      'icon': Icons.fitness_center,
      'duration': 60,
      'difficulty': 'Advanced',
    },
  ];

  // Difficulty filter
  String _selectedDifficulty = 'All';
  List<Map<String, dynamic>> get _availablePoses {
    if (_selectedDifficulty == 'All') {
      return _allPoses;
    }
    return _allPoses
        .where((pose) => pose['difficulty'] == _selectedDifficulty)
        .toList();
  }

  int _currentPoseIndex = 0;
  String? _selectedPoseId;
  Map<String, dynamic>? _selectedPose;

  // Camera management
  List<CameraDescription> _availableCameras = [];
  int _currentCameraIndex = 0;

  // Yoga gesture control via server
  final YogaGestureDetector _gestureDetector = YogaGestureDetector();
  StreamSubscription? _gestureSubscription;

  // Session tracking
  final UserStatsService _statsService = UserStatsService();
  DateTime? _sessionStartTime;
  final List<String> _completedPoses = [];

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
      return;
    }

    // Check if gesture backend is available
    final isAvailable = await _gestureDetector.isServerAvailable();
    if (!isAvailable) {
      return;
    }

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
            // Silent error handling
          },
        );
  }

  void _handleGesture(String gesture) {
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

  void _changeDifficulty(String difficulty) {
    // Stop tracking if currently active
    if (_isLiveTracking) {
      _stopLiveTracking();
    }

    setState(() {
      _selectedDifficulty = difficulty;
      _currentPoseIndex = 0;
      _poseSeconds = 0;
    });

    // Select first pose from new difficulty
    if (_availablePoses.isNotEmpty) {
      _selectPose(_availablePoses[0]);
    }

    // Show compact notification
    final Color difficultyColor = difficulty == 'Beginner'
        ? Colors.green
        : difficulty == 'Intermediate'
        ? Colors.orange
        : difficulty == 'Advanced'
        ? Colors.red
        : primaryColor;

    final IconData difficultyIcon = difficulty == 'Beginner'
        ? Icons.child_care
        : difficulty == 'Intermediate'
        ? Icons.trending_up
        : difficulty == 'Advanced'
        ? Icons.flash_on
        : Icons.select_all;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(difficultyIcon, color: Colors.white, size: 18),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$difficulty Poses',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_availablePoses.length} pose${_availablePoses.length != 1 ? 's' : ''} available',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: difficultyColor.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(top: 80, left: 20, right: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _startLiveTracking() {
    if (_selectedPoseId == null) return;

    // If already tracking, don't restart timers
    if (_isLiveTracking && !_isPaused) return;

    // Start session timer if this is the first pose
    if (_sessionStartTime == null) {
      _sessionStartTime = DateTime.now();
    }

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
      // Silent error handling
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  void _selectPose(Map<String, dynamic> pose) async {
    final poseIndex = _availablePoses.indexWhere((p) => p['id'] == pose['id']);

    // Don't auto-start if this is initial selection
    if (_isLiveTracking) {
      // Track completed pose before moving to next
      if (_selectedPoseId != null &&
          !_completedPoses.contains(_selectedPoseId)) {
        _completedPoses.add(_selectedPoseId!);

        // Save duration and name of the PREVIOUS pose (the one just completed)
        // Round up to at least 1 minute if any time was spent (handles poses < 60 seconds)
        final completedPoseDuration = _poseSeconds > 0
            ? ((_poseSeconds + 59) ~/ 60) // Round up: (seconds + 59) / 60
            : 0;
        final completedPoseName = _selectedPose?['name']; // Previous pose name

        // Update daily streak with completed pose details
        if (completedPoseName != null && completedPoseDuration > 0) {
          try {
            await _statsService.updateDailyStreak(
              poseName: completedPoseName,
              durationMinutes: completedPoseDuration,
            );
          } catch (e) {
            // Silent error handling
          }
        }
      }
      // If currently tracking, start rest period before new pose
      _startRestPeriod();
    }

    setState(() {
      _currentPoseIndex = poseIndex;
      _selectedPoseId = pose['id'];
      _selectedPose = pose;
      _analysisResult = null;
      _poseSeconds = 0; // Reset timer when changing pose
    });
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

  void _completeAllPoses() async {
    _stopLiveTracking();

    // Track the last completed pose
    if (_selectedPoseId != null && !_completedPoses.contains(_selectedPoseId)) {
      _completedPoses.add(_selectedPoseId!);
    }

    // Calculate session duration in minutes
    int sessionDuration = 0;
    if (_sessionStartTime != null) {
      final duration = DateTime.now().difference(_sessionStartTime!);
      sessionDuration = duration.inMinutes;
    }

    // Save session stats ONLY when ALL poses are completed
    try {
      await _statsService.recordSession(
        durationMinutes: sessionDuration,
        posesCompleted: _completedPoses,
      );
    } catch (e) {
      // Silent error handling
    }

    // Show beautiful completion dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: BorderRadius.circular(0),
            border: Border.all(color: primaryColor, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
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
                    horizontal: 16,
                    vertical: 11,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Back to Poses',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.16,
                  ),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedPose != null
                  ? _selectedPose!['name']
                  : 'Yoga Pose Tracker',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (_selectedPose != null && _selectedPose!['difficulty'] != null)
              Text(
                '${_selectedPose!['difficulty']} • ${_currentPoseIndex + 1}/${_availablePoses.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // Difficulty filter dropdown
          PopupMenuButton<String>(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.filter_list, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    _selectedDifficulty,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            onSelected: (String difficulty) {
              _changeDifficulty(difficulty);
            },
            itemBuilder: (BuildContext context) {
              return <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'All',
                  child: Row(
                    children: [
                      Icon(Icons.select_all, size: 18),
                      SizedBox(width: 8),
                      Text('All Poses'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'Beginner',
                  child: Row(
                    children: [
                      Icon(Icons.child_care, size: 18, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Beginner'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'Intermediate',
                  child: Row(
                    children: [
                      Icon(Icons.trending_up, size: 18, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Intermediate'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'Advanced',
                  child: Row(
                    children: [
                      Icon(Icons.flash_on, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Advanced'),
                    ],
                  ),
                ),
              ];
            },
          ),
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
                    color: Colors.black.withOpacity(0.3),
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

                        // Bottom controls - Next pose button, score, or Back to Home
                        if (_isLiveTracking && !_isResting)
                          _buildBottomControls(),

                        // Show "Back to Home" when stopped on last pose
                        if (!_isLiveTracking &&
                            !_isResting &&
                            _currentPoseIndex == _availablePoses.length - 1)
                          _buildBackToHomeButton(),

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
          color: warningColor,
          borderRadius: BorderRadius.circular(0), // Carbon uses sharp corners
          border: Border.all(color: warningColor, width: 1),
        ),
        child: TextButton.icon(
          onPressed: _pauseLiveTracking,
          icon: const Icon(Icons.pause, size: 16, color: Color(0xFF161616)),
          label: const Text(
            'Pause',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF161616),
              letterSpacing: 0.16,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
        ),
      );
    }

    // Show resume button when paused
    if (_isPaused) {
      return Container(
        decoration: BoxDecoration(
          color: accentColor,
          borderRadius: BorderRadius.circular(0),
          border: Border.all(color: accentColor, width: 1),
        ),
        child: TextButton.icon(
          onPressed: _resumeLiveTracking,
          icon: const Icon(Icons.play_arrow, size: 16, color: Colors.white),
          label: const Text(
            'Resume',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.white,
              letterSpacing: 0.16,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
        ),
      );
    }

    // Show start button when not tracking
    return Container(
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(0),
        border: Border.all(color: primaryColor, width: 1),
      ),
      child: TextButton.icon(
        onPressed: _startLiveTracking,
        icon: const Icon(Icons.play_arrow, size: 16, color: Colors.white),
        label: const Text(
          'Start Tracking',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.white,
            letterSpacing: 0.16,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
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
    final isLastPose = _currentPoseIndex == _availablePoses.length - 1;

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

        // Show "Back to Home" button if on last pose and paused
        if (isLastPose && _isPaused)
          Container(
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(0),
              border: Border.all(color: accentColor, width: 1),
            ),
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
              },
              icon: const Icon(Icons.home, size: 16, color: Colors.white),
              label: const Text(
                'Back to Home',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  letterSpacing: 0.16,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
          )
        // Next pose button (only show if not on last pose)
        else if (hasNextPose)
          Container(
            decoration: BoxDecoration(
              color: secondaryColor,
              borderRadius: BorderRadius.circular(0),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: TextButton.icon(
              onPressed: _goToNextPose,
              icon: const Icon(
                Icons.arrow_forward,
                size: 16,
                color: Colors.white,
              ),
              label: Text(
                'Next: ${_availablePoses[_currentPoseIndex + 1]['name']}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  letterSpacing: 0.16,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 11,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBackToHomeButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        decoration: BoxDecoration(
          color: accentColor,
          borderRadius: BorderRadius.circular(0),
          border: Border.all(color: accentColor, width: 1),
        ),
        child: TextButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.home, size: 16, color: Colors.white),
          label: const Text(
            'Back to Home',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.white,
              letterSpacing: 0.16,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRestControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Extend rest button
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: secondaryColor,
              borderRadius: BorderRadius.circular(0),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: TextButton.icon(
              onPressed: _extendRestPeriod,
              icon: const Icon(Icons.add, size: 16, color: Colors.white),
              label: const Text(
                '+5s',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  letterSpacing: 0.16,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
          ),
        ),

        // Reset pose button
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: warningColor,
              borderRadius: BorderRadius.circular(0),
              border: Border.all(color: warningColor, width: 1),
            ),
            child: TextButton.icon(
              onPressed: _resetCurrentPose,
              icon: const Icon(Icons.refresh, size: 16, color: Colors.black),
              label: const Text(
                'Reset',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.black,
                  letterSpacing: 0.16,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
            ),
          ),
        ),

        // Skip rest button
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(left: 6),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(0),
              border: Border.all(color: primaryColor, width: 1),
            ),
            child: TextButton.icon(
              onPressed: _skipRestPeriod,
              icon: const Icon(Icons.skip_next, size: 16, color: Colors.white),
              label: const Text(
                'Skip',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                  letterSpacing: 0.16,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.zero,
                ),
              ),
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

  void _resetCurrentPose() {
    // Cancel rest timer
    _restTimer?.cancel();
    _restTimer = null;

    // Stop any active tracking
    _stopLiveTracking();

    setState(() {
      _isResting = false;
      _restSeconds = 0;
      _poseSeconds = 0;
      _isPaused = false;
      _analysisResult = null;
      // Keep the same pose index - just reset the timer
    });

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.refresh, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text(
              'Pose reset - Get ready!',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: accentColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 100, left: 20, right: 20),
      ),
    );

    // Wait a moment then restart tracking for the same pose
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _startLiveTracking();
      }
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
