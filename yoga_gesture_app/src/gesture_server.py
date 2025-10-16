"""
Gesture Recognition Server for Yoga App Integration
Provides HTTP API to control live tracking with hand gestures
"""

import cv2
import mediapipe as mp
import math
import os
import sys
import json
from typing import Dict, Optional, Tuple, List
from http.server import HTTPServer, BaseHTTPRequestHandler
from threading import Thread
import time

# Suppress TensorFlow warnings
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '2'
os.environ['TF_ENABLE_ONEDNN_OPTS'] = '0'

# Suppress MediaPipe warnings
import logging
logging.getLogger('mediapipe').setLevel(logging.ERROR)

mp_hands = mp.solutions.hands
mp_drawing = mp.solutions.drawing_utils


class GestureState:
    """Shared state for gesture detection"""
    def __init__(self):
        self.current_gesture = "No Hand"
        self.current_action = "none"
        self.is_tracking = False
        self.last_update = time.time()
    
    def to_dict(self):
        return {
            "gesture": self.current_gesture,
            "action": self.current_action,
            "is_tracking": self.is_tracking,
            "timestamp": self.last_update
        }


# Global gesture state
gesture_state = GestureState()


class GestureHTTPHandler(BaseHTTPRequestHandler):
    """HTTP handler for gesture API"""
    
    def do_GET(self):
        """Handle GET requests"""
        if self.path == '/gesture/status':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            response = gesture_state.to_dict()
            self.wfile.write(json.dumps(response).encode())
        else:
            self.send_response(404)
            self.end_headers()
    
    def log_message(self, format, *args):
        """Suppress default logging"""
        pass


