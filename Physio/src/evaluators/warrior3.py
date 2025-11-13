from typing import Optional, List, Tuple
import math
from ..evaluator_base import PoseEvaluator, Issue
from ..utils import to_xy, angle_3pt

def _angle_with_vertical(p1, p2) -> Optional[float]:
    """Angle (deg) between vector p1->p2 and vertical up. 0° = vertical."""
    if p1 is None or p2 is None:
        return None
    vx, vy = (p2[0] - p1[0], p2[1] - p1[1])  # image y grows downward
    mag = math.hypot(vx, vy)
    if mag <= 1e-6:
        return None
    cosang = max(-1.0, min(1.0, (-vy) / mag))  # compare to (0, -1)
    return math.degrees(math.acos(cosang))

def _horiz_error_deg(p1, p2) -> Optional[float]:
    """How far p1->p2 is from perfectly horizontal (0° error = horizontal)."""
    a = _angle_with_vertical(p1, p2)
    if a is None:
        return None
    return abs(90.0 - a)

def _angle_between(pA1, pA2, pB1, pB2) -> Optional[float]:
    """Angle (deg) between directions A and B (0 = parallel)."""
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

class Warrior3Evaluator(PoseEvaluator):
    name = "Warrior III"

    def __init__(self):
        # Tunables (for webcams / side view). Tighten later if you want.
        self.STAND_KNEE_MIN   = 165  # standing leg straight
        self.BACK_KNEE_MIN    = 165  # lifted/back leg straight
        self.TORSO_H_MAX      = 18   # torso ~horizontal (deg error from horizontal)
        self.BACKLEG_H_MAX    = 18   # back leg line ~horizontal
        self.ARMS_H_MAX       = 20   # arms ~horizontal forward (or roughly inline with torso)
        self.ARM_TORSO_ALIGN  = 20   # arms direction parallel to torso line
        self.HIPS_SQUARED_MAX = 30   # hips & shoulders lines roughly parallel (less twist)
        self.MIN_OK_CHECKS    = 4    # require any 4 of 6

        self._tick = 0  # periodic debug

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

        # Require lower body + shoulders
        if any(p is None for p in (LSH, RSH, LHP, RHP, LKN, RKN, LAK, RAK)):
            return False, "Step back so shoulders–ankles are visible", 0.2, []

        issues: List[Issue] = []
        Rcirc = max(12, int(min(w, h) * 0.05))

        # Identify standing vs back (lifted) leg:
        # Standing ankle will be lowest on screen (largest y).
        if LAK and RAK:
            stand = "LEFT" if LAK[1] > RAK[1] else "RIGHT"
            back  = "RIGHT" if stand == "LEFT" else "LEFT"
        else:
            stand, back = "LEFT", "RIGHT"

        def P(side, name): return to_xy(lms, w, h, f"{side}_{name}")
        S_HIP, S_KNEE, S_ANK = P(stand, "HIP"), P(stand, "KNEE"), P(stand, "ANKLE")
        B_HIP, B_KNEE, B_ANK = P(back,  "HIP"), P(back,  "KNEE"), P(back,  "ANKLE")
        S_SH,  B_SH  = P(stand, "SHOULDER"), P(back, "SHOULDER")
        S_WR,  B_WR  = P(stand, "WRIST"),    P(back, "WRIST")

        # 1) Standing leg straight
        s_knee = angle_3pt(S_HIP, S_KNEE, S_ANK)
        stand_leg_ok = (s_knee is not None) and (s_knee >= self.STAND_KNEE_MIN)
        if not stand_leg_ok and S_KNEE: issues.append((int(S_KNEE[0]), int(S_KNEE[1]), Rcirc))

        # 2) Back (lifted) leg straight
        b_knee = angle_3pt(B_HIP, B_KNEE, B_ANK)
        back_leg_ok = (b_knee is not None) and (b_knee >= self.BACK_KNEE_MIN)
        if not back_leg_ok and B_KNEE: issues.append((int(B_KNEE[0]), int(B_KNEE[1]), Rcirc))

        # 3) Torso ~horizontal (hip->shoulder)
        lt = _horiz_error_deg(LHP, LSH)
        rt = _horiz_error_deg(RHP, RSH)
        torso_err = _avg([lt, rt])
        torso_ok = (torso_err is not None) and (torso_err <= self.TORSO_H_MAX)
        if not torso_ok and LSH and RSH:
            cx = int((LSH[0] + RSH[0]) / 2); cy = int((LSH[1] + RSH[1]) / 2)
            issues.append((cx, cy, Rcirc))

        # 4) Back leg ~horizontal (hip->ankle line)
        back_h_err = _horiz_error_deg(B_HIP, B_ANK)
        back_h_ok = (back_h_err is not None) and (back_h_err <= self.BACKLEG_H_MAX)
        if not back_h_ok and B_HIP and B_ANK:
            cx = int((B_HIP[0] + B_ANK[0]) / 2); cy = int((B_HIP[1] + B_ANK[1]) / 2)
            issues.append((cx, cy, Rcirc))

        # 5) Arms forward & roughly inline with torso (accept horizontal OR parallel)
        # Use average shoulders/wrists for a single arm vector (helps when one is occluded)
        SH_C = _avg([LSH[0] if LSH else None, RSH[0] if RSH else None]), _avg([LSH[1] if LSH else None, RSH[1] if RSH else None])
        WR_C = _avg([LWR[0] if LWR else None, RWR[0] if RWR else None]), _avg([LWR[1] if LWR else None, RWR[1] if RWR else None])
        if None in SH_C or None in WR_C:
            arms_h_err = None
            arms_align = None
            arms_ok = False
        else:
            SH_C = (SH_C[0], SH_C[1]); WR_C = (WR_C[0], WR_C[1])
            arms_h_err = _horiz_error_deg(SH_C, WR_C)
            # Compare arms direction to torso direction (hips center -> shoulders center)
            HIP_C = (_avg([LHP[0] if LHP else None, RHP[0] if RHP else None]),
                     _avg([LHP[1] if LHP else None, RHP[1] if RHP else None]))
            if None in HIP_C:
                arms_align = None
            else:
                HIP_C = (HIP_C[0], HIP_C[1])
                arms_align = _angle_between(HIP_C, SH_C, SH_C, WR_C)
            # arms OK if near horizontal OR parallel to torso line
            ok_h = (arms_h_err is not None and arms_h_err <= self.ARMS_H_MAX)
            ok_parallel = (arms_align is not None and arms_align <= self.ARM_TORSO_ALIGN)
            arms_ok = ok_h or ok_parallel
        if not arms_ok and WR_C[0] is not None and WR_C[1] is not None:
            issues.append((int(WR_C[0]), int(WR_C[1]), Rcirc))

        # 6) Hips squared (hip-line parallel to shoulder-line)
        hipsq = _angle_between(LHP, RHP, LSH, RSH)
        hips_squared_ok = (hipsq is not None) and (hipsq <= self.HIPS_SQUARED_MAX)
        if not hips_squared_ok and LHP and RHP and LSH and RSH:
            cx = int((LHP[0] + RHP[0] + LSH[0] + RSH[0]) / 4)
            cy = int((LHP[1] + RHP[1] + LSH[1] + RSH[1]) / 4)
            issues.append((cx, cy, Rcirc))

        # Aggregate
        checks = [stand_leg_ok, back_leg_ok, torso_ok, back_h_ok, arms_ok, hips_squared_ok]
        passed = sum(1 for c in checks if c)
        is_correct = passed >= self.MIN_OK_CHECKS

        # Debug line (prints every 8 frames)
        if self._tick % 8 == 0:
            print(
                f"[WARRIOR III] stand={stand} sKnee={s_knee and round(s_knee,1)} "
                f"bKnee={b_knee and round(b_knee,1)} torsoErr={torso_err and round(torso_err,1)} "
                f"backErr={back_h_err and round(back_h_err,1)} armsErr={arms_h_err and round(arms_h_err,1)} "
                f"armsAlign={arms_align and round(arms_align,1)} hipSq={hipsq and round(hipsq,1)} "
                f"passed={passed}/6"
            )

        msg = (
            f"Stand knee:{'N/A' if s_knee is None else f'{s_knee:.0f}°'} "
            f"| Back knee:{'N/A' if b_knee is None else f'{b_knee:.0f}°'} "
            f"| Torso horiz err:{'N/A' if torso_err is None else f'{torso_err:.0f}°'} "
            f"| Back leg horiz err:{'N/A' if back_h_err is None else f'{back_h_err:.0f}°'} "
            f"| Arms horiz err:{'N/A' if arms_h_err is None else f'{arms_h_err:.0f}°'}"
            f"{'' if arms_align is None else f' | Arm↔Torso:{arms_align:.0f}°'} "
            f"| Hips square:{'N/A' if hipsq is None else f'{hipsq:.0f}°'} "
            f"| OK {passed}/6 (need ≥{self.MIN_OK_CHECKS})"
        )
        score = passed / 6.0
        return is_correct, msg, score, issues
