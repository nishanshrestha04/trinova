from django.urls import path
from . import views

urlpatterns = [
    path('stats/', views.get_stats, name='get_stats'),
    path('session/', views.record_session, name='record_session'),
    path('streak/', views.update_streak, name='update_streak'),
    path('sessions/', views.get_recent_sessions, name='get_recent_sessions'),
]
