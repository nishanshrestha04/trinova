import cv2
import mediapipe as mp
import math
import os
import sys
from typing import Dict, Optional, Tuple, List

# Suppress TensorFlow warnings
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'  # Suppress TensorFlow logging
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'  # Disable oneDNN optimizations

# Suppress MediaPipe warnings
import logging
logging.getLogger('mediapipe').setLevel(logging.ERROR)

mp_hands = mp.solutions.hands
mp_drawing = mp.solutions.drawing_utils

class YogaGestureRecognizer:
    """
    Advanced gesture recognition system for yoga pose control using MediaPipe Hands.
    Supports rule-based gesture detection with 21 hand landmarks.
    """
    
    def __init__(self):
        self.gesture_actions = {
            "Open Palm": "pause",      # ✋ = Pause
            "Thumbs Up": "resume",    # 👍 = Resume  
            "Point": "next",           # 👉 = Next Exercise
            "Fist": "fist_detected",   # Part of exit sequence
            "Exit Sequence": "exit"    # 🖐✊ = Exit workout mode
        }
        
        # For exit sequence detection (Open Palm followed by Fist)
        self.gesture_history = []
        self.history_size = 10
        
    def _get_finger_states(self, landmarks) -> List[bool]:
        """
        Determine which fingers are extended based on landmark positions.
        Returns list of bools: [thumb, index, middle, ring, pinky]
        """
        fingers = []
        
        # Thumb - compare x coordinates (left/right position)
        # For right hand: thumb extended if tip is to the right of IP joint
        # For left hand: thumb extended if tip is to the left of IP joint
        thumb_extended = landmarks[4].x > landmarks[3].x
        fingers.append(thumb_extended)
        
        # Other four fingers - compare y coordinates (up/down position)
        # Finger extended if tip is above PIP joint
        finger_tips = [8, 12, 16, 20]  # Index, Middle, Ring, Pinky tips
        finger_pips = [6, 10, 14, 18]  # Corresponding PIP joints
        
        for tip, pip in zip(finger_tips, finger_pips):
            fingers.append(landmarks[tip].y < landmarks[pip].y)
            
        return fingers
    
    def _calculate_distance(self, point1, point2) -> float:
        """Calculate Euclidean distance between two landmark points."""
        return math.sqrt((point1.x - point2.x)**2 + (point1.y - point2.y)**2)
    
    def _log_debug(self, message: str):
        """Utility function to log debug messages."""
        print(f"[DEBUG] {message}")

    def _detect_thumbs_up(self, landmarks) -> bool:
        """
        Detect thumbs up gesture (👍) - thumb extended, other fingers folded.
        """
        fingers = self._get_finger_states(landmarks)
        thumb_extended = fingers[0]  # Thumb is extended
        other_fingers_folded = not fingers[1] and not fingers[2] and not fingers[3] and not fingers[4]
        thumb_tip_above_base = landmarks[4].y < landmarks[3].y  # Ensure thumb tip is above its base

        self._log_debug(f"Thumbs Up Detection: thumb_extended={thumb_extended}, other_fingers_folded={other_fingers_folded}, thumb_tip_above_base={thumb_tip_above_base}")
        return thumb_extended and other_fingers_folded and thumb_tip_above_base

    def _detect_point_gesture(self, landmarks) -> bool:
        """
        Detect pointing gesture (👉) - index finger extended, others folded.
        """
        # Allow slight bending of the index finger for better detection
        fingers = self._get_finger_states(landmarks)
        index_flexibility = landmarks[8].y < landmarks[7].y + 0.07  # Increased flexibility
        index_tip_above_base = landmarks[8].y < landmarks[5].y + 0.05  # Allow more deviation
        
        self._log_debug(f"Point Gesture Detection: fingers={fingers}, index_flexibility={index_flexibility}, index_tip_above_base={index_tip_above_base}")
        return (not fingers[0] and index_flexibility and index_tip_above_base and 
                not fingers[2] and not fingers[3] and not fingers[4])
    
    def _detect_open_palm(self, landmarks) -> bool:
        """
        Detect open palm (✋) - all fingers extended.
        """
        fingers = self._get_finger_states(landmarks)

        # Open palm: all fingers extended
        self._log_debug(f"Open Palm Detection: fingers={fingers}")
        return all(fingers)
    
    def _detect_fist(self, landmarks) -> bool:
        """
        Detect fist (✊) - all fingers folded.
        """
        fingers = self._get_finger_states(landmarks)
        
        # Fist: all fingers folded
        self._log_debug(f"Fist Detection: fingers={fingers}")
        return not any(fingers)
    
    def _update_gesture_history(self, gesture: str):
        """Update gesture history for sequence detection."""
        self.gesture_history.append(gesture)
        if len(self.gesture_history) > self.history_size:
            self.gesture_history.pop(0)
    
    def _detect_exit_sequence(self) -> bool:
        """
        Detect exit sequence: Open Palm followed by Fist within recent history.
        """
        if len(self.gesture_history) < 2:
            return False
            
        # Look for Open Palm followed by Fist in recent history
        for i in range(len(self.gesture_history) - 1):
            if (self.gesture_history[i] == "Open Palm" and 
                self.gesture_history[i + 1] == "Fist"):
                return True
        return False
    
    def detect_gesture(self, landmarks) -> Tuple[str, str]:
        """
        Main gesture detection function.
        Returns tuple of (gesture_name, action).
        """
        if not landmarks:
            return "No Hand", "none"
        
        # Detect individual gestures
        if self._detect_thumbs_up(landmarks):
            gesture = "Thumbs Up"
        elif self._detect_point_gesture(landmarks):
            gesture = "Point"
        elif self._detect_open_palm(landmarks):
            gesture = "Open Palm"
        elif self._detect_fist(landmarks):
            gesture = "Fist"
        else:
            gesture = "Unknown"
        
        # Update history
        self._update_gesture_history(gesture)
        
        # Check for exit sequence
        if self._detect_exit_sequence():
            return "Exit Sequence", self.gesture_actions["Exit Sequence"]
        
        # Return gesture and corresponding action
        action = self.gesture_actions.get(gesture, "none")
        self._log_debug(f"Detecting gesture with landmarks: {landmarks}")
        self._log_debug(f"Detected gesture: {gesture}, action: {action}")
        return gesture, action


