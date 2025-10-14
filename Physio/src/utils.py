import math
from typing import Tuple, Optional, Dict
import numpy as np

# MediaPipe indexes: https://google.github.io/mediapipe/solutions/pose#pose-landmark-model-blazepose-33-points
# Convenience names:
LM = {
    "NOSE": 0,
    "LEFT_EYE": 2, "RIGHT_EYE": 5,
    "LEFT_EAR": 7, "RIGHT_EAR": 8,
    "LEFT_SHOULDER": 11, "RIGHT_SHOULDER": 12,
    "LEFT_ELBOW": 13, "RIGHT_ELBOW": 14,
    "LEFT_WRIST": 15, "RIGHT_WRIST": 16,
    "LEFT_HIP": 23, "RIGHT_HIP": 24,
    "LEFT_KNEE": 25, "RIGHT_KNEE": 26,
    "LEFT_ANKLE": 27, "RIGHT_ANKLE": 28,
}

def to_xy(landmarks, w: int, h: int, name: str) -> Optional[Tuple[float, float]]:
    idx = LM.get(name)
    if idx is None or landmarks is None:
        return None
    lm = landmarks[idx]
    if lm.visibility < 0.5:
        return None
    return (lm.x * w, lm.y * h)

def angle_3pt(a, b, c) -> Optional[float]:
    """Angle ABC in degrees (at point B)."""
    if any(p is None for p in (a, b, c)): 
        return None
    ax, ay = a; bx, by = b; cx, cy = c
    v1 = np.array([ax - bx, ay - by], dtype=float)
    v2 = np.array([cx - bx, cy - by], dtype=float)
    denom = np.linalg.norm(v1) * np.linalg.norm(v2)
    if denom < 1e-6:
        return None
    cosang = np.clip(np.dot(v1, v2) / denom, -1.0, 1.0)
    return float(np.degrees(np.arccos(cosang)))

def horiz_level(y1: float, y2: float, tol: float) -> bool:
    """Are two y coordinates roughly level (within tol px)?"""
    return abs(y1 - y2) <= tol

def rel(y_top: float, y_bottom: float, min_diff: float) -> bool:
    """Is top sufficiently above bottom by >= min_diff px (remember y grows downward)?"""
    return (y_bottom - y_top) >= min_diff

def line_angle_deg(p1, p2) -> Optional[float]:
    if p1 is None or p2 is None:
        return None
    import math
    return math.degrees(math.atan2(p2[1]-p1[1], p2[0]-p1[0]))

def safe_get_all(landmarks, w, h, names) -> Dict[str, Optional[Tuple[float,float]]]:
    return {n: to_xy(landmarks, w, h, n) for n in names}
