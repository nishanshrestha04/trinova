#!/bin/bash

# YogAI Quick Start Script
# This script starts the backend server and opens instructions for running the app

echo "Starting YogAI Backend Server..."
echo ""

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Activate virtual environment
echo "📦 Activating virtual environment..."
source env/bin/activate

# Check if required packages are installed
echo "🔍 Checking Python dependencies..."
python -c "import cv2, mediapipe, numpy" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "⚠️  Installing missing dependencies..."
    pip install opencv-python mediapipe numpy
fi

# Get local IP address
LOCAL_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "✅ Your computer's IP address: $LOCAL_IP"
echo ""
echo "📝 IMPORTANT: Update lib/services/pose_service.dart with this IP:"
echo "   static const String baseUrl = 'http://$LOCAL_IP:8000/api/poses';"
echo ""
echo "🚀 Starting backend server on 0.0.0.0:8000..."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📱 To run on your PHONE:"
echo "   1. Connect phone and computer to SAME WiFi"
echo "   2. Update pose_service.dart with IP above"
echo "   3. Run: flutter run"
echo ""
echo "💻 To run on CHROME (for testing):"
echo "   In a new terminal, run: flutter run -d chrome"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# Start Django server
cd backend
python manage.py runserver 0.0.0.0:8000
