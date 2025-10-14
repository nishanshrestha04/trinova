import argparse
from src.pose_runner import PoseRunner
from src.evaluators.cobra import CobraEvaluator
from src.evaluators.warrior2 import Warrior2Evaluator
from src.evaluators.tree import TreeEvaluator   # <-- add this

def make_evaluator(name: str):
    n = name.lower()
    if n == "cobra":
        return CobraEvaluator()
    if n in ["warrior", "warrior2", "warrior_ii", "warrior-ii"]:
        return Warrior2Evaluator()
    if n in ["tree", "treepose", "vrikshasana", "vrksasana"]:
        return TreeEvaluator()                  # <-- add this
    raise ValueError(f"Unknown pose '{name}'. Choose: catcow | cobra | warrior | tree")

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--pose", required=True, help="catcow | cobra | warrior | tree")
    ap.add_argument("--camera", type=int, default=0, help="webcam index (default 0)")
    args = ap.parse_args()

    evaluator = make_evaluator(args.pose)
    runner = PoseRunner(evaluator=evaluator, cam_index=args.camera)
    runner.run()

