from typing import Optional, List, Tuple
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
    vx, vy = (p2[0] - p1[0], p2[1] - p1[1])  # y grows downward
    mag = math.hypot(vx, vy)
    if mag <= 1e-6:
        return None
    cosang = max(-1.0, min(1.0, (-vy) / mag))  # compare with (0, -1)
    return math.degrees(math.acos(cosang))


def _horiz_error_deg(p1, p2) -> Optional[float]:
    """How far p1->p2 deviates from horizontal. 0° = perfectly horizontal."""
    ang = _angle_with_vertical(p1, p2)
    if ang is None:
        return None
    return abs(90.0 - ang)


def _avg(vals):
    nums = [v for v in vals if v is not None]
    return sum(nums) / len(nums) if nums else None


class TriangleEvaluator(PoseEvaluator):
    """
    Triangle Pose (Trikonasana) side-view checker.

    It only returns TRUE when:
    - legs are straight and wide,
    - torso is sideways (almost horizontal),
    - one hand is clearly near a foot,
    - the other hand is straight upward forming a vertical line with the lower hand.
    """

    name = "Triangle Pose"

    def __init__(self):
        # Thresholds – tuned to be strict but still usable with a webcam.
        self.KNEE_MIN = 168           # both legs almost fully straight
        self.STANCE_MIN_RATIO = 1.6   # ankles distance >= 1.6 * hip span (wide)
        self.TORSO_H_MAX_ERR = 22     # torso within 22° of horizontal
        self.ARMS_V_MAX_ERR = 18      # arms line within 18° of vertical
        self.HAND_FOOT_MAX_DIST = 0.35  # hand-foot distance <= 35% of leg length

    def _knee_angle(self, lms, w, h, side: str) -> Optional[float]:
        hip = to_xy(lms, w, h, f"{side}_HIP")
        knee = to_xy(lms, w, h, f"{side}_KNEE")
        ankle = to_xy(lms, w, h, f"{side}_ANKLE")
        return angle_3pt(hip, knee, ankle)

    def evaluate(self, lms, frame, w, h) -> Tuple[bool, str, float, List[Issue]]:
        if lms is None:
            return False, "No person detected", 0.0, []

        # ---- landmarks ----
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

        # basic visibility: hips, shoulders, knees, ankles, wrists
        basic = [LSH, RSH, LHP, RHP, LKN, RKN, LAK, RAK, LWR, RWR]
        if any(p is None for p in basic):
            return False, "Step back so full legs and both hands are visible", 0.2, []

        issues: List[Issue] = []
        Rcirc = max(10, int(min(w, h) * 0.04))

        # ---- 1) legs straight ----
        lk = self._knee_angle(lms, w, h, "LEFT")
        rk = self._knee_angle(lms, w, h, "RIGHT")
        legs_ok = (
            lk is not None and lk >= self.KNEE_MIN and
            rk is not None and rk >= self.KNEE_MIN
        )
        if not (lk is not None and lk >= self.KNEE_MIN) and LKN:
            issues.append((int(LKN[0]), int(LKN[1]), Rcirc))
        if not (rk is not None and rk >= self.KNEE_MIN) and RKN:
            issues.append((int(RKN[0]), int(RKN[1]), Rcirc))

        # ---- 2) wide stance like a triangle ----
        feet_span = abs(RAK[0] - LAK[0]) if (RAK and LAK) else None
        hip_span = abs(RHP[0] - LHP[0]) if (RHP and LHP) else None
        if feet_span is not None and hip_span not in (None, 0):
            stance_ratio = feet_span / hip_span
            stance_ok = stance_ratio >= self.STANCE_MIN_RATIO
        else:
            stance_ratio = None
            stance_ok = False
        if not stance_ok and LAK and RAK:
            cx = int((LAK[0] + RAK[0]) / 2)
            cy = int((LAK[1] + RAK[1]) / 2)
            issues.append((cx, cy, Rcirc))

        # ---- 3) torso sideways (almost horizontal) ----
        HIP_C = (_avg([LHP[0], RHP[0]]), _avg([LHP[1], RHP[1]]))
        SH_C = (_avg([LSH[0], RSH[0]]), _avg([LSH[1], RSH[1]]))
        if None in HIP_C or None in SH_C:
            torso_h_err = None
            torso_ok = False
        else:
            HIP_C = (HIP_C[0], HIP_C[1])
            SH_C = (SH_C[0], SH_C[1])
            torso_h_err = _horiz_error_deg(HIP_C, SH_C)
            torso_ok = torso_h_err is not None and torso_h_err <= self.TORSO_H_MAX_ERR
        if not torso_ok and LSH and RSH:
            cx = int((LSH[0] + RSH[0]) / 2)
            cy = int((LSH[1] + RSH[1]) / 2)
            issues.append((cx, cy, Rcirc))

        # ---- 4) arms must form a vertical line (one up, one down) ----
        # identify upper & lower wrist by y
        if LWR[1] < RWR[1]:
            upper_wrist, lower_wrist = LWR, RWR
        else:
            upper_wrist, lower_wrist = RWR, LWR
        arms_v_angle = _angle_with_vertical(lower_wrist, upper_wrist)
        arms_v_err = None if arms_v_angle is None else abs(arms_v_angle - 0.0)
        arms_vertical_ok = arms_v_err is not None and arms_v_err <= self.ARMS_V_MAX_ERR

        # also check: upper wrist above shoulders, lower wrist below hips
        sh_y = _avg([LSH[1], RSH[1]])
        hip_y = _avg([LHP[1], RHP[1]])
        up_pos_ok = sh_y is not None and upper_wrist[1] < sh_y
        low_pos_ok = hip_y is not None and lower_wrist[1] > hip_y

        arms_ok = arms_vertical_ok and up_pos_ok and low_pos_ok
        if not arms_ok and LWR and RWR:
            cx = int((LWR[0] + RWR[0]) / 2)
            cy = int((LWR[1] + RWR[1]) / 2)
            issues.append((cx, cy, Rcirc))

        # ---- 5) lower hand is really at the foot ----
        # choose nearest ankle to the lower wrist
        d_to_LA = math.dist(lower_wrist, LAK)
        d_to_RA = math.dist(lower_wrist, RAK)
        near_ankle = LAK if d_to_LA <= d_to_RA else RAK
        # normalize by leg length on that side
        if near_ankle is LAK:
            leg_len = math.dist(LHP, LAK)
        else:
            leg_len = math.dist(RHP, RAK)
        if leg_len > 1e-6:
            hand_foot_ratio = math.dist(lower_wrist, near_ankle) / leg_len
            hand_on_foot_ok = hand_foot_ratio <= self.HAND_FOOT_MAX_DIST
        else:
            hand_foot_ratio = None
            hand_on_foot_ok = False

        if not hand_on_foot_ok and lower_wrist:
            issues.append((int(lower_wrist[0]), int(lower_wrist[1]), Rcirc))

        # ---- final decision: all conditions must be true ----
        checks = [legs_ok, stance_ok, torso_ok, arms_ok, hand_on_foot_ok]
        passed = sum(1 for c in checks if c)
        is_correct = all(checks)  # strictly require everything

        msg = (
            f"Legs:{'OK' if legs_ok else 'straighten'} | "
            f"Stance:{'N/A' if stance_ratio is None else f'{stance_ratio:.2f}x'} "
            f"({'OK' if stance_ok else 'wider'}) | "
            f"Torso horiz err:{'N/A' if torso_h_err is None else f'{torso_h_err:.0f}°'} "
            f"({'OK' if torso_ok else 'side bend more'}) | "
            f"Arms vert err:{'N/A' if arms_v_err is None else f'{arms_v_err:.0f}°'} "
            f"({'OK' if arms_ok else 'one up, one down'}) | "
            f"Hand–foot ratio:{'N/A' if hand_foot_ratio is None else f'{hand_foot_ratio:.2f}'} "
            f"({'OK' if hand_on_foot_ok else 'touch the foot/ankle'})"
        )

        score = passed / 5.0
        return is_correct, msg, score, issues
