import cv2
import mediapipe as mp
from typing import List, Tuple
from .evaluator_base import PoseEvaluator

Issue = Tuple[int, int, int]

class PoseRunner:
    def __init__(self, evaluator: PoseEvaluator, cam_index=0):
        self.evaluator = evaluator
        self.cam_index = cam_index
        self.mp_pose = mp.solutions.pose
        self.pose = self.mp_pose.Pose(
            static_image_mode=False,
            model_complexity=1,
            enable_segmentation=False,
            min_detection_confidence=0.6,
            min_tracking_confidence=0.6,
        )
        self.drawer = mp.solutions.drawing_utils
        self.style = mp.solutions.drawing_styles

    def run(self):
        cap = cv2.VideoCapture(self.cam_index)
        if not cap.isOpened():
            print("Cannot open camera")
            return

        name = self.evaluator.name
        while True:
            ok, frame = cap.read()
            if not ok: break
            frame = cv2.flip(frame, 1)
            h, w = frame.shape[:2]

            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            res = self.pose.process(rgb)
            lms = res.pose_landmarks.landmark if res.pose_landmarks else None

            # Evaluate
            is_correct, message, score, issues = self.evaluator.evaluate(lms, frame, w, h)

            # Draw skeleton
            if res.pose_landmarks:
                self.drawer.draw_landmarks(
                    frame,
                    res.pose_landmarks,
                    self.mp_pose.POSE_CONNECTIONS,
                    landmark_drawing_spec=self.style.get_default_pose_landmarks_style()
                )

            # Header/status
            status_color = (0,200,0) if is_correct else (0,0,255)
            cv2.rectangle(frame, (0,0),(w,60), (30,30,30), -1)
            cv2.putText(frame, f"{name} | {'Correct' if is_correct else 'Adjust'}",
                        (10,40), cv2.FONT_HERSHEY_SIMPLEX, 1.0, status_color, 2)

            # Message
            self._wrap_text(frame, message, x=10, y=80, max_w=w-20, line_h=24)

            # Draw attention circles
            if issues:
                self._draw_issues(frame, issues)

            cv2.imshow("Yoga Pose Checker", frame)
            key = cv2.waitKey(1) & 0xFF
            if key == ord('q'):
                break

        cap.release()
        cv2.destroyAllWindows()

    def _wrap_text(self, frame, text, x, y, max_w, line_h):
        words = text.split()
        line = ""
        xx, yy = x, y
        for w in words:
            test = f"{line} {w}".strip()
            (tw, th), _ = cv2.getTextSize(test, cv2.FONT_HERSHEY_SIMPLEX, 0.6, 1)
            if tw > max_w and line:
                cv2.putText(frame, line, (xx, yy), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255,255,255), 1)
                line = w
                yy += line_h
            else:
                line = test
        if line:
            cv2.putText(frame, line, (xx, yy), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (255,255,255), 1)

    def _draw_issues(self, frame, issues):
        # Draw red outline circles (no fill), thick border like your reference
        for (cx, cy, r) in issues:
            cv2.circle(frame, (int(cx), int(cy)), int(r), (0, 0, 255), thickness=10, lineType=cv2.LINE_AA)
