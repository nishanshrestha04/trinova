from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from django.utils import timezone
from datetime import timedelta
from .models import UserStats, Session
from .serializers import UserStatsSerializer, SessionSerializer


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_stats(request):
    """Get user's statistics"""
    try:
        stats = UserStats.objects.get(user=request.user)
        serializer = UserStatsSerializer(stats)
        return Response({
            'success': True,
            'stats': serializer.data
        })
    except UserStats.DoesNotExist:
        # Create default stats if they don't exist
        stats = UserStats.objects.create(user=request.user)
        serializer = UserStatsSerializer(stats)
        return Response({
            'success': True,
            'stats': serializer.data
        })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def record_session(request):
    """Record a completed yoga session"""
    try:
        duration_minutes = request.data.get('duration_minutes', 0)
        poses_completed = request.data.get('poses_completed', [])

        # Create session record
        session = Session.objects.create(
            user=request.user,
            duration_minutes=duration_minutes,
            poses_completed=poses_completed
        )

        # Get or create user stats
        stats, created = UserStats.objects.get_or_create(user=request.user)
        
        # Update stats
        stats.total_sessions += 1
        stats.total_minutes += duration_minutes

        # Update streak
        now = timezone.now()
        if stats.last_session_date:
            days_since_last = (now.date() - stats.last_session_date.date()).days
            
            if days_since_last == 0:
                # Same day - streak continues
                pass
            elif days_since_last == 1:
                # Next day - increment streak
                stats.current_streak += 1
                if stats.current_streak > stats.longest_streak:
                    stats.longest_streak = stats.current_streak
            else:
                # Streak broken - reset to 1
                stats.current_streak = 1
        else:
            # First session ever
            stats.current_streak = 1
            stats.longest_streak = 1

        stats.last_session_date = now

        # Update pose counts
        for pose in poses_completed:
            if pose in stats.pose_counts:
                stats.pose_counts[pose] += 1
            else:
                stats.pose_counts[pose] = 1

        stats.save()

        return Response({
            'success': True,
            'message': 'Session recorded successfully',
            'stats': UserStatsSerializer(stats).data,
            'session': SessionSerializer(session).data
        })

    except Exception as e:
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_streak(request):
    """Update daily streak when user completes at least one pose"""
    try:
        # Get optional pose details
        pose_name = request.data.get('pose_name', None)
        duration_minutes = request.data.get('duration_minutes', 0)
        
        # Get or create user stats
        stats, created = UserStats.objects.get_or_create(user=request.user)
        
        now = timezone.now()
        needs_update = False

        # Update minutes if provided
        if duration_minutes > 0:
            stats.total_minutes += duration_minutes
            needs_update = True

        # Update pose count if provided
        if pose_name:
            if pose_name in stats.pose_counts:
                stats.pose_counts[pose_name] += 1
            else:
                stats.pose_counts[pose_name] = 1
            needs_update = True

        if stats.last_session_date:
            # Check if it's a different day
            is_same_day = stats.last_session_date.date() == now.date()
            
            if not is_same_day:
                needs_update = True
                days_since_last = (now.date() - stats.last_session_date.date()).days
                
                if days_since_last == 1:
                    # Next day - increment streak
                    stats.current_streak += 1
                    if stats.current_streak > stats.longest_streak:
                        stats.longest_streak = stats.current_streak
                else:
                    # Streak broken - reset to 1
                    stats.current_streak = 1
                
                stats.last_session_date = now
        else:
            # First practice ever
            needs_update = True
            stats.current_streak = 1
            stats.longest_streak = 1
            stats.last_session_date = now

        if needs_update:
            stats.save()

        return Response({
            'success': True,
            'message': 'Streak updated' if needs_update else 'No update needed',
            'stats': UserStatsSerializer(stats).data
        })

    except Exception as e:
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_400_BAD_REQUEST)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_recent_sessions(request):
    """Get user's recent sessions"""
    try:
        limit = int(request.GET.get('limit', 10))
        sessions = Session.objects.filter(user=request.user)[:limit]
        serializer = SessionSerializer(sessions, many=True)
        
        return Response({
            'success': True,
            'sessions': serializer.data
        })
    except Exception as e:
        return Response({
            'success': False,
            'error': str(e)
        }, status=status.HTTP_400_BAD_REQUEST)
