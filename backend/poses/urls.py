from django.urls import path
from . import views

urlpatterns = [
    path('available/', views.get_available_poses, name='get_available_poses'),
    path('analyze/', views.analyze_pose_image, name='analyze_pose_image'),
    path('tips/<str:pose_name>/', views.get_pose_tips, name='get_pose_tips'),
]
