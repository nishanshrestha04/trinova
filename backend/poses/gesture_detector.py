"""
Hand Gesture Detection for Yoga Pose Control
Uses MediaPipe Hands for real-time gesture recognition
"""

import cv2
import mediapipe as mp
import math
import numpy as np
from typing import Optional, Tuple, List
import threading
import time

mp_hands = mp.solutions.hands


class YogaGestureRecognizer:
    """
    Hand gesture recognition for yoga pose control.
    Detects: Thumbs Up (START), Open Palm (STOP), Point (NEXT)
    """

    def __init__(self):
        self.hands = mp_hands.Hands(
            static_image_mode=False,
            max_num_hands=1,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        )
        self.current_gesture = "No Hand"
        self.current_action = "none"
        self.last_update = time.time()
        self.gesture_history = []
        self.history_size = 10

    def _get_finger_states(self, landmarks) -> List[bool]:
        """
        Determine which fingers are extended.
        Returns: [thumb, index, middle, ring, pinky]
        """
        fingers = []

        # Thumb - compare x coordinates
        thumb_extended = landmarks[4].x > landmarks[3].x
        fingers.append(thumb_extended)

        # Other fingers - compare y coordinates
        finger_tips = [8, 12, 16, 20]  # Index, Middle, Ring, Pinky
        finger_pips = [6, 10, 14, 18]  # PIP joints

        for tip, pip in zip(finger_tips, finger_pips):
            fingers.append(landmarks[tip].y < landmarks[pip].y)

        return fingers

    def _detect_thumbs_up(self, landmarks) -> bool:
        """Detect thumbs up gesture (👍)"""
        fingers = self._get_finger_states(landmarks)
        thumb_extended = fingers[0]
        other_fingers_folded = not any(fingers[1:])
        thumb_tip_above_base = landmarks[4].y < landmarks[3].y

        return thumb_extended and other_fingers_folded and thumb_tip_above_base

    def _detect_open_palm(self, landmarks) -> bool:
        """Detect open palm (✋) - all fingers extended"""
        fingers = self._get_finger_states(landmarks)
        return all(fingers)

    def _detect_point_gesture(self, landmarks) -> bool:
        """Detect pointing gesture (👉) - index finger extended"""
        fingers = self._get_finger_states(landmarks)
        index_extended = fingers[1]
        other_fingers_folded = not fingers[0] and not fingers[2] and not fingers[3] and not fingers[4]
        return index_extended and other_fingers_folded

    def detect_gesture(self, image) -> Tuple[str, str]:
        """
        Detect gesture from image.
        Returns: (gesture_name, action)
        Actions: 'resume' (start), 'pause' (stop), 'next', 'none'
        """
        # Convert BGR to RGB
        image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

        # Process image
        results = self.hands.process(image_rgb)

        if not results.multi_hand_landmarks:
            self.current_gesture = "No Hand"
            self.current_action = "none"
            return self.current_gesture, self.current_action

        # Get first hand landmarks
        landmarks = results.multi_hand_landmarks[0].landmark

        # Detect gestures
        if self._detect_thumbs_up(landmarks):
            gesture = "Thumbs Up"
            action = "resume"  # START
        elif self._detect_open_palm(landmarks):
            gesture = "Open Palm"
            action = "pause"  # STOP
        elif self._detect_point_gesture(landmarks):
            gesture = "Point"
            action = "next"  # NEXT
        else:
            gesture = "Unknown"
            action = "none"

        self.current_gesture = gesture
        self.current_action = action
        self.last_update = time.time()

        return gesture, action

    def get_status(self):
        """Get current gesture status"""
        return {
            "gesture": self.current_gesture,
            "action": self.current_action,
            "timestamp": self.last_update
        }

    def cleanup(self):
        """Cleanup resources"""
        if self.hands:
            self.hands.close()


# Global gesture recognizer instance
_gesture_recognizer = None
_camera = None
_camera_thread = None
_camera_running = False


def get_gesture_recognizer():
    """Get or create gesture recognizer instance"""
    global _gesture_recognizer
    if _gesture_recognizer is None:
        _gesture_recognizer = YogaGestureRecognizer()
    return _gesture_recognizer


def start_camera_gesture_detection():
    """Start camera for continuous gesture detection"""
    global _camera, _camera_thread, _camera_running

    if _camera_running:
        return

    def camera_loop():
        global _camera, _camera_running
        _camera = cv2.VideoCapture(0)
        recognizer = get_gesture_recognizer()

        while _camera_running:
            ret, frame = _camera.read()
            if ret:
                recognizer.detect_gesture(frame)
            time.sleep(0.1)  # 10 FPS

        _camera.release()

    _camera_running = True
    _camera_thread = threading.Thread(target=camera_loop, daemon=True)
    _camera_thread.start()


def stop_camera_gesture_detection():
    """Stop camera gesture detection"""
    global _camera_running
    _camera_running = False
