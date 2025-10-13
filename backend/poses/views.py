from django.shortcuts import render
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.response import Response
import subprocess
import os
import json
import base64
import cv2
import numpy as np
from pathlib import Path

# Get the path to the Physio directory
BASE_DIR = Path(__file__).resolve().parent.parent.parent
PHYSIO_DIR = BASE_DIR / 'Physio'


@api_view(['GET'])
@permission_classes([AllowAny])
def get_available_poses(request):
    """
    Get list of available yoga poses
    """
    poses = [
        {
            'id': 'tree',
            'name': 'Tree Pose',
            'sanskrit': 'Vrikshasana',
            'difficulty': 'Beginner',
            'duration': '2-3 min',
            'description': 'A balancing pose that improves focus and stability. Stand on one leg with the other foot on your thigh.',
            'benefits': ['Improves balance', 'Strengthens legs', 'Enhances focus'],
            'icon': 'park',
            'color': '#4caf50'
        },
        {
            'id': 'cobra',
            'name': 'Cobra Pose',
            'sanskrit': 'Bhujangasana',
            'difficulty': 'Beginner',
            'duration': '2-3 min',
            'description': 'A backbend that opens the chest and strengthens the spine. Lie on your stomach and lift your chest.',
            'benefits': ['Opens chest', 'Strengthens spine', 'Improves posture'],
            'icon': 'pets',
            'color': '#667eea'
        },
        {
            'id': 'warrior',
            'name': 'Warrior II',
            'sanskrit': 'Virabhadrasana II',
            'difficulty': 'Intermediate',
            'duration': '3-4 min',
            'description': 'A standing pose that builds strength and stamina. Lunge with arms extended in a T-shape.',
            'benefits': ['Builds strength', 'Increases stamina', 'Opens hips'],
            'icon': 'fitness_center',
            'color': '#764ba2'
        }
    ]
    
    return Response({
        'success': True,
        'poses': poses
    }, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([AllowAny])
def analyze_pose_image(request):
    """
    Analyze a single image for pose detection
    Expects: { "pose": "tree|cobra|warrior", "image": "base64_encoded_image" }
    """
    try:
        data = request.data
        pose_name = data.get('pose', 'tree').lower()
        image_data = data.get('image')
        
        if not image_data:
            return Response({
                'error': 'Image data is required'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Validate pose name
        valid_poses = ['tree', 'cobra', 'warrior', 'warrior2']
        if pose_name not in valid_poses:
            return Response({
                'error': f'Invalid pose. Choose from: {", ".join(valid_poses)}'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Decode base64 image
        try:
            # Remove data URL prefix if present
            if ',' in image_data:
                image_data = image_data.split(',')[1]
            
            img_bytes = base64.b64decode(image_data)
            nparr = np.frombuffer(img_bytes, np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
            
            if frame is None:
                return Response({
                    'error': 'Invalid image data'
                }, status=status.HTTP_400_BAD_REQUEST)
            
        except Exception as e:
            return Response({
                'error': f'Failed to decode image: {str(e)}'
            }, status=status.HTTP_400_BAD_REQUEST)
        
        # Import the pose detection modules
        import sys
        sys.path.append(str(PHYSIO_DIR))
        
        from src.evaluators.tree import TreeEvaluator
        from src.evaluators.cobra import CobraEvaluator
        from src.evaluators.warrior2 import Warrior2Evaluator
        import mediapipe as mp
        
        # Create evaluator based on pose
        if pose_name == 'tree':
            evaluator = TreeEvaluator()
        elif pose_name == 'cobra':
            evaluator = CobraEvaluator()
        else:  # warrior or warrior2
            evaluator = Warrior2Evaluator()
        
        # Initialize MediaPipe
        mp_pose = mp.solutions.pose
        pose_detector = mp_pose.Pose(
            static_image_mode=True,
            model_complexity=1,
            min_detection_confidence=0.5,
            min_tracking_confidence=0.5
        )
        
        # Process image
        h, w = frame.shape[:2]
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = pose_detector.process(rgb_frame)
        
        if results.pose_landmarks:
            # Evaluate pose
            is_correct, message, score, issues = evaluator.evaluate(
                results.pose_landmarks.landmark,
                frame,
                w,
                h
            )
            
            # Convert landmarks to list of dictionaries for JSON serialization
            landmarks_list = []
            for landmark in results.pose_landmarks.landmark:
                landmarks_list.append({
                    'x': landmark.x,
                    'y': landmark.y,
                    'z': landmark.z,
                    'visibility': landmark.visibility
                })
            
            return Response({
                'success': True,
                'pose': pose_name,
                'is_correct': is_correct,
                'score': score,
                'message': message,
                'landmarks': landmarks_list,
                'feedback': {
                    'detected': True,
                    'issues_count': len(issues),
                }
            }, status=status.HTTP_200_OK)
        else:
            return Response({
                'success': True,
                'pose': pose_name,
                'is_correct': False,
                'score': 0.0,
                'message': 'No person detected in the image',
                'feedback': {
                    'detected': False,
                    'issues_count': 0,
                }
            }, status=status.HTTP_200_OK)
        
    except Exception as e:
        return Response({
            'error': f'Analysis failed: {str(e)}'
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['GET'])
@permission_classes([AllowAny])
def get_pose_tips(request, pose_name):
    """
    Get tips and instructions for a specific pose
    """
    tips_data = {
        'tree': {
            'name': 'Tree Pose',
            'sanskrit': 'Vrikshasana',
            'key_points': [
                'Stand on one leg firmly',
                'Place other foot on inner thigh (not knee)',
                'Bring hands together above head',
                'Keep hips level and facing forward',
                'Focus on a fixed point for balance'
            ],
            'common_mistakes': [
                'Placing foot directly on knee joint',
                'Leaning to one side',
                'Holding breath',
                'Tilting hips'
            ],
            'camera_setup': 'Position camera at chest height, showing full body from front'
        },
        'cobra': {
            'name': 'Cobra Pose',
            'sanskrit': 'Bhujangasana',
            'key_points': [
                'Lie face down on mat',
                'Place hands under shoulders',
                'Lift chest using back muscles',
                'Keep elbows slightly bent',
                'Look slightly upward'
            ],
            'common_mistakes': [
                'Lifting too high causing strain',
                'Collapsing shoulders',
                'Legs too far apart',
                'Over-arching lower back'
            ],
            'camera_setup': 'Position camera to the side, showing full body profile'
        },
        'warrior': {
            'name': 'Warrior II',
            'sanskrit': 'Virabhadrasana II',
            'key_points': [
                'Stand with feet wide apart',
                'Turn front foot 90 degrees out',
                'Bend front knee to 90 degrees',
                'Extend arms parallel to ground',
                'Look over front hand'
            ],
            'common_mistakes': [
                'Front knee extending past ankle',
                'Back foot not flat on ground',
                'Torso leaning forward',
                'Arms not level'
            ],
            'camera_setup': 'Position camera at chest height, showing full body from front'
        }
    }
    
    pose_name = pose_name.lower()
    if pose_name not in tips_data:
        return Response({
            'error': 'Pose not found'
        }, status=status.HTTP_404_NOT_FOUND)
    
    return Response({
        'success': True,
        'pose': pose_name,
        'tips': tips_data[pose_name]
    }, status=status.HTTP_200_OK)
