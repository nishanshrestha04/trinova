"""
Advanced camera troubleshooting utility for the yoga gesture recognition system.
This tool helps diagnose and fix common camera issues on Windows.
"""
import cv2
import sys
import time

def check_camera_properties(camera_id):
    """Check detailed camera properties and capabilities."""
    cap = cv2.VideoCapture(camera_id)
    
    if not cap.isOpened():
        return None
    
    properties = {
        'frame_width': cap.get(cv2.CAP_PROP_FRAME_WIDTH),
        'frame_height': cap.get(cv2.CAP_PROP_FRAME_HEIGHT), 
        'fps': cap.get(cv2.CAP_PROP_FPS),
        'fourcc': cap.get(cv2.CAP_PROP_FOURCC),
        'brightness': cap.get(cv2.CAP_PROP_BRIGHTNESS),
        'contrast': cap.get(cv2.CAP_PROP_CONTRAST),
        'saturation': cap.get(cv2.CAP_PROP_SATURATION),
        'exposure': cap.get(cv2.CAP_PROP_EXPOSURE)
    }
    
    cap.release()
    return properties

def test_camera_with_different_backends():
    """Test camera with different OpenCV backends."""
    backends = [
        (cv2.CAP_DSHOW, "DirectShow"),
        (cv2.CAP_MSMF, "Media Foundation"), 
        (cv2.CAP_V4L2, "Video4Linux2"),
        (cv2.CAP_ANY, "Any Available")
    ]
    
    print("🔍 Testing different camera backends...")
    
    for backend_id, backend_name in backends:
        print(f"\n📷 Testing {backend_name} backend...")
        
        for camera_id in range(3):
            try:
                cap = cv2.VideoCapture(camera_id, backend_id)
                
                if cap.isOpened():
                    ret, frame = cap.read()
                    if ret:
                        print(f"✅ Camera {camera_id} works with {backend_name}")
                        print(f"   Frame size: {frame.shape}")
                        cap.release()
                        return camera_id, backend_id, backend_name
                    else:
                        print(f"⚠️  Camera {camera_id} opens but can't read frames")
                        
                cap.release()
                
            except Exception as e:
                print(f"❌ Error with camera {camera_id}: {e}")
    
    return None, None, None

def run_camera_stress_test(camera_id, duration=10):
    """Run a stress test on the camera to check stability."""
    print(f"\n🧪 Running {duration}s stress test on camera {camera_id}...")
    
    cap = cv2.VideoCapture(camera_id)
    
    if not cap.isOpened():
        print("❌ Cannot open camera for stress test")
        return False
    
    frame_count = 0
    failed_frames = 0
    start_time = time.time()
    
    while time.time() - start_time < duration:
        ret, frame = cap.read()
        
        if ret:
            frame_count += 1
        else:
            failed_frames += 1
            
        if frame_count % 30 == 0:  # Print every 30 frames (~1 second)
            elapsed = time.time() - start_time
            fps = frame_count / elapsed if elapsed > 0 else 0
            print(f"   {elapsed:.1f}s: {frame_count} frames, {fps:.1f} FPS, {failed_frames} failures")
    
    cap.release()
    
    success_rate = (frame_count / (frame_count + failed_frames)) * 100 if (frame_count + failed_frames) > 0 else 0
    print(f"✅ Stress test complete: {success_rate:.1f}% success rate")
    
    return success_rate > 90

def check_windows_camera_settings():
    """Provide guidance for Windows camera settings."""
    print("\n🔧 Windows Camera Settings Checklist:")
    print("=" * 50)
    
    steps = [
        "1. Open Windows Settings (Win + I)",
        "2. Go to Privacy & Security > Camera",
        "3. Make sure 'Camera access' is turned ON",
        "4. Make sure 'Let apps access your camera' is turned ON", 
        "5. Scroll down and make sure Python/Command Prompt is allowed",
        "6. Check Device Manager > Cameras for any warning icons",
        "7. Try updating camera drivers if available",
        "8. Restart Windows if changes were made"
    ]
    
    for step in steps:
        print(f"   {step}")
    
    print("\n💡 Additional Tips:")
    print("   • Close Skype, Teams, Zoom, or other camera apps")
    print("   • Try running Command Prompt as Administrator")
    print("   • Check if antivirus is blocking camera access")
    print("   • Test camera in Windows Camera app first")

def interactive_camera_fix():
    """Interactive camera troubleshooting session."""
    print("🚀 Interactive Camera Troubleshooting")
    print("=" * 50)
    
    # Test basic camera access
    print("\n1️⃣ Testing basic camera access...")
    working_camera, backend, backend_name = test_camera_with_different_backends()
    
    if working_camera is not None:
        print(f"\n✅ Found working camera: {working_camera} with {backend_name}")
        
        # Get camera properties
        properties = check_camera_properties(working_camera)
        if properties:
            print(f"\n📊 Camera {working_camera} Properties:")
            for prop, value in properties.items():
                print(f"   {prop}: {value}")
        
        # Run stress test
        print("\n2️⃣ Running stability test...")
        stable = run_camera_stress_test(working_camera, 5)
        
        if stable:
            print(f"\n🎉 Camera {working_camera} is working perfectly!")
            print(f"\n🔧 To fix the yoga app, modify the camera ID:")
            print(f"   In src/hand_gesture.py, change:")
            print(f"   for camera_id in range(3): -> for camera_id in [{working_camera}]:")
            return working_camera
        else:
            print(f"\n⚠️  Camera {working_camera} has stability issues")
    
    print("\n❌ No stable camera found. Checking Windows settings...")
    check_windows_camera_settings()
    return None

def main():
    print("📷 Advanced Camera Troubleshooting Tool")
    print("For Yoga Gesture Recognition System")
    print("=" * 50)
    
    try:
        result = interactive_camera_fix()
        
        if result is not None:
            print(f"\n✅ Success! Camera {result} is ready for gesture recognition")
            print("Run: python src/hand_gesture.py")
        else:
            print("\n💡 Camera issues detected. Follow the troubleshooting steps above.")
            print("Alternative: Run the demo version: python demo_gesture_recognition.py")
            
    except KeyboardInterrupt:
        print("\n\n🛑 Troubleshooting cancelled by user")
    except Exception as e:
        print(f"\n❌ Unexpected error: {e}")
        print("Please check your OpenCV installation")

if __name__ == "__main__":
    main()
