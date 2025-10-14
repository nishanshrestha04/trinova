# Warrior II (Virabhadrasana II): front knee ~90°, back leg straight, arms level (T).
from typing import Optional, List, Tuple
from ..evaluator_base import PoseEvaluator, Issue
from ..utils import to_xy, angle_3pt, horiz_level

class Warrior2Evaluator(PoseEvaluator):
    name = "Warrior II"

    def __init__(self):
        self.front_knee_range = (70, 110)  # degrees
        self.back_knee_min = 165           # degrees
        self.arm_level_tol = 50            # px
        self.hip_width_min = 40            # px

    def _knee_angles(self, lms, w, h):
        l = angle_3pt(to_xy(lms,w,h,"LEFT_HIP"), to_xy(lms,w,h,"LEFT_KNEE"), to_xy(lms,w,h,"LEFT_ANKLE"))
        r = angle_3pt(to_xy(lms,w,h,"RIGHT_HIP"), to_xy(lms,w,h,"RIGHT_KNEE"), to_xy(lms,w,h,"RIGHT_ANKLE"))
        return l, r

    def _arms_level(self, lms, w, h) -> bool:
        ls = to_xy(lms,w,h,"LEFT_SHOULDER"); rs = to_xy(lms,w,h,"RIGHT_SHOULDER")
        lw = to_xy(lms,w,h,"LEFT_WRIST");    rw = to_xy(lms,w,h,"RIGHT_WRIST")
        if None in (ls, rs, lw, rw): return False
        tol = self.arm_level_tol
        left_ok  = horiz_level(lw[1], ls[1], tol)
        right_ok = horiz_level(rw[1], rs[1], tol)
        return left_ok and right_ok

    def evaluate(self, lms, frame, w, h) -> Tuple[bool, str, float, List[Issue]]:
        if lms is None:
            return False, "No person detected", 0.0, []

        issues: List[Issue] = []
        R = int(min(w, h) * 0.1)

        lk, rk = self._knee_angles(lms, w, h)
        if lk is None or rk is None:
            return False, "Need both knees visible", 0.2, []

        # Determine front leg as knee closer to 90°
        if abs(lk - 90) < abs(rk - 90):
            front, back, front_side = lk, rk, "LEFT"
        else:
            front, back, front_side = rk, lk, "RIGHT"

        la = to_xy(lms,w,h,"LEFT_ANKLE"); ra = to_xy(lms,w,h,"RIGHT_ANKLE")
        if None in (la, ra): 
            return False, "Feet not visible", 0.2, []
        stance_ok = abs(la[0]-ra[0]) >= self.hip_width_min
        if not stance_ok:
            # mark ankle region
            mid_x = int((la[0]+ra[0])/2); mid_y = int((la[1]+ra[1])/2)
            issues.append((mid_x, mid_y, R))

        arms_ok = self._arms_level(lms, w, h)
        if not arms_ok:
            # mark both wrists
            lw = to_xy(lms,w,h,"LEFT_WRIST"); rw = to_xy(lms,w,h,"RIGHT_WRIST")
            for p in (lw, rw):
                if p: issues.append((int(p[0]), int(p[1]), R))

        front_ok = self.front_knee_range[0] <= front <= self.front_knee_range[1]
        if not front_ok:
            fk = to_xy(lms,w,h,f"{front_side}_KNEE")
            if fk: issues.append((int(fk[0]), int(fk[1]), R))

        back_ok  = back is not None and back >= self.back_knee_min
        if not back_ok:
            back_side = "RIGHT" if front_side == "LEFT" else "LEFT"
            bk = to_xy(lms,w,h,f"{back_side}_KNEE")
            if bk: issues.append((int(bk[0]), int(bk[1]), R))

        is_correct = bool(front_ok and back_ok and arms_ok and stance_ok)
        msg = [
            f"Front({front_side}) knee: {front:.0f}° {'OK' if front_ok else '(aim ~90°)'}",
            f"Back knee: {back:.0f}° {'OK' if back_ok else '(straighten)'}",
            f"Arms level: {'OK' if arms_ok else 'raise to shoulder height'}",
            f"Stance width: {'OK' if stance_ok else 'wider stance'}"
        ]
        score = 1.0 if is_correct else 0.5
        return is_correct, " | ".join(msg), score, issues
