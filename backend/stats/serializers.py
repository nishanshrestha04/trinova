from rest_framework import serializers
from .models import UserStats, Session


class UserStatsSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserStats
        fields = ['total_sessions', 'total_minutes', 'current_streak', 
                  'longest_streak', 'last_session_date', 'pose_counts']


class SessionSerializer(serializers.ModelSerializer):
    class Meta:
        model = Session
        fields = ['id', 'duration_minutes', 'poses_completed', 'completed_at']
        read_only_fields = ['id', 'completed_at']
