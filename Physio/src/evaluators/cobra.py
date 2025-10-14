# Cobra (Bhujangasana): chest lifted, shoulders above hips; elbows fairly extended.
from typing import Optional, List, Tuple
from ..evaluator_base import PoseEvaluator, Issue
from ..utils import to_xy, angle_3pt

class CobraEvaluator(PoseEvaluator):
    name = "Cobra"

    def __init__(self):
        # Tunables:
        self.min_shoulder_hip_vertical_gap = 60   # px
        self.min_elbow_extension = 150            # degrees
        self.hip_knee_floor_gap_max = 100         # px

    def _elbow_angle(self, lms, w, h, side: str) -> Optional[float]:
        sh = to_xy(lms, w, h, f"{side}_SHOULDER")
        el = to_xy(lms, w, h, f"{side}_ELBOW")
        wr = to_xy(lms, w, h, f"{side}_WRIST")
        return angle_3pt(sh, el, wr)

    def evaluate(self, lms, frame, w, h) -> Tuple[bool, str, float, List[Issue]]:
        if lms is None:
            return False, "No person detected", 0.0, []

        issues: List[Issue] = []
        R = int(min(w, h) * 0.10)  # circle radius

        ls = to_xy(lms, w, h, "LEFT_SHOULDER")
        rs = to_xy(lms, w, h, "RIGHT_SHOULDER")
        lh = to_xy(lms, w, h, "LEFT_HIP")
        rh = to_xy(lms, w, h, "RIGHT_HIP")
        lk = to_xy(lms, w, h, "LEFT_KNEE")
        rk = to_xy(lms, w, h, "RIGHT_KNEE")

        if None in (ls, rs, lh, rh):
            return False, "Need clear side view of torso (shoulders/hips)", 0.2, []

        sh_y = (ls[1] + rs[1]) / 2
        hip_y = (lh[1] + rh[1]) / 2
        vertical_ok = (hip_y - sh_y) >= self.min_shoulder_hip_vertical_gap
        if not vertical_ok:
            # mark torso/hip area
            issues.append((int((lh[0]+rh[0])/2), int(hip_y), R))

        le = self._elbow_angle(lms, w, h, "LEFT")
        re = self._elbow_angle(lms, w, h, "RIGHT")
        elbow_ok = False
        elbow_val = None
        for side, ang in (("LEFT", le), ("RIGHT", re)):
            if ang is not None:
                elbow_val = ang if elbow_val is None else max(elbow_val, ang)
                if ang >= self.min_elbow_extension:
                    elbow_ok = True
                else:
                    # mark bent elbow
                    el = to_xy(lms, w, h, f"{side}_ELBOW")
                    if el: issues.append((int(el[0]), int(el[1]), R))

        legs_ok = True
        if lk and rk:
            knee_y = (lk[1] + rk[1]) / 2
            legs_ok = (knee_y - hip_y) <= self.hip_knee_floor_gap_max
            if not legs_ok:
                # mark legs area (knees)
                issues.append((int((lk[0]+rk[0])/2), int(knee_y), R))

        is_correct = bool(vertical_ok and elbow_ok and legs_ok)
        msg = [
            f"Shoulder↑ vs Hip: {'OK' if vertical_ok else 'LOW'}",
            f"Elbow ext: {('N/A' if elbow_val is None else f'{elbow_val:.0f}°')} ({'OK' if elbow_ok else 'straighten at least one arm'})",
            f"Legs grounded: {'OK' if legs_ok else 'unclear'}"
        ]
        score = 1.0 if is_correct else 0.4
        return is_correct, " | ".join(msg), score, issues
