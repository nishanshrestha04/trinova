# src/evaluators/downward_dog.py
# Downward-Facing Dog (Adho Mukha Svanasana) evaluator – one-side version.

from typing import List, Tuple, Optional
import math
from ..evaluator_base import PoseEvaluator, Issue
from ..utils import to_xy, angle_3pt


def _avg(vals):
    nums = [v for v in vals if v is not None]
    return sum(nums) / len(nums) if nums else None


class DownwardDogEvaluator(PoseEvaluator):
    name = "Downward Dog"

    def __init__(self):
        # Tuned for your webcam / side view.
        self.ELBOW_MIN = 150        # arms almost straight
        self.KNEE_MIN = 150         # legs almost straight
        self.HIPS_HIGH_MARGIN = 0.03   # hips a bit higher than others (fraction of image height)
        self.HAND_FOOT_LEVEL_MAX = 0.20  # hands & foot roughly same height (floor)
        self.MIN_TRIANGLE_HEIGHT = 0.18  # hip peak above line between hand & foot

    # ---------- helpers ----------

    def _elbow_angle(self, lms, w, h, side: str) -> Optional[float]:
        sh = to_xy(lms, w, h, f"{side}_SHOULDER")
        el = to_xy(lms, w, h, f"{side}_ELBOW")
        wr = to_xy(lms, w, h, f"{side}_WRIST")
        return angle_3pt(sh, el, wr)

    def _knee_angle(self, lms, w, h, side: str) -> Optional[float]:
        hp = to_xy(lms, w, h, f"{side}_HIP")
        kn = to_xy(lms, w, h, f"{side}_KNEE")
        ak = to_xy(lms, w, h, f"{side}_ANKLE")
        return angle_3pt(hp, kn, ak)

    # ---------- main ----------

    def evaluate(self, lms, frame, w, h) -> Tuple[bool, str, float, List[Issue]]:
        if lms is None:
            return False, "No person detected", 0.0, []

        # Try RIGHT side first (your screenshot shows right side clearer)
        RSH = to_xy(lms, w, h, "RIGHT_SHOULDER")
        REL = to_xy(lms, w, h, "RIGHT_ELBOW")
        RWR = to_xy(lms, w, h, "RIGHT_WRIST")
        RHP = to_xy(lms, w, h, "RIGHT_HIP")
        RKN = to_xy(lms, w, h, "RIGHT_KNEE")
        RAK = to_xy(lms, w, h, "RIGHT_ANKLE")

        LSH = to_xy(lms, w, h, "LEFT_SHOULDER")
        LEL = to_xy(lms, w, h, "LEFT_ELBOW")
        LWR = to_xy(lms, w, h, "LEFT_WRIST")
        LHP = to_xy(lms, w, h, "LEFT_HIP")
        LKN = to_xy(lms, w, h, "LEFT_KNEE")
        LAK = to_xy(lms, w, h, "LEFT_ANKLE")

        # Decide which side is usable: needs full chain shoulder → elbow → wrist → hip → knee → ankle
        def side_ok(sh, el, wr, hp, kn, ak):
            return all(p is not None for p in (sh, el, wr, hp, kn, ak))

        use_right = side_ok(RSH, REL, RWR, RHP, RKN, RAK)
        use_left  = side_ok(LSH, LEL, LWR, LHP, LKN, LAK)

        if not use_right and not use_left:
            return False, "Step back so one full arm and leg are visible from the side", 0.2, []

        if use_right:
            side = "RIGHT"
            SH, EL, WR, HP, KN, AK = RSH, REL, RWR, RHP, RKN, RAK
        else:
            side = "LEFT"
            SH, EL, WR, HP, KN, AK = LSH, LEL, LWR, LHP, LKN, LAK

        issues: List[Issue] = []
        Rcirc = max(12, int(min(w, h) * 0.05))

        # 1) Arm straight-ish
        elbow_angle = self._elbow_angle(lms, w, h, side)
        arm_ok = elbow_angle is not None and elbow_angle >= self.ELBOW_MIN
        if not arm_ok and EL:
            issues.append((int(EL[0]), int(EL[1]), Rcirc))

        # 2) Leg straight-ish
        knee_angle = self._knee_angle(lms, w, h, side)
        leg_ok = knee_angle is not None and knee_angle >= self.KNEE_MIN
        if not leg_ok and KN:
            issues.append((int(KN[0]), int(KN[1]), Rcirc))

        # 3) Hips highest on that side (triangle peak)
        hips_y = HP[1]
        sh_y = SH[1]
        hand_y = WR[1]
        foot_y = AK[1]

        margin = self.HIPS_HIGH_MARGIN * h
        hips_high_ok = (hips_y + margin < sh_y) and (hips_y + margin < hand_y) and (hips_y + margin < foot_y)
        if not hips_high_ok and HP:
            issues.append((int(HP[0]), int(HP[1]), Rcirc))

        # 4) Hand and foot approximately at same height (both on floor)
        diff_hand_foot = abs(hand_y - foot_y) / h
        hand_foot_level_ok = diff_hand_foot <= self.HAND_FOOT_LEVEL_MAX
        if not hand_foot_level_ok:
            cx = int((WR[0] + AK[0]) / 2)
            cy = int((WR[1] + AK[1]) / 2)
            issues.append((cx, cy, Rcirc))

        # 5) Triangle tall enough (hips nicely lifted)
        mid_y = (hand_y + foot_y) / 2.0
        tri_height = (mid_y - hips_y) / h  # fraction of image height
        v_shape_ok = tri_height >= self.MIN_TRIANGLE_HEIGHT
        if not v_shape_ok and HP:
            issues.append((int(HP[0]), int(HP[1]), Rcirc))

        checks = [arm_ok, leg_ok, hips_high_ok, hand_foot_level_ok, v_shape_ok]
        passed = sum(1 for c in checks if c)
        is_correct = all(checks)

        msg = (
            f"Side:{side[0]} | "
            f"Elbow:{'N/A' if elbow_angle is None else f'{elbow_angle:.0f}°'} "
            f"| Knee:{'N/A' if knee_angle is None else f'{knee_angle:.0f}°'} "
            f"| Hips highest:{'YES' if hips_high_ok else 'lift hips'} "
            f"| Hand/foot level diff:{diff_hand_foot:.2f} "
            f"| Triangle height:{tri_height:.2f} "
            f"| OK {passed}/5"
        )

        score = passed / 5.0
        return is_correct, msg, score, issues
