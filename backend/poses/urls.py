from django.urls import path
from . import views

urlpatterns = [
    path('available/', views.get_available_poses, name='get_available_poses'),
    path('analyze/', views.analyze_pose_image, name='analyze_pose_image'),
    path('tips/<str:pose_name>/', views.get_pose_tips, name='get_pose_tips'),
    
    # Gesture detection endpoints
    path('gesture/status/', views.gesture_status, name='gesture_status'),
    path('gesture/detect/', views.detect_gesture_from_image, name='detect_gesture_from_image'),
    path('gesture/camera/start/', views.start_camera_detection, name='start_camera_detection'),
    path('gesture/camera/stop/', views.stop_camera_detection, name='stop_camera_detection'),
]
