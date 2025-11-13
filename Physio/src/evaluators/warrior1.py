from typing import Optional, List, Tuple
import math
from ..evaluator_base import PoseEvaluator, Issue
from ..utils import to_xy, angle_3pt

def _angle_with_vertical(p1, p2) -> Optional[float]:
    """Angle (deg) between vector p1->p2 and vertical up. 0° = vertical."""
    if p1 is None or p2 is None:
        return None
    vx, vy = (p2[0] - p1[0], p2[1] - p1[1])  # y grows downward in images
    mag = math.hypot(vx, vy)
    if mag <= 1e-6:
        return None
    cosang = max(-1.0, min(1.0, (-vy) / mag))  # compare with (0,-1)
    return math.degrees(math.acos(cosang))

def _angle_between_dirs(pA1, pA2, pB1, pB2) -> Optional[float]:
    """Angle (deg) between directions A: A1->A2 and B: B1->B2 (0 = parallel)."""
    if None in (pA1, pA2, pB1, pB2):
        return None
    ax, ay = (pA2[0] - pA1[0], pA2[1] - pA1[1])
    bx, by = (pB2[0] - pB1[0], pB2[1] - pB1[1])
    amag = math.hypot(ax, ay); bmag = math.hypot(bx, by)
    if amag <= 1e-6 or bmag <= 1e-6:
        return None
    cosang = max(-1.0, min(1.0, (ax*bx + ay*by) / (amag*bmag)))
    return math.degrees(math.acos(cosang))

def _avg(vals: List[Optional[float]]) -> Optional[float]:
    nums = [v for v in vals if v is not None]
    return sum(nums)/len(nums) if nums else None

