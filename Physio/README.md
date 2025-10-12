# Yoga Pose Checker (Webcam, MediaPipe)

Poses supported:
- Tree
- Cobra (Bhujangasana)
- Warrior II (Virabhadrasana II)

## Install
python -m venv .venv
# Windows: .venv\Scripts\activate
# Mac/Linux: source .venv/bin/activate
pip install -r requirements.txt

## Run
# Choose one pose:
python main.py --pose tree
python main.py --pose cobra
python main.py --pose warrior

# Optional camera index (default 0):
python main.py --pose warrior --camera 0

Press 'q' to quit.

## Notes
- Thresholds are *heuristics*. Adjust in each evaluator file if your setup/angle differs.
- Good lighting and full-body visibility help a lot.
- MediaPipe struggles with floor poses if landmarks are occluded—face the camera sideways for Cobra, and stand far enough for Warrior II/Tree.
