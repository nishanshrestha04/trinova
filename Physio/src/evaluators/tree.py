# Tree Pose (Vrikshasana) – strict above-knee + knee-forbidden band + thigh-line proximity + issue markers
from typing import Optional, Tuple, List
from ..evaluator_base import PoseEvaluator, Issue
from ..utils import to_xy, angle_3pt
import numpy as np

def _dist(p1, p2) -> Optional[float]:
    if p1 is None or p2 is None:
        return None
    dx = p1[0]-p2[0]; dy = p1[1]-p2[1]
    return (dx*dx + dy*dy) ** 0.5

def _point_to_segment_dist(p, a, b) -> Optional[float]:
    if p is None or a is None or b is None:
        return None
    p = np.array(p, float); a = np.array(a, float); b = np.array(b, float)
    ab = b - a
    denom = (ab @ ab)
    if denom <= 1e-9:
        return float(np.linalg.norm(p - a))
    t = max(0.0, min(1.0, ((p - a) @ ab) / denom))
    proj = a + t * ab
    return float(np.linalg.norm(p - proj))

class TreeEvaluator(PoseEvaluator):
    name = "Tree Pose"

    def __init__(self):
        self.stand_knee_min = 165
        self.wrist_merge_px = 140
        self.above_knee_margin_px = 20
        self.knee_forbidden_band_px = 28
        self.thigh_prox_px = 90
        self.torso_upright_tol = 90

    def _knee_angle(self, lms, w, h, side: str) -> Optional[float]:
        hip  = to_xy(lms, w, h, f"{side}_HIP")
        knee = to_xy(lms, w, h, f"{side}_KNEE")
        ank  = to_xy(lms, w, h, f"{side}_ANKLE")
        return angle_3pt(hip, knee, ank)

    def _standing_leg(self, lms, w, h) -> Optional[str]:
        la = to_xy(lms,w,h,"LEFT_ANKLE"); ra = to_xy(lms,w,h,"RIGHT_ANKLE")
        if la is None or ra is None: return None
        # lower ankle (bigger y) = standing
        return "LEFT" if la[1] > ra[1] else "RIGHT"

    def _arms_overhead(self, lms, w, h, wrist_close_px: float):
        lw = to_xy(lms,w,h,"LEFT_WRIST"); rw = to_xy(lms,w,h,"RIGHT_WRIST")
        le = to_xy(lms,w,h,"LEFT_EYE");   re = to_xy(lms,w,h,"RIGHT_EYE")
        if None in (lw, rw, le, re):
            return False, None
        eye_y = (le[1] + re[1]) / 2.0
        above = (lw[1] < eye_y) and (rw[1] < eye_y)
        d = _dist(lw, rw)
        merged = (d is not None and d <= wrist_close_px)
        return bool(above and merged), d

    def _torso_upright(self, lms, w, h, tol_px: float) -> bool:
        ls = to_xy(lms,w,h,"LEFT_SHOULDER"); rs = to_xy(lms,w,h,"RIGHT_SHOULDER")
        lh = to_xy(lms,w,h,"LEFT_HIP");      rh = to_xy(lms,w,h,"RIGHT_HIP")
        if None in (ls, rs, lh, rh): return False
        sh_mid = ((ls[0]+rs[0])/2, (ls[1]+rs[1])/2)
        hip_mid = ((lh[0]+rh[0])/2, (lh[1]+rh[1])/2)
        return abs(sh_mid[0] - hip_mid[0]) <= tol_px

    def evaluate(self, lms, frame, w, h) -> Tuple[bool, str, float, List[Issue]]:
        if lms is None:
            return False, "No person detected", 0.0, []

        issues: List[Issue] = []
        R = int(min(w, h) * 0.10)

        scale = max(h / 720.0, 0.6)
        wrist_merge_px = self.wrist_merge_px * scale
        above_knee_px  = self.above_knee_margin_px * scale
        knee_band_px   = self.knee_forbidden_band_px * scale
        thigh_prox_px  = self.thigh_prox_px * scale
        torso_upright_tol = self.torso_upright_tol * scale

        standing = self._standing_leg(lms, w, h)
        if standing is None:
            return False, "Need clear ankles to pick standing leg", 0.2, []
        lifted = "RIGHT" if standing == "LEFT" else "LEFT"

        # standing knee
        stand_knee = self._knee_angle(lms, w, h, standing)
        stand_ok = (stand_knee is not None and stand_knee >= self.stand_knee_min)
        if not stand_ok:
            sk = to_xy(lms,w,h,f"{standing}_KNEE")
            if sk: issues.append((int(sk[0]), int(sk[1]), R))

        # landmarks
        lift_ank = to_xy(lms,w,h,f"{lifted}_ANKLE")
        stand_k  = to_xy(lms,w,h,f"{standing}_KNEE")
        stand_h  = to_xy(lms,w,h,f"{standing}_HIP")
        if None in (lift_ank, stand_k, stand_h):
            return False, "Need hip/knee/ankle landmarks", 0.2, []

        # above-knee rule
        above_knee = (lift_ank[1] < (stand_k[1] - above_knee_px))
        if not above_knee:
            issues.append((int(lift_ank[0]), int(lift_ank[1]), R))
            issues.append((int(stand_k[0]), int(stand_k[1]), R))

        knee_vertical_gap = abs(lift_ank[1] - stand_k[1])
        in_knee_band = (knee_vertical_gap <= knee_band_px)
        if in_knee_band:
            issues.append((int(stand_k[0]), int(stand_k[1]), R))

        # inner-thigh proximity (to hip->knee segment)
        thigh_line_dist = _point_to_segment_dist(lift_ank, stand_h, stand_k)
        near_thigh = (thigh_line_dist is not None and thigh_line_dist <= thigh_prox_px)
        if not near_thigh:
            issues.append((int(lift_ank[0]), int(lift_ank[1]), R))

        # arms & torso
        arms_ok, _ = self._arms_overhead(lms, w, h, wrist_merge_px)
        if not arms_ok:
            lw = to_xy(lms,w,h,"LEFT_WRIST"); rw = to_xy(lms,w,h,"RIGHT_WRIST")
            for p in (lw, rw):
                if p: issues.append((int(p[0]), int(p[1]), R))

        torso_ok = self._torso_upright(lms, w, h, torso_upright_tol)
        if not torso_ok:
            ls = to_xy(lms,w,h,"LEFT_SHOULDER"); rs = to_xy(lms,w,h,"RIGHT_SHOULDER")
            if ls and rs:
                sh_mid = (int((ls[0]+rs[0])/2), int((ls[1]+rs[1])/2))
                issues.append((sh_mid[0], sh_mid[1]),)
            # also mark hip midpoint
            if stand_h:
                issues.append((int(stand_h[0]), int(stand_h[1]), R))

        touch_ok = bool(above_knee and (not in_knee_band) and near_thigh)
        is_correct = bool(stand_ok and touch_ok and arms_ok and torso_ok)

        height_msg = "above knee" if above_knee else "at/below knee"
        msg = [
            f"Standing leg: {standing} knee {('N/A' if stand_knee is None else f'{stand_knee:.0f}°')} {'OK' if stand_ok else '(straighten)'}",
            f"Foot height: {height_msg} (forbidden band ±{knee_band_px:.0f}px: {'IN' if in_knee_band else 'clear'})",
            f"Thigh proximity: {('N/A' if thigh_line_dist is None else f'{thigh_line_dist:.0f}px')} {'OK' if near_thigh else '(place on inner thigh)'}",
            f"Arms overhead: {'OK' if arms_ok else 'adjust'}",
            f"Torso upright: {'OK' if torso_ok else 'stack shoulder over hip'}",
        ]
        score = 1.0 if is_correct else 0.5
        return is_correct, " | ".join(msg), score, issues
