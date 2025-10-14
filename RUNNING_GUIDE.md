# YogAI - Running Guide 🧘‍♀️

This guide will help you run the complete YogAI application including the Flutter frontend, Django backend, and Python pose detection system.

## Prerequisites

Before you start, make sure you have installed:
- **Flutter SDK** (3.9.0 or higher) - [Install Flutter](https://docs.flutter.dev/get-started/install)
- **Python 3.10+** - Already available at `/home/nishanshrestha/Documents/YogAI/trinova/env/bin/python3`
- **A webcam** - For pose detection
- **Android Studio / Xcode / Chrome** - For running the Flutter app

---

## Quick Start (3 Steps)

### Step 1: Start the Django Backend

```bash
cd /home/nishanshrestha/Documents/YogAI/trinova/backend

# Activate virtual environment (if not already activated)
source ../env/bin/activate

# Run Django server
python manage.py runserver
```

**Backend will run at:** `http://localhost:8000`

---

### Step 2: Start the Flutter App

Open a **new terminal** and run:

```bash
cd /home/nishanshrestha/Documents/YogAI/trinova

# Get Flutter dependencies
flutter pub get

# Run the app (choose one option):

# For Chrome (Web)
flutter run -d chrome

# For Android Emulator
flutter run -d android

# For Linux Desktop
flutter run -d linux
```

---

### Step 3: Test Pose Detection (Optional)

Open a **new terminal** and run:

```bash
cd /home/nishanshrestha/Documents/YogAI/trinova/Physio

# Activate Python virtual environment
source .venv/bin/activate  # or create new one if needed

# Install dependencies (first time only)
pip install -r requirements.txt

# Test a pose (choose one):
python main.py --pose tree
python main.py --pose cobra
python main.py --pose warrior

# Press 'q' to quit
```

---

## Detailed Setup Instructions

### 1. Backend Setup (Django)

#### First Time Setup:
```bash
cd backend

# Activate virtual environment
source ../env/bin/activate

# Install dependencies (if needed)
pip install django djangorestframework djangorestframework-simplejwt django-cors-headers

# Run migrations
python manage.py makemigrations
python manage.py migrate

# Create superuser (optional)
python manage.py createsuperuser

# Run server
python manage.py runserver
```

#### Test Backend:
```bash
# Test API endpoints
curl http://localhost:8000/api/auth/register/
curl http://localhost:8000/api/auth/login/
```

---

### 2. Flutter App Setup

#### First Time Setup:
```bash
cd /home/nishanshrestha/Documents/YogAI/trinova

# Get dependencies
flutter pub get

# Check available devices
flutter devices

# Run on Chrome (recommended for development)
flutter run -d chrome
```

#### App Features:
- ✅ User Authentication (Login/Register)
- ✅ Home Page with personalized greeting
- ✅ Poses Tab with 3 yoga poses
- ✅ Progress Tab (coming soon)
- ✅ Profile Tab

---

### 3. Python Pose Detection Setup

#### First Time Setup:
```bash
cd Physio

# Create virtual environment (if not exists)
python3 -m venv .venv

# Activate it
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

#### Available Poses:
1. **Tree Pose** - `python main.py --pose tree`
2. **Cobra Pose** - `python main.py --pose cobra`
3. **Warrior II** - `python main.py --pose warrior`

#### Pose Detection Tips:
- Ensure good lighting
- Keep full body visible in frame
- Stand 6-8 feet from camera
- Press 'q' to quit

---

## Troubleshooting

### Backend Issues:

**Port already in use:**
```bash
# Kill process on port 8000
sudo lsof -ti:8000 | xargs kill -9
# or use different port
python manage.py runserver 8001
```

**Database errors:**
```bash
# Reset database
rm db.sqlite3
python manage.py migrate
```

---

### Flutter Issues:

**Dependencies error:**
```bash
flutter clean
flutter pub get
```

**Device not found:**
```bash
# Check devices
flutter devices

# For web
flutter run -d web-server --web-port 8080

# For Linux desktop
flutter run -d linux
```

**Build error:**
```bash
# Clear build cache
flutter clean
rm -rf build/
flutter pub get
flutter run
```

---

### Python Pose Detection Issues:

**ModuleNotFoundError:**
```bash
cd Physio
source .venv/bin/activate
pip install -r requirements.txt
```

**Camera not working:**
```bash
# Try different camera index
python main.py --pose tree --camera 0
python main.py --pose tree --camera 1
```

**OpenCV error:**
```bash
pip uninstall opencv-python
pip install opencv-python
```

---

## Architecture

```
YogAI/
├── Flutter App (Frontend)        → Port: varies by platform
│   ├── Authentication Pages
│   ├── Home Page
│   ├── Poses Tab
│   └── Profile Tab
│
├── Django Backend (API)          → Port: 8000
│   ├── User Authentication
│   ├── JWT Token Management
│   └── REST API Endpoints
│
└── Python Pose Detection         → Standalone CLI
    ├── MediaPipe Integration
    ├── Real-time Pose Analysis
    └── 3 Yoga Poses Support
```

---

## API Endpoints

### Authentication:
- `POST /api/auth/register/` - Create new user
- `POST /api/auth/login/` - Login user
- `POST /api/auth/logout/` - Logout user
- `GET /api/auth/user/` - Get user details

---

## Development Workflow

### Typical Development Session:

1. **Terminal 1 - Backend:**
   ```bash
   cd backend
   source ../env/bin/activate
   python manage.py runserver
   ```

2. **Terminal 2 - Flutter:**
   ```bash
   cd /home/nishanshrestha/Documents/YogAI/trinova
   flutter run -d chrome
   ```

3. **Terminal 3 - Pose Detection (when needed):**
   ```bash
   cd Physio
   source .venv/bin/activate
   python main.py --pose tree
   ```

---

## Next Steps

### To Integrate Pose Detection with Flutter:
1. Create REST API endpoint in Django backend
2. Add method channel in Flutter
3. Call Python script from backend
4. Return results to Flutter app

### Future Features:
- Video recording of practice sessions
- Progress tracking and analytics
- Social features and challenges
- More yoga poses
- Personalized workout plans

---

## Support

For issues or questions:
1. Check this guide's Troubleshooting section
2. Review Flutter logs: `flutter logs`
3. Check Django logs in terminal
4. Test each component separately

---

**Happy Coding! 🚀**
