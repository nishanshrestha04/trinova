from abc import ABC, abstractmethod
from typing import List, Tuple

# Issue = (x, y, r_px) in image coordinates
Issue = Tuple[int, int, int]

class PoseEvaluator(ABC):
    """Return (is_correct: bool, message: str, score: float, issues: List[Issue]) per frame."""
    name: str = "Pose"

    @abstractmethod
    def evaluate(self, lms, frame, w, h) -> Tuple[bool, str, float, List[Issue]]:
        pass
