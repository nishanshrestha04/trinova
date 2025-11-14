# src/evaluators/chair.py
# Chair Pose (Utkatasana) evaluator – stricter & aligned with real chair pose.

from typing import List, Tuple, Optional
import math
from ..evaluator_base import PoseEvaluator, Issue
from ..utils import to_xy, angle_3pt


def _angle_with_vertical(p1, p2) -> Optional[float]:
    """
    Angle (deg) between vector p1->p2 and vertical up.
    0° = vertical, 90° = horizontal.
    """
    if p1 is None or p2 is None:
        return None
    vx = p2[0] - p1[0]
    vy = p2[1] - p1[1]  # image y grows downward
    mag = math.hypot(vx, vy)
    if mag <= 1e-6:
        return None
    cosang = max(-1.0, min(1.0, (-vy) / mag))  # compare to (0, -1)
    return math.degrees(math.acos(cosang))


def _avg(vals):
    nums = [v for v in vals if v is not None]
    return sum(nums) / len(nums) if nums else None


class ChairEvaluator(PoseEvaluator):
    name = "Chair Pose"

    def __init__(self):
        # These are tuned for your webcam style. You can tweak later.
        self.KNEE_MIN = 100      # need clear bend (standing was ~80 in your screenshot)
        self.KNEE_MAX = 170      # not collapsing completely
        self.TORSO_MAX_TILT = 45 # allow forward lean
        self.ARM_MAX_TILT = 50   # arms roughly overhead
        self.FEET_RATIO_RANGE = (0.5, 2.0)  # feet ~ hip width but tolerant

    # ----------------- helpers -----------------

    def _knee_angle(self, lms, w, h, side: str) -> Optional[float]:
        hip = to_xy(lms, w, h, f"{side}_HIP")
        knee = to_xy(lms, w, h, f"{side}_KNEE")
        ankle = to_xy(lms, w, h, f"{side}_ANKLE")
        return angle_3pt(hip, knee, ankle)

    # ----------------- main eval -----------------

    def evaluate(self, lms, frame, w, h) -> Tuple[bool, str, float, List[Issue]]:
        if lms is None:
            return False, "No person detected", 0.0, []

        # Grab landmarks (we’ll choose the better side below)
        LSH = to_xy(lms, w, h, "LEFT_SHOULDER")
        RSH = to_xy(lms, w, h, "RIGHT_SHOULDER")
        LHP = to_xy(lms, w, h, "LEFT_HIP")
        RHP = to_xy(lms, w, h, "RIGHT_HIP")
        LKN = to_xy(lms, w, h, "LEFT_KNEE")
        RKN = to_xy(lms, w, h, "RIGHT_KNEE")
        LAK = to_xy(lms, w, h, "LEFT_ANKLE")
        RAK = to_xy(lms, w, h, "RIGHT_ANKLE")
        LWR = to_xy(lms, w, h, "LEFT_WRIST")
        RWR = to_xy(lms, w, h, "RIGHT_WRIST")
        LER = to_xy(lms, w, h, "LEFT_EAR")
        RER = to_xy(lms, w, h, "RIGHT_EAR")
        NOS = to_xy(lms, w, h, "NOSE")

        # Need at least both shoulders + some hips
        if any(p is None for p in (LSH, RSH, LHP, RHP)):
            return False, "Step back so torso is fully visible", 0.0, []

        # ---- choose side where leg is fully visible ----
        left_leg_ok  = (LHP is not None and LKN is not None and LAK is not None)
        right_leg_ok = (RHP is not None and RKN is not None and RAK is not None)

        if left_leg_ok:
            leg_side = "LEFT"
        elif right_leg_ok:
            leg_side = "RIGHT"
        else:
            return False, "Step back so at least one full leg is visible", 0.0, []

        # convenience accessors for chosen leg
        if leg_side == "LEFT":
            HIP = LHP; KNEE = LKN; ANK = LAK
        else:
            HIP = RHP; KNEE = RKN; ANK = RAK

        issues: List[Issue] = []
        Rcirc = max(10, int(min(w, h) * 0.04))

        # 1) Knees clearly bent (chair, not standing)
        knee_angle = self._knee_angle(lms, w, h, leg_side)
        knees_ok = (
            knee_angle is not None
            and self.KNEE_MIN <= knee_angle <= self.KNEE_MAX
        )
        if not knees_ok and KNEE:
            issues.append((int(KNEE[0]), int(KNEE[1]), Rcirc))

        # 2) Hips lower than shoulders (actually sitting down)
        hips_y = _avg([LHP[1], RHP[1]])
        shoulders_y = _avg([LSH[1], RSH[1]])
        hips_down_ok = (
            hips_y is not None and shoulders_y is not None and hips_y > shoulders_y + 10
        )
        if not hips_down_ok and HIP:
            issues.append((int(HIP[0]), int(HIP[1]), Rcirc))

        # 3) Torso not collapsing: roughly upright(ish)
        lt = _angle_with_vertical(LHP, LSH)
        rt = _angle_with_vertical(RHP, RSH)
        torso_tilt = _avg([lt, rt])
        torso_ok = (
            torso_tilt is not None and torso_tilt <= self.TORSO_MAX_TILT
        )
        if not torso_ok and LSH and RSH:
            cx = int((LSH[0] + RSH[0]) / 2)
            cy = int((LSH[1] + RSH[1]) / 2)
            issues.append((cx, cy, Rcirc))

        # 4) Arms overhead (wrists above head + near-vertical)
        arm_tilt_l = _angle_with_vertical(LSH, LWR) if (LSH and LWR) else None
        arm_tilt_r = _angle_with_vertical(RSH, RWR) if (RSH and RWR) else None
        arms_tilt = _avg([arm_tilt_l, arm_tilt_r])

        # head height (use ears/nose)
        head_pts = [p for p in (LER, RER, NOS) if p is not None]
        head_y = min([p[1] for p in head_pts]) if head_pts else None

        wrists_up = False
        if head_y is not None and LWR and RWR:
            wrists_up = (LWR[1] < head_y) and (RWR[1] < head_y)

        arms_ok = (
            arms_tilt is not None
            and arms_tilt <= self.ARM_MAX_TILT
            and wrists_up
        )
        if not arms_ok and (LWR or RWR):
            wx = _avg([LWR[0] if LWR else None, RWR[0] if RWR else None])
            wy = _avg([LWR[1] if LWR else None, RWR[1] if RWR else None])
            if wx is not None and wy is not None:
                issues.append((int(wx), int(wy), Rcirc))

        # 5) Feet ~ hip width (soft check – does NOT gate correctness)
        feet_ratio = None
        feet_ok = True
        if LAK and RAK and LHP and RHP:
            feet_span = abs(RAK[0] - LAK[0])
            hip_span = abs(RHP[0] - LHP[0])
            if hip_span > 1e-6:
                feet_ratio = feet_span / hip_span
                feet_ok = (
                    self.FEET_RATIO_RANGE[0]
                    <= feet_ratio
                    <= self.FEET_RATIO_RANGE[1]
                )
        if not feet_ok and LAK and RAK:
            cx = int((LAK[0] + RAK[0]) / 2)
            cy = int((LAK[1] + RAK[1]) / 2)
            issues.append((cx, cy, Rcirc))

        # --------- FINAL DECISION ----------
        # Must have bent leg + hips down + arms overhead.
        # Torso/feet only act as refinements.
        core_checks_ok = knees_ok and hips_down_ok and arms_ok
        is_correct = core_checks_ok and torso_ok and feet_ok

        # score = fraction of all 5 checks that passed (for the text)
        all_checks = [knees_ok, hips_down_ok, torso_ok, arms_ok, feet_ok]
        score = sum(1 for c in all_checks if c) / len(all_checks)

        msg = (
            f"Knee angle:{'N/A' if knee_angle is None else f'{knee_angle:.0f}°'} "
            f"| Hips lower than shoulders:{'YES' if hips_down_ok else 'NO'} "
            f"| Torso tilt:{'N/A' if torso_tilt is None else f'{torso_tilt:.0f}°'} "
            f"| Arms tilt:{'N/A' if arms_tilt is None else f'{arms_tilt:.0f}°'}"
            f"{' wrists↑' if wrists_up else ''} "
            f"| Feet/hip:{'N/A' if feet_ratio is None else f'{feet_ratio:.2f}x'} "
            f"| Checks OK {sum(1 for c in all_checks if c)}/{len(all_checks)}"
        )

        return is_correct, msg, score, issues
