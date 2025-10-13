# Live Pose Tracking Feature

## Overview
The pose camera page now supports **real-time continuous pose detection** during live camera feed, replacing the previous photo-based analysis approach.

## What Changed

### Previous Behavior
- User had to press "Analyze Pose" button to capture a photo
- Single photo was analyzed and results shown in a dialog
- No continuous feedback during practice

### New Behavior
- Press **"Start Tracking"** to begin continuous pose analysis
- Automatic analysis every 2 seconds during live camera feed
- Real-time feedback overlay shows score and correctness
- Press **"Stop Tracking"** to end continuous analysis
- Gallery option still available for analyzing saved images

## Technical Implementation

### New Features Added

1. **Live Tracking State Management**
   - `_isLiveTracking`: Boolean flag to control tracking state
   - `_analysisTimer`: Timer for periodic frame capture (every 2 seconds)
   - `_lastAnalysisTime`: Prevents too-frequent API calls

2. **Key Methods**
   - `_startLiveTracking()`: Initializes Timer.periodic for continuous analysis
   - `_stopLiveTracking()`: Cancels timer and resets state
   - `_analyzeLiveFrame()`: Captures current camera frame and sends to API

3. **UI Updates**
   - Replaced "Analyze Pose" button with "Start/Stop Tracking" toggle
   - Button changes color (green → red) and icon (play → stop) when active
   - Real-time feedback overlay appears at bottom showing current score
   - "Analyzing..." indicator shows when processing frame

4. **Performance Optimizations**
   - 2-second interval between analyses to avoid overwhelming backend
   - 1.5-second minimum gap between consecutive calls
   - Analysis only runs when camera is ready and not already analyzing
   - Proper cleanup: timer cancelled in dispose(), PopScope, and back button

## How to Use

1. **Start Practice Session**
   - Navigate to any pose (Tree, Cobra, or Warrior II)
   - Camera will activate automatically
   - Position yourself so full body is visible

2. **Begin Live Tracking**
   - Press the green **"Start Tracking"** button
   - Hold your pose - analysis starts automatically
   - Watch the feedback overlay for real-time score

3. **Review Feedback**
   - ✅ **Correct Pose!** - Green overlay when pose is accurate
   - ⚠️ **Needs Adjustment** - Orange overlay with score
   - Score percentage updates every 2 seconds

4. **Stop Tracking**
   - Press the red **"Stop Tracking"** button when done
   - Feedback overlay clears
   - Ready to start again or navigate away

5. **Alternative: Gallery Analysis**
   - Press gallery icon (left button) to analyze saved images
   - Works independently of live tracking
   - Shows detailed dialog with tips

## Network Requirements

- Backend must be running at `192.168.18.6:8000`
- Phone and computer must be on same WiFi network
- API endpoint: `POST /api/poses/analyze/`
- Continuous connection needed during live tracking

## Performance Notes

- **Analysis Frequency**: Every 2 seconds
- **Minimum Gap**: 1.5 seconds between calls
- **Camera Resolution**: Medium (balanced for speed and accuracy)
- **API Timeout**: Standard HTTP timeout applies

## Troubleshooting

### Issue: Tracking stops unexpectedly
- **Solution**: Check backend is running, verify network connection

### Issue: Analysis too slow
- **Cause**: Backend processing time or network latency
- **Solution**: Timer automatically skips analysis if previous one still running

### Issue: App freezes when going back
- **Solution**: Already handled - timer cancelled in multiple cleanup locations

### Issue: Feedback not updating
- **Check**: Verify `_isLiveTracking` is true and camera is initialized
- **Check**: Backend logs for errors in pose detection

## Code Locations

- **Main File**: `/lib/pages/pose_camera_page.dart`
- **Live Tracking Methods**: Lines 78-157
- **UI Toggle Button**: Lines 499-528
- **Cleanup Logic**: Lines 326-333, 340-349, 357-365

## Future Enhancements

Possible improvements for later:
- Adjustable analysis frequency (user preference)
- Local frame buffering to smooth out network delays
- Pose landmark overlay on camera feed
- Session recording and playback
- Historical score tracking over time
- Haptic feedback on pose correction
- Audio coaching cues

## Related Files

- Backend API: `/backend/poses/views.py` - analyze_pose_image()
- Service Layer: `/lib/services/pose_service.dart` - PoseService class
- Python ML: `/Physio/src/evaluators/` - MediaPipe pose detection
- Documentation: `INTEGRATION_COMPLETE.md`, `RUNNING_GUIDE.md`