class Warrior1Evaluator(PoseEvaluator):
    name = "Warrior I"

    def __init__(self):
        # Tunables (tolerant defaults; tighten after testing your camera)
        self.FRONT_KNEE_RANGE = (80, 115)  # front knee ≈90°
        self.BACK_KNEE_MIN    = 165        # back knee straight
        self.SHIN_MAX_TILT    = 24         # front shin ~ vertical
        self.TORSO_MAX_TILT   = 22         # torso upright
        self.ARMS_MAX_TILT    = 28         # arms overhead near-vertical
        self.HIPS_SQUARED_MAX = 28         # shoulders/hips line angle (low twist)
        self.STANCE_MIN_RATIO = 1.10       # ankles distance >= 1.10 * hip span
        self.MIN_OK_CHECKS    = 4          # require any 4/7 conditions

        self._tick = 0  # for periodic console debug

    # --- helpers for joint angles
    def _knee_angle(self, lms, w, h, side: str) -> Optional[float]:
        hip   = to_xy(lms, w, h, f"{side}_HIP")
        knee  = to_xy(lms, w, h, f"{side}_KNEE")
        ankle = to_xy(lms, w, h, f"{side}_ANKLE")
        return angle_3pt(hip, knee, ankle)

    def evaluate(self, lms, frame, w, h) -> Tuple[bool, str, float, List[Issue]]:
        self._tick += 1
        if lms is None:
            return False, "No person detected", 0.0, []

        # Landmarks
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

        # Visibility gate: lower body + shoulders
        if any(p is None for p in (LSH, RSH, LHP, RHP, LKN, RKN, LAK, RAK)):
            return False, "Step back: keep shoulders–ankles visible", 0.2, []

        issues: List[Issue] = []
        Rcirc = max(12, int(min(w, h) * 0.05))

        # Decide which leg is the front leg (the one with deeper bend)
        left_knee  = self._knee_angle(lms, w, h, "LEFT")
        right_knee = self._knee_angle(lms, w, h, "RIGHT")
        # Smaller knee angle => more bent => likely front leg
        if left_knee is not None and right_knee is not None:
            front = "LEFT" if left_knee <= right_knee else "RIGHT"
            back  = "RIGHT" if front == "LEFT" else "LEFT"
        else:
            # Fallback: use x (whichever ankle is more forward in image x) — not ideal but OK
            if LAK and RAK:
                front = "LEFT" if LAK[0] < RAK[0] else "RIGHT"
                back  = "RIGHT" if front == "LEFT" else "LEFT"
            else:
                front, back = "LEFT", "RIGHT"

        # Convenience pickers
        def P(side, name): return to_xy(lms, w, h, f"{side}_{name}")

        F_HIP, F_KNEE, F_ANK = P(front,"HIP"), P(front,"KNEE"), P(front,"ANKLE")
        B_HIP, B_KNEE, B_ANK = P(back,"HIP"),  P(back,"KNEE"),  P(back,"ANKLE")
        F_SH,  B_SH  = P(front,"SHOULDER"), P(back,"SHOULDER")
        F_WR,  B_WR  = P(front,"WRIST"),    P(back,"WRIST")

        # --- Checks ---

        # 1) Front knee ≈ 90°
        f_knee = angle_3pt(F_HIP, F_KNEE, F_ANK)
        front_knee_ok = (f_knee is not None) and (self.FRONT_KNEE_RANGE[0] <= f_knee <= self.FRONT_KNEE_RANGE[1])
        if not front_knee_ok and F_KNEE: issues.append((int(F_KNEE[0]), int(F_KNEE[1]), Rcirc))

        # 2) Front shin near vertical
        f_shin_tilt = _angle_with_vertical(F_KNEE, F_ANK)
        front_shin_ok = (f_shin_tilt is not None) and (f_shin_tilt <= self.SHIN_MAX_TILT)
        if not front_shin_ok and F_KNEE and F_ANK:
            cx = int((F_KNEE[0] + F_ANK[0]) / 2); cy = int((F_KNEE[1] + F_ANK[1]) / 2)
            issues.append((cx, cy, Rcirc))

        # 3) Back leg straight
        b_knee = angle_3pt(B_HIP, B_KNEE, B_ANK)
        back_leg_ok = (b_knee is not None) and (b_knee >= self.BACK_KNEE_MIN)
        if not back_leg_ok and B_KNEE: issues.append((int(B_KNEE[0]), int(B_KNEE[1]), Rcirc))

        # 4) Torso upright (hips->shoulders near vertical)
        lt = _angle_with_vertical(LHP, LSH)
        rt = _angle_with_vertical(RHP, RSH)
        torso_tilt = _avg([lt, rt])
        torso_ok = (torso_tilt is not None) and (torso_tilt <= self.TORSO_MAX_TILT)
        if not torso_ok and LSH and RSH:
            cx = int((LSH[0] + RSH[0]) / 2); cy = int((LSH[1] + RSH[1]) / 2)
            issues.append((cx, cy, Rcirc))

        # 5) Arms overhead (near vertical) OR wrists above head/shoulders (side tolerant)
        arm_tilt_f = _angle_with_vertical(F_SH, F_WR) if F_WR and F_SH else None
        arm_tilt_b = _angle_with_vertical(B_SH, B_WR) if B_WR and B_SH else None
        arms_tilt  = _avg([arm_tilt_f, arm_tilt_b])
        head_candidates = [p for p in (LER, RER, NOS) if p is not None]
        head_y = min([p[1] for p in head_candidates]) if head_candidates else None
        shoulder_y = _avg([LSH[1] if LSH else None, RSH[1] if RSH else None])
        up_line = head_y if head_y is not None else (shoulder_y - 8 if shoulder_y is not None else None)
        wrists_up = (up_line is not None and F_WR and B_WR and F_WR[1] < up_line and B_WR[1] < up_line)
        arms_ok = ((arms_tilt is not None and arms_tilt <= self.ARMS_MAX_TILT) or wrists_up)
        if not arms_ok and F_WR and B_WR:
            cx = int((F_WR[0] + B_WR[0]) / 2); cy = int((F_WR[1] + B_WR[1]) / 2)
            issues.append((cx, cy, Rcirc))

        # 6) Hips squared forward (low torso twist)
        # Approximate: angle between hip-line (LHIP->RHIP) and shoulder-line (LSH->RSH) should be small.
        hipsq = _angle_between_dirs(LHP, RHP, LSH, RSH)
        hips_squared_ok = (hipsq is not None) and (hipsq <= self.HIPS_SQUARED_MAX)
        if not hips_squared_ok and LHP and RHP and LSH and RSH:
            cx = int((LHP[0] + RHP[0] + LSH[0] + RSH[0]) / 4)
            cy = int((LHP[1] + RHP[1] + LSH[1] + RSH[1]) / 4)
            issues.append((cx, cy, Rcirc))

        # 7) Stance length wide enough (ankles distance vs hip span)
        feet_span = abs(RAK[0] - LAK[0]) if (RAK and LAK) else None
        hip_span  = abs(RHP[0] - LHP[0]) if (RHP and LHP) else None
        if feet_span is not None and hip_span not in (None, 0):
            stance_ratio = feet_span / hip_span
            stance_ok = stance_ratio >= self.STANCE_MIN_RATIO
        else:
            stance_ok, stance_ratio = True, None  # cannot judge
        if not stance_ok and LAK and RAK:
            cx = int((LAK[0] + RAK[0]) / 2); cy = int((LAK[1] + RAK[1]) / 2)
            issues.append((cx, cy, Rcirc))

        # Aggregate result
        checks = [front_knee_ok, front_shin_ok, back_leg_ok, torso_ok, arms_ok, hips_squared_ok, stance_ok]
        passed = sum(1 for c in checks if c)
        is_correct = passed >= self.MIN_OK_CHECKS

        # Console debug (every 8 frames)
        if self._tick % 8 == 0:
            print(
                f"[WARRIOR I] front={front} fKnee={f_knee and round(f_knee,1)} "
                f"fShinTilt={f_shin_tilt and round(f_shin_tilt,1)} "
                f"bKnee={b_knee and round(b_knee,1)} torso={torso_tilt and round(torso_tilt,1)} "
                f"armsTilt={arms_tilt and round(arms_tilt,1)} wristsUp={bool(wrists_up)} "
                f"hipSq={hipsq and round(hipsq,1)} stance={stance_ratio and round(stance_ratio,2)} "
                f"passed={passed}/7"
            )

        msg = (
            f"Front knee:{'N/A' if f_knee is None else f'{f_knee:.0f}°'} "
            f"| Front shin:{'N/A' if f_shin_tilt is None else f'{f_shin_tilt:.0f}°'} "
            f"| Back knee:{'N/A' if b_knee is None else f'{b_knee:.0f}°'} "
            f"| Torso:{'N/A' if torso_tilt is None else f'{torso_tilt:.0f}°'} "
            f"| Arms:{'N/A' if arms_tilt is None else f'{arms_tilt:.0f}°'}{' wrists↑' if wrists_up else ''} "
            f"| Hips square:{'N/A' if hipsq is None else f'{hipsq:.0f}°'} "
            f"| Stance:{'N/A' if stance_ratio is None else f'{stance_ratio:.2f}x'} "
            f"| OK {passed}/7 (need ≥{self.MIN_OK_CHECKS})"
        )
        score = passed / 7.0
        return is_correct, msg, score, issues
