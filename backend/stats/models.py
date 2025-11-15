from django.db import models
from django.contrib.auth.models import User


class UserStats(models.Model):
    """Store user yoga practice statistics"""
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='yoga_stats')
    total_sessions = models.IntegerField(default=0)
    total_minutes = models.IntegerField(default=0)
    current_streak = models.IntegerField(default=0)
    longest_streak = models.IntegerField(default=0)
    last_session_date = models.DateTimeField(null=True, blank=True)
    pose_counts = models.JSONField(default=dict)  # Store pose counts as JSON
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = 'User Statistics'
        verbose_name_plural = 'User Statistics'

    def __str__(self):
        return f"{self.user.username}'s Stats"


class Session(models.Model):
    """Store individual yoga sessions"""
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='yoga_sessions')
    duration_minutes = models.IntegerField()
    poses_completed = models.JSONField(default=list)  # List of pose IDs
    completed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-completed_at']

    def __str__(self):
        return f"{self.user.username} - {self.completed_at.strftime('%Y-%m-%d %H:%M')}"
