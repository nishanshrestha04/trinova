import argparse
from src.pose_runner import PoseRunner
from src.evaluators.cobra import CobraEvaluator
from src.evaluators.warrior2 import Warrior2Evaluator
from src.evaluators.tree import TreeEvaluator
from src.evaluators.warrior1 import Warrior1Evaluator
from src.evaluators.warrior3 import Warrior3Evaluator
from src.evaluators.triangle import TriangleEvaluator
from src.evaluators.chair import ChairEvaluator 
from src.evaluators.downward_dog import DownwardDogEvaluator

def make_evaluator(name: str):
    
    n = name.lower()
    if n == "cobra":
        return CobraEvaluator()
    if n in ["warrior", "warrior2", "warrior_ii", "warrior-ii"]:
        return Warrior2Evaluator()
    if n in ["warrior1", "warrior-i", "warrior_1", "virabhadrasana i", "virabhadrasana-i"]:
        return Warrior1Evaluator()
    if n in ["warrior3", "warrior-iii", "warrior_iii", "virabhadrasana iii", "virabhadrasana-iii"]:
        return Warrior3Evaluator() 
    if n in ["tree", "treepose", "vrikshasana", "vrksasana"]:
        return TreeEvaluator()
    if n in ["triangle", "triangular", "trikonasana", "trikona", "trianglepose"]:
        return TriangleEvaluator()
    if n in ["chair", "utkatasana", "utkata"]:
        return ChairEvaluator()
    if n in [
        "downwarddog",
        "downward_dog",
        "downward-dog",
        "down_dog",
        "downwardfacingdog",
        "adho-mukha-svanasana",
        "adhomukhasvanasana",
    ]:
        return DownwardDogEvaluator()
    raise ValueError(f"Unknown pose '{name}'. Choose: cobra | warrior | warrior1 | warrior3 | tree | triangle | chair | downwarddog")

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--pose", required=True, help="cobra | warrior | warrior1 | warrior3 | tree | triangle | chair | downwarddog")
    ap.add_argument("--camera", type=int, default=0, help="webcam index (default 0)")
    args = ap.parse_args()

    evaluator = make_evaluator(args.pose)
    runner = PoseRunner(evaluator=evaluator, cam_index=args.camera)
    runner.run()
