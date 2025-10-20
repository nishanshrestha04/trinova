from django.shortcuts import render
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from django.contrib.auth.models import User
from django.contrib.auth import authenticate
from rest_framework_simplejwt.tokens import RefreshToken
from django.db import IntegrityError
import json


@api_view(['POST'])
@permission_classes([AllowAny])
def register(request):
    """
    Register a new user
    """
    try:
        data = json.loads(request.body)
        username = data.get('username')
        email = data.get('email')
        password = data.get('password')
        first_name = data.get('first_name', '')
        last_name = data.get('last_name', '')

        # Validate required fields
        if not username or not email or not password:
            return Response({
                'error': 'Username, email, and password are required'
            }, status=status.HTTP_400_BAD_REQUEST)

        # Check if user already exists
        if User.objects.filter(username=username).exists():
            return Response({
                'error': 'Username already exists'
            }, status=status.HTTP_400_BAD_REQUEST)

        if User.objects.filter(email=email).exists():
            return Response({
                'error': 'Email already exists'
            }, status=status.HTTP_400_BAD_REQUEST)

        # Create user
        user = User.objects.create_user(
            username=username,
            email=email,
            password=password,
            first_name=first_name,
            last_name=last_name
        )

        # Generate tokens
        refresh = RefreshToken.for_user(user)
        access_token = refresh.access_token

        return Response({
            'message': 'User created successfully',
            'access_token': str(access_token),
            'refresh_token': str(refresh),
            'user': {
                'id': user.id,
                'username': user.username,
                'email': user.email,
                'first_name': user.first_name,
                'last_name': user.last_name,
                'date_joined': user.date_joined.isoformat() if user.date_joined else None,
                'profile_picture': None,
            }
        }, status=status.HTTP_201_CREATED)

    except json.JSONDecodeError:
        return Response({
            'error': 'Invalid JSON data'
        }, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        return Response({
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
@permission_classes([AllowAny])
def login(request):
    """
    Login user and return tokens
    """
    try:
        data = json.loads(request.body)
        username = data.get('username')
        password = data.get('password')

        if not username or not password:
            return Response({
                'error': 'Username and password are required'
            }, status=status.HTTP_400_BAD_REQUEST)

        # Authenticate user
        user = authenticate(username=username, password=password)
        
        if user is None:
            return Response({
                'error': 'Invalid credentials'
            }, status=status.HTTP_401_UNAUTHORIZED)

        if not user.is_active:
            return Response({
                'error': 'Account is disabled'
            }, status=status.HTTP_401_UNAUTHORIZED)

        # Generate tokens
        refresh = RefreshToken.for_user(user)
        access_token = refresh.access_token

        # Get or create profile and get profile picture URL
        from .models import UserProfile
        profile, created = UserProfile.objects.get_or_create(user=user)
        profile_picture_url = None
        if profile.profile_picture:
            profile_picture_url = request.build_absolute_uri(profile.profile_picture.url)

        return Response({
            'message': 'Login successful',
            'access_token': str(access_token),
            'refresh_token': str(refresh),
            'user': {
                'id': user.id,
                'username': user.username,
                'email': user.email,
                'first_name': user.first_name,
                'last_name': user.last_name,
                'date_joined': user.date_joined.isoformat() if user.date_joined else None,
                'profile_picture': profile_picture_url,
            }
        }, status=status.HTTP_200_OK)

    except json.JSONDecodeError:
        return Response({
            'error': 'Invalid JSON data'
        }, status=status.HTTP_400_BAD_REQUEST)
    except Exception as e:
        return Response({
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)


@api_view(['POST'])
def logout(request):
    """
    Logout user by blacklisting the refresh token
    """
    try:
        refresh_token = request.data.get('refresh_token')
        
        if not refresh_token:
            return Response({
                'error': 'Refresh token is required'
            }, status=status.HTTP_400_BAD_REQUEST)

        token = RefreshToken(refresh_token)
        token.blacklist()

        return Response({
            'message': 'Logout successful'
        }, status=status.HTTP_200_OK)

    except Exception as e:
        return Response({
            'error': 'Invalid token'
        }, status=status.HTTP_400_BAD_REQUEST)


@api_view(['GET'])
def profile(request):
    """
    Get user profile information
    """
    user = request.user
    
    # Get or create profile
    from .models import UserProfile
    profile, created = UserProfile.objects.get_or_create(user=user)
    
    profile_picture_url = None
    if profile.profile_picture:
        profile_picture_url = request.build_absolute_uri(profile.profile_picture.url)
    
    return Response({
        'user': {
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'first_name': user.first_name,
            'last_name': user.last_name,
            'date_joined': user.date_joined.isoformat() if user.date_joined else None,
            'profile_picture': profile_picture_url,
        }
    }, status=status.HTTP_200_OK)


@api_view(['PUT', 'PATCH'])
def update_profile(request):
    """
    Update user profile information including profile picture
    """
    try:
        user = request.user
        
        # Update basic user fields
        if 'first_name' in request.data:
            user.first_name = request.data.get('first_name', user.first_name)
        if 'last_name' in request.data:
            user.last_name = request.data.get('last_name', user.last_name)
        if 'username' in request.data:
            new_username = request.data.get('username')
            # Check if username is already taken by another user
            if new_username != user.username and User.objects.filter(username=new_username).exists():
                return Response({
                    'error': 'Username already exists'
                }, status=status.HTTP_400_BAD_REQUEST)
            user.username = new_username
        
        user.save()
        
        # Get or create user profile
        from .models import UserProfile
        profile, created = UserProfile.objects.get_or_create(user=user)
        
        # Update profile picture if provided
        if 'profile_picture' in request.FILES:
            profile.profile_picture = request.FILES['profile_picture']
            profile.save()
        
        # Build profile picture URL
        profile_picture_url = None
        if profile.profile_picture:
            profile_picture_url = request.build_absolute_uri(profile.profile_picture.url)
        
        return Response({
            'message': 'Profile updated successfully',
            'user': {
                'id': user.id,
                'username': user.username,
                'email': user.email,
                'first_name': user.first_name,
                'last_name': user.last_name,
                'date_joined': user.date_joined.isoformat() if user.date_joined else None,
                'profile_picture': profile_picture_url,
            }
        }, status=status.HTTP_200_OK)
        
    except Exception as e:
        return Response({
            'error': str(e)
        }, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
