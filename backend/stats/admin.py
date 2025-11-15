from django.contrib import admin
from .models import UserStats, Session


@admin.register(UserStats)
class UserStatsAdmin(admin.ModelAdmin):
    list_display = ['user', 'total_sessions', 'total_minutes', 'current_streak', 'longest_streak', 'last_session_date']
    search_fields = ['user__username', 'user__email']
    readonly_fields = ['created_at', 'updated_at']


@admin.register(Session)
class SessionAdmin(admin.ModelAdmin):
    list_display = ['user', 'duration_minutes', 'completed_at']
    list_filter = ['completed_at']
    search_fields = ['user__username']
    readonly_fields = ['completed_at']
