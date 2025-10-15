"""
Simple camera test to verify camera access before running gesture recognition.
"""
import cv2

def test_camera():
    print("Testing camera access...")
    
    # Try different camera indices
    for camera_id in range(3):
        print(f"Trying camera {camera_id}...")
        cap = cv2.VideoCapture(camera_id)
        
        if cap.isOpened():
            ret, frame = cap.read()
            if ret:
                print(f"✅ Camera {camera_id} is working!")
                print(f"Frame dimensions: {frame.shape}")
                cap.release()
                return camera_id
            else:
                print(f"❌ Camera {camera_id} opened but cannot read frames")
        else:
            print(f"❌ Cannot open camera {camera_id}")
            
        cap.release()
    
    print("❌ No working camera found")
    return None

if __name__ == "__main__":
    working_camera = test_camera()
    
    if working_camera is not None:
        print(f"\n🎥 Use camera ID {working_camera} for gesture recognition")
        print("\nTroubleshooting tips:")
        print("1. Make sure no other applications are using the camera")
        print("2. Check camera permissions in Windows Settings")
        print("3. Try running as administrator if needed")
    else:
        print("\n🔧 Troubleshooting steps:")
        print("1. Check if camera is connected and working")
        print("2. Close other applications that might be using the camera")
        print("3. Check Windows camera privacy settings")
        print("4. Try restarting the computer")
