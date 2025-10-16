"""
Demo Gesture Recognition - Visual Guide
Shows example hand positions for each gesture
"""

import cv2
import numpy as np


def create_gesture_guide():
    """Create visual guide showing all gestures"""
    
    # Create canvas
    width, height = 1200, 800
    canvas = np.ones((height, width, 3), dtype=np.uint8) * 255
    
    # Title
    cv2.putText(canvas, "Yoga Gesture Control - Quick Reference Guide", 
                (50, 50), cv2.FONT_HERSHEY_BOLD, 1.2, (0, 0, 0), 2)
    
    cv2.line(canvas, (50, 70), (1150, 70), (200, 200, 200), 2)
    
    # Gesture descriptions
    gestures = [
        {
            "name": "Open Palm",
            "emoji": "Hand",
            "action": "PAUSE TRACKING",
            "description": "All 5 fingers extended",
            "tips": ["Keep hand flat", "Face palm to camera", "All fingers visible"],
            "color": (0, 165, 255)  # Orange
        },
        {
            "name": "Thumbs Up",
            "emoji": "Thumb",
            "action": "RESUME/PLAY TRACKING",
            "description": "Only thumb extended upward",
            "tips": ["Fold other fingers", "Thumb points up", "Clear thumb visibility"],
            "color": (0, 255, 0)  # Green
        },
        {
            "name": "Point",
            "emoji": "Index",
            "action": "NEXT EXERCISE",
            "description": "Only index finger extended",
            "tips": ["Point index forward", "Fold other fingers", "Hold steady"],
            "color": (255, 0, 0)  # Blue
        },
        {
            "name": "Exit Sequence",
            "emoji": "Palm->Fist",
            "action": "EXIT GESTURE MODE",
            "description": "Open Palm followed by Fist",
            "tips": ["Show open palm first", "Then close to fist", "Within 2 seconds"],
            "color": (0, 0, 255)  # Red
        }
    ]
    
    # Draw each gesture
    y_offset = 120
    for i, gesture in enumerate(gestures):
        # Gesture box
        box_y = y_offset + (i * 160)
        
        # Colored indicator
        cv2.rectangle(canvas, (60, box_y), (80, box_y + 120), gesture["color"], -1)
        
        # Gesture name
        cv2.putText(canvas, f"{gesture['emoji']} {gesture['name']}", 
                    (100, box_y + 30), cv2.FONT_HERSHEY_BOLD, 0.8, (0, 0, 0), 2)
        
        # Action (highlighted)
        cv2.rectangle(canvas, (100, box_y + 45), (500, box_y + 75), 
                     gesture["color"], -1)
        cv2.putText(canvas, gesture["action"], 
                    (110, box_y + 67), cv2.FONT_HERSHEY_BOLD, 0.7, (255, 255, 255), 2)
        
        # Description
        cv2.putText(canvas, gesture["description"], 
                    (100, box_y + 100), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (60, 60, 60), 1)
        
        # Tips
        for j, tip in enumerate(gesture["tips"]):
            cv2.putText(canvas, f"• {tip}", 
                       (550, box_y + 30 + (j * 30)), 
                       cv2.FONT_HERSHEY_SIMPLEX, 0.5, (100, 100, 100), 1)
    
    # Instructions box
    instructions_y = 680
    cv2.rectangle(canvas, (50, instructions_y), (1150, instructions_y + 100), 
                 (240, 240, 240), -1)
    cv2.rectangle(canvas, (50, instructions_y), (1150, instructions_y + 100), 
                 (200, 200, 200), 2)
    
    cv2.putText(canvas, "How to Use:", 
                (70, instructions_y + 30), cv2.FONT_HERSHEY_BOLD, 0.7, (0, 0, 0), 2)
    
    steps = [
        "1. Start the gesture server: ./start_gesture_server.sh",
        "2. Run the Flutter app and open a pose",
        "3. Show gestures to camera to control tracking",
        "4. Hold each gesture for 1-2 seconds for detection"
    ]
    
    for i, step in enumerate(steps):
        cv2.putText(canvas, step, 
                   (70, instructions_y + 55 + (i * 20)), 
                   cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 0, 0), 1)
    
    return canvas


def main():
    """Display the gesture guide"""
    print("📚 Creating Gesture Guide...")
    
    guide = create_gesture_guide()
    
    # Save the guide
    output_path = "gesture_guide.png"
    cv2.imwrite(output_path, guide)
    print(f"✅ Gesture guide saved to: {output_path}")
    
    # Display the guide
    cv2.imshow("Yoga Gesture Control - Quick Reference", guide)
    print("👋 Press any key to close the guide...")
    cv2.waitKey(0)
    cv2.destroyAllWindows()


if __name__ == "__main__":
    main()