class YogaGestureRecognizer:
    """
    Advanced gesture recognition system for yoga pose control using MediaPipe Hands.
    Supports rule-based gesture detection with 21 hand landmarks.
    """
    
    def __init__(self):
        self.gesture_actions = {
            "Open Palm": "pause",      # ✋ = Pause
            "Thumbs Up": "resume",     # 👍 = Resume  
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
        thumb_extended = landmarks[4].x > landmarks[3].x
        fingers.append(thumb_extended)
        
        # Other four fingers - compare y coordinates (up/down position)
        finger_tips = [8, 12, 16, 20]  # Index, Middle, Ring, Pinky tips
        finger_pips = [6, 10, 14, 18]  # Corresponding PIP joints
        
        for tip, pip in zip(finger_tips, finger_pips):
            fingers.append(landmarks[tip].y < landmarks[pip].y)
            
        return fingers
    
    def _calculate_distance(self, point1, point2) -> float:
        """Calculate Euclidean distance between two landmark points."""
        return math.sqrt((point1.x - point2.x)**2 + (point1.y - point2.y)**2)

    def _detect_thumbs_up(self, landmarks) -> bool:
        """Detect thumbs up gesture (👍) - thumb extended, other fingers folded."""
        fingers = self._get_finger_states(landmarks)
        thumb_extended = fingers[0]
        other_fingers_folded = not any(fingers[1:])
        thumb_tip_above_base = landmarks[4].y < landmarks[3].y

        return thumb_extended and other_fingers_folded and thumb_tip_above_base

    def _detect_point_gesture(self, landmarks) -> bool:
        """Detect pointing gesture (👉) - index finger extended, others folded."""
        fingers = self._get_finger_states(landmarks)
        index_flexibility = landmarks[8].y < landmarks[7].y + 0.07
        index_tip_above_base = landmarks[8].y < landmarks[5].y + 0.05
        
        return (not fingers[0] and index_flexibility and index_tip_above_base and 
                not fingers[2] and not fingers[3] and not fingers[4])
    
    def _detect_open_palm(self, landmarks) -> bool:
        """Detect open palm (✋) - all fingers extended."""
        fingers = self._get_finger_states(landmarks)
        return all(fingers)
    
    def _detect_fist(self, landmarks) -> bool:
        """Detect fist (✊) - all fingers folded."""
        fingers = self._get_finger_states(landmarks)
        return not any(fingers)
    
    def _update_gesture_history(self, gesture: str):
        """Update gesture history for sequence detection."""
        self.gesture_history.append(gesture)
        if len(self.gesture_history) > self.history_size:
            self.gesture_history.pop(0)
    
    def _detect_exit_sequence(self) -> bool:
        """Detect exit sequence: Open Palm followed by Fist within recent history."""
        if len(self.gesture_history) < 2:
            return False
            
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
        return gesture, action


class YogaGestureServerApp:
    """
    Main application class with integrated HTTP server for remote control.
    """
    
    def __init__(self, port=8080):
        self.gesture_recognizer = YogaGestureRecognizer()
        self.port = port
        self.http_server = None
        self.server_thread = None
        
    def start_http_server(self):
        """Start HTTP server in a separate thread"""
        self.http_server = HTTPServer(('localhost', self.port), GestureHTTPHandler)
        self.server_thread = Thread(target=self.http_server.serve_forever)
        self.server_thread.daemon = True
        self.server_thread.start()
        print(f"🌐 Gesture API Server started on http://localhost:{self.port}")
        print(f"   API Endpoint: http://localhost:{self.port}/gesture/status")
        
    def process_gesture_action(self, action: str, gesture: str):
        """Process detected gesture action and update global state."""
        global gesture_state
        
        if action == "pause":
            print(f"🔸 PAUSE TRACKING - {gesture} detected")
            gesture_state.is_tracking = False
            
        elif action == "resume":
            print(f"▶️ RESUME TRACKING - {gesture} detected")
            gesture_state.is_tracking = True
            
        elif action == "next":
            print(f"⏭️ NEXT EXERCISE - {gesture} detected")
            
        elif action == "exit":
            print(f"❌ EXIT - {gesture} detected")
            return False
            
        gesture_state.current_gesture = gesture
        gesture_state.current_action = action
        gesture_state.last_update = time.time()
        return True
    
    def draw_ui_overlay(self, frame, gesture: str, action: str):
        """Draw user interface overlay with gesture info."""
        height, width = frame.shape[:2]
        
        # Background for text
        overlay = frame.copy()
        cv2.rectangle(overlay, (10, 10), (width - 10, 180), (0, 0, 0), -1)
        cv2.addWeighted(overlay, 0.7, frame, 0.3, 0, frame)
        
        # Gesture detection info
        cv2.putText(frame, f"Gesture: {gesture}", (20, 40),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 255, 0), 2)
        
        # Tracking status
        status = "TRACKING" if gesture_state.is_tracking else "PAUSED"
        status_color = (0, 255, 0) if gesture_state.is_tracking else (0, 165, 255)
        cv2.putText(frame, f"Status: {status}", (20, 80),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.7, status_color, 2)
        
        # Server status
        cv2.putText(frame, f"Server: http://localhost:{self.port}", (20, 120),
                   cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
        
        # Instructions
        instructions = [
            "Live Tracking Controls:",
            "✋ Open Palm = PAUSE",
            "👍 Thumbs Up = RESUME/PLAY", 
            "👉 Point = Next Exercise",
            "✋ → ✊ = Exit"
        ]
        
        start_y = height - 150
        for i, instruction in enumerate(instructions):
            color = (255, 255, 255) if i == 0 else (200, 200, 200)
            cv2.putText(frame, instruction, (20, start_y + i * 25),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 1)
    
    def run(self):
        """Main application loop"""
        print("🧘 Yoga Gesture Recognition Server Starting...")
        
        # Start HTTP server
        self.start_http_server()
        
        # Initialize camera
        cap = cv2.VideoCapture(0)
        if not cap.isOpened():
            print("❌ Failed to open camera")
            return
        
        # Configure MediaPipe Hands
        with mp_hands.Hands(
            max_num_hands=1,
            min_detection_confidence=0.7,
            min_tracking_confidence=0.5
        ) as hands:
            
            print("🧘 Gesture Recognition Started!")
            print("👋 Show gestures to control live tracking")
            print("⌨️  Press ESC to exit")
            print("-" * 50)
            
            while cap.isOpened():
                ret, frame = cap.read()
                
                if not ret:
                    print("⚠️ Frame read failed")
                    continue
                
                # Flip frame horizontally for mirror effect
                frame = cv2.flip(frame, 1)
                
                # Convert BGR to RGB for MediaPipe
                rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
                
                try:
                    results = hands.process(rgb_frame)
                except Exception as e:
                    print(f"⚠️ MediaPipe error: {e}")
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
                                print("👋 Exiting...")
                                break
                                
                        except Exception as e:
                            print(f"⚠️ Gesture detection error: {e}")
                
                # Draw UI overlay
                self.draw_ui_overlay(frame, gesture, action)
                
                # Display frame
                cv2.imshow('Yoga Gesture Control', frame)
                
                # Check for ESC key
                if cv2.waitKey(1) & 0xFF == 27:
                    print("👋 ESC pressed, exiting...")
                    break
        
        # Cleanup
        cap.release()
        cv2.destroyAllWindows()
        if self.http_server:
            self.http_server.shutdown()


def main():
    """Main entry point"""
    port = 8080
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            print(f"Invalid port number, using default: {port}")
    
    app = YogaGestureServerApp(port=port)
    app.run()


if __name__ == "__main__":
    main()