class YogaGestureApp:
    """
    Main application class for yoga gesture recognition.
    Integrates camera input with gesture recognition for yoga pose control.
    """
    
    def __init__(self):
        self.gesture_recognizer = YogaGestureRecognizer()
        self.current_action = "none"
        self.action_feedback = ""
        
    def process_gesture_action(self, action: str, gesture: str):
        """Process detected gesture action and provide user feedback."""
        if action == "pause":
            self.action_feedback = "🔸 YOGA PAUSED 🔸"
            print(f"Action: Pause yoga session - {gesture} detected")
            
        elif action == "resume":
            self.action_feedback = "▶️ YOGA RESUMED ▶️"
            print(f"Action: Resume yoga session - {gesture} detected")
            
        elif action == "next":
            self.action_feedback = "⏭️ NEXT EXERCISE ⏭️"
            print(f"Action: Next exercise - {gesture} detected")
            
        elif action == "exit":
            self.action_feedback = "❌ EXITING YOGA MODE ❌"
            print(f"Action: Exit yoga mode - {gesture} detected")
            return False  # Signal to exit
            
        elif action == "fist_detected":
            self.action_feedback = "✊ Fist detected (part of exit sequence)"
            
        else:
            self.action_feedback = ""
            
        self.current_action = action
        return True  # Continue running
    
    def draw_ui_overlay(self, frame, gesture: str, action: str):
        """Draw user interface overlay with gesture info and instructions."""
        height, width = frame.shape[:2]
        
        # Background for text
        overlay = frame.copy()
        cv2.rectangle(overlay, (10, 10), (width - 10, 150), (0, 0, 0), -1)
        cv2.addWeighted(overlay, 0.7, frame, 0.3, 0, frame)
        
        # Gesture detection info
        cv2.putText(frame, f"Gesture: {gesture}", (20, 40),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
        
        # Action feedback
        if self.action_feedback:
            cv2.putText(frame, self.action_feedback, (20, 80),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 255), 2)
        
        # Instructions
        instructions = [
            "Yoga Gesture Controls:",
            "✋ Open Palm = Pause",
            "👍 Thumbs Up = Resume", 
            "👉 Point = Next Exercise",
            "✋ → ✊ = Exit Mode"
        ]
        
        start_y = height - 150
        for i, instruction in enumerate(instructions):
            color = (255, 255, 255) if i == 0 else (200, 200, 200)
            cv2.putText(frame, instruction, (20, start_y + i * 25),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 1)
    
    def run(self):
        """Main application loop with comprehensive camera fix."""
        print("🧘 Yoga Gesture Recognition Starting...")
        print("🔍 Attempting to fix camera access issues...")
        
        # Try different camera backends and configurations
        cap = None
        camera_found = False
        
        # Method 1: Try DirectShow backend with aggressive settings
        print("   📷 Method 1: Trying DirectShow backend with force settings...")
        for camera_id in range(3):
            try:
                cap = cv2.VideoCapture(camera_id, cv2.CAP_DSHOW)
                
                # Force camera to wake up
                cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
                cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
                cap.set(cv2.CAP_PROP_FPS, 30)
                cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
                cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc('M', 'J', 'P', 'G'))
                
                if cap.isOpened():
                    # Aggressive frame reading - flush buffer multiple times
                    for flush_attempt in range(10):
                        ret, frame = cap.read()
                        if ret and frame is not None and frame.size > 0:
                            print(f"✅ Camera {camera_id} working with DirectShow! (attempt {flush_attempt + 1})")
                            camera_found = True
                            break
                        import time
                        time.sleep(0.1)
                    
                    if camera_found:
                        break
                    else:
                        print(f"   ⚠️  Camera {camera_id} opened but no valid frames after 10 attempts")
                        cap.release()
                        
            except Exception as e:
                print(f"   ❌ Camera {camera_id} DirectShow failed: {e}")
                if cap:
                    cap.release()
        
        # Method 2: Try Media Foundation with camera reset
        if not camera_found:
            print("   📷 Method 2: Trying Media Foundation with camera reset...")
            for camera_id in range(3):
                try:
                    # First, try to reset any existing camera connections
                    dummy_cap = cv2.VideoCapture(camera_id)
                    dummy_cap.release()
                    
                    import time
                    time.sleep(0.5)  # Wait for camera to reset
                    
                    cap = cv2.VideoCapture(camera_id, cv2.CAP_MSMF)
                    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 320)  # Lower resolution
                    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 240)
                    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
                    cap.set(cv2.CAP_PROP_FPS, 15)  # Lower FPS
                    
                    if cap.isOpened():
                        # Wait longer for MSMF initialization
                        time.sleep(2)
                        
                        # Try multiple read attempts
                        for read_attempt in range(15):
                            ret, frame = cap.read()
                            if ret and frame is not None and frame.size > 0:
                                print(f"✅ Camera {camera_id} working with Media Foundation! (attempt {read_attempt + 1})")
                                camera_found = True
                                break
                            time.sleep(0.2)
                        
                        if camera_found:
                            break
                        else:
                            print(f"   ⚠️  Camera {camera_id} MSMF opened but no valid frames after 15 attempts")
                            cap.release()
                            
                except Exception as e:
                    print(f"   ❌ Camera {camera_id} MSMF failed: {e}")
                    if cap:
                        cap.release()
        
        # Method 3: Try default backend with different settings
        if not camera_found:
            print("   � Method 3: Trying default backend with optimized settings...")
            for camera_id in range(3):
                try:
                    cap = cv2.VideoCapture(camera_id)
                    
                    # Force specific codec and settings
                    cap.set(cv2.CAP_PROP_FOURCC, cv2.VideoWriter_fourcc('M', 'J', 'P', 'G'))
                    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 320)  # Lower resolution
                    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 240)
                    cap.set(cv2.CAP_PROP_FPS, 15)  # Lower FPS
                    cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
                    
                    if cap.isOpened():
                        # Multiple read attempts
                        for attempt in range(5):
                            ret, frame = cap.read()
                            if ret and frame is not None:
                                print(f"✅ Camera {camera_id} working with default backend!")
                                camera_found = True
                                break
                            import time
                            time.sleep(0.2)
                        
                        if camera_found:
                            break
                        else:
                            cap.release()
                            
                except Exception as e:
                    print(f"   ❌ Camera {camera_id} failed: {e}")
                    if cap:
                        cap.release()
        
        # Method 4: Last resort - try with minimal settings and force enable
        if not camera_found:
            print("   📷 Method 4: Last resort - minimal settings with force enable...")
            for camera_id in range(3):
                try:
                    # Multiple connection attempts
                    for connection_attempt in range(3):
                        cap = cv2.VideoCapture(camera_id)
                        
                        if cap.isOpened():
                            # Minimal settings
                            cap.set(cv2.CAP_PROP_FRAME_WIDTH, 160)
                            cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 120)
                            cap.set(cv2.CAP_PROP_FPS, 10)
                            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
                            
                            # Aggressive read attempts
                            import time
                            time.sleep(1)
                            
                            for read_attempt in range(20):
                                ret, frame = cap.read()
                                if ret and frame is not None and frame.size > 0:
                                    print(f"✅ Camera {camera_id} working with minimal settings! (connection {connection_attempt + 1}, read {read_attempt + 1})")
                                    camera_found = True
                                    break
                                time.sleep(0.1)
                            
                            if camera_found:
                                break
                            else:
                                cap.release()
                                time.sleep(0.5)
                        
                        if camera_found:
                            break
                        
                except Exception as e:
                    print(f"   ❌ Camera {camera_id} minimal settings failed: {e}")
                    if cap:
                        cap.release()
                
                if camera_found:
                    break
        
        if not camera_found:
            print("\n❌ ALL CAMERA METHODS FAILED!")
            print("\n🔧 URGENT: Camera Hardware/Driver Issue Detected")
            print("This is likely a Windows driver or hardware problem.")
            print("\n✅ IMMEDIATE SOLUTIONS:")
            print("1. Open Windows Camera app RIGHT NOW to test")
            print("2. If Windows Camera fails, restart your computer")
            print("3. Update camera drivers in Device Manager")
            print("4. Check if camera LED is on (hardware working)")
            print("5. Try a different USB port (if USB camera)")
            print("\n� If Windows Camera app works but this doesn't:")
            print("   - Run this as Administrator")
            print("   - Disable antivirus camera protection temporarily")
            return
            
        # Configure MediaPipe Hands with optimized settings
        with mp_hands.Hands(
            max_num_hands=1,
            min_detection_confidence=0.7,  # Increased threshold for better detection
            min_tracking_confidence=0.5    # Increased threshold for better tracking
        ) as hands:
            
            print("🧘 Yoga Gesture Recognition Started Successfully!")
            print("📷 Camera connected and optimized")
            print("👋 Show your hand to the camera to control yoga session")
            print("🔄 Available gestures:")
            print("   ✋ Open Palm = Pause")
            print("   👍 Thumbs Up = Resume")
            print("   👉 Point = Next Exercise") 
            print("   ✋→✊ Open Palm then Fist = Exit")
            print("⌨️  Press ESC key to exit anytime")
            print("-" * 50)
            
            frame_count = 0
            failed_reads = 0
            max_failed_reads = 10
            
            while cap.isOpened():
                ret, frame = cap.read()
                
                if not ret:
                    failed_reads += 1
                    print(f"⚠️  Frame read failed ({failed_reads}/{max_failed_reads})")
                    
                    if failed_reads >= max_failed_reads:
                        print("❌ Too many failed reads - camera connection lost")
                        break
                    
                    # Try to flush the buffer and continue
                    for _ in range(3):
                        cap.read()
                    continue
                else:
                    failed_reads = 0  # Reset counter on successful read
                
                frame_count += 1
                
                # Flip frame horizontally for mirror effect
                frame = cv2.flip(frame, 1)
                
                # Convert BGR to RGB for MediaPipe
                rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                
                try:
                    results = hands.process(rgb_frame)
                except Exception as e:
                    print(f"⚠️  MediaPipe processing error: {e}")
                    continue
                
                gesture = "No Hand"
                action = "none"
                
                # Process hand landmarks
                if results.multi_hand_landmarks:
                    for hand_landmarks in results.multi_hand_landmarks:
                        # Draw hand landmarks
                        mp_drawing.draw_landmarks(
                            frame, hand_landmarks, mp_hands.HAND_CONNECTIONS,
                            mp_drawing.DrawingSpec(color=(0, 0, 255), thickness=2, circle_radius=2),
                            mp_drawing.DrawingSpec(color=(0, 255, 0), thickness=2)
                        )
                        
                        try:
                            # Detect gesture
                            gesture, action = self.gesture_recognizer.detect_gesture(
                                hand_landmarks.landmark
                            )
                            
                            # Process the action
                            continue_running = self.process_gesture_action(action, gesture)
                            if not continue_running:
                                print("👋 Exiting due to exit gesture sequence...")
                                break
                                
                        except Exception as e:
                            print(f"⚠️  Gesture detection error: {e}")
                            gesture = "Error"
                            action = "none"
                
                # Draw UI overlay
                try:
                    self.draw_ui_overlay(frame, gesture, action)
                except Exception as e:
                    print(f"⚠️  UI overlay error: {e}")
                
                # Display frame
                try:
                    cv2.imshow("Yoga Gesture Recognition", frame)
                except Exception as e:
                    print(f"⚠️  Display error: {e}")
                    break
                
                # Check for exit conditions
                key = cv2.waitKey(1) & 0xFF
                if key == 27:  # ESC key
                    print("⌨️  ESC key pressed - exiting...")
                    break
                elif action == "exit":
                    print("🚪 Exit gesture detected - closing application...")
                    break
                    
                # Show status every 100 frames
                if frame_count % 100 == 0:
                    print(f"📊 Processed {frame_count} frames successfully (Current: {gesture})")
        
        # Cleanup
        try:
            cap.release()
            cv2.destroyAllWindows()
        except Exception as e:
            print(f"⚠️  Cleanup error: {e}")
            
        print("🧘 Yoga Gesture Recognition Ended Successfully")


def run_gesture_app():
    """Legacy function for backwards compatibility."""
    app = YogaGestureApp()
    app.run()


if __name__ == "__main__":
    app = YogaGestureApp()
    app.run()
