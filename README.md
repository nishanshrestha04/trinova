# YogAI 🧘‍♀️

AI-powered yoga pose detection app with real-time feedback. Practice yoga poses and get instant corrections using advanced computer vision technology.

![YogAI](https://img.shields.io/badge/Flutter-3.9.0-blue) ![Django](https://img.shields.io/badge/Django-5.2.6-green) ![Python](https://img.shields.io/badge/Python-3.10-yellow)

## ✨ Features

- 🎯 **AI-Powered Pose Detection** - Real-time analysis using MediaPipe
- 📱 **Cross-Platform** - Works on Android, iOS, and Web
- 🧘 **3 Yoga Poses** - Tree, Cobra, and Warrior II
- 📊 **Instant Feedback** - Get scored on pose accuracy (0-100%)
- 💡 **Smart Tips** - Personalized corrections and suggestions
- 📸 **Camera & Gallery** - Analyze live or from photos
- 👤 **User Authentication** - Secure login and profile management

## 🚀 Quick Start

### Prerequisites
- Flutter SDK (3.9.0+)
- Python 3.10+
- Webcam/Camera for pose detection

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/nishanshrestha04/trinova.git
cd trinova
```

2. **Install Flutter dependencies**
```bash
flutter pub get
```

3. **Start the backend**
```bash
./start_backend.sh
```

4. **Run the app**
```bash
# For Chrome (Web)
flutter run -d chrome

# For Android/iOS Phone
flutter run
```

## 📱 Running on Your Phone

For detailed phone setup instructions, see **[PHONE_SETUP_GUIDE.md](PHONE_SETUP_GUIDE.md)**

**Quick steps:**

1. Start backend:
   ```bash
   ./start_backend.sh
   ```

2. Find your computer's IP (shown by start script)

3. Update `lib/services/pose_service.dart`:
   ```dart
   static const String baseUrl = 'http://YOUR_IP:8000/api/poses';
   ```

4. Connect phone and run:
   ```bash
   flutter run
   ```

## 🎯 How to Use

1. **Launch the app** and login/register
2. **Navigate to Poses tab** (second icon)
3. **Choose a yoga pose** (Tree, Cobra, or Warrior II)
4. **Tap "Start Practice"**
5. **Position yourself** in front of camera
6. **Take a picture** or select from gallery
7. **Get instant feedback** with score and corrections!

## 🏗️ Architecture

```
YogAI/
├── lib/                    # Flutter app (Frontend)
│   ├── main.dart
│   ├── pages/             # UI pages
│   ├── services/          # API services
│   ├── providers/         # State management
│   └── models/            # Data models
│
├── backend/               # Django API (Backend)
│   ├── authentication/    # User auth
│   ├── poses/            # Pose detection API
│   └── manage.py
│
└── Physio/               # Python pose detection
    ├── main.py           # CLI interface
    └── src/
        └── evaluators/   # Pose evaluation logic
```

## 🔌 API Endpoints

### Authentication
- `POST /api/auth/register/` - Create account
- `POST /api/auth/login/` - Login
- `POST /api/auth/logout/` - Logout
- `GET /api/auth/user/` - Get user profile

### Poses
- `GET /api/poses/available/` - List available poses
- `POST /api/poses/analyze/` - Analyze pose from image
- `GET /api/poses/tips/<pose>/` - Get pose instructions

## 🧘 Available Poses

### 1. Tree Pose (Vrikshasana) 🌳
- **Difficulty**: Beginner
- **Benefits**: Balance, leg strength, focus
- **Key Points**: Stand on one leg, foot on thigh, hands overhead

### 2. Cobra Pose (Bhujangasana) 🐍
- **Difficulty**: Beginner
- **Benefits**: Spine strength, chest opening, posture
- **Key Points**: Lie face down, lift chest, slight bend in elbows

### 3. Warrior II (Virabhadrasana II) ⚔️
- **Difficulty**: Intermediate
- **Benefits**: Leg strength, stamina, hip flexibility
- **Key Points**: Wide stance, front knee bent, arms parallel

## 🛠️ Tech Stack

### Frontend
- **Flutter** - Cross-platform UI framework
- **Provider** - State management
- **Camera** - Camera access
- **HTTP** - API communication

### Backend
- **Django** - Web framework
- **Django REST Framework** - API
- **JWT** - Authentication
- **CORS** - Cross-origin support

### AI/ML
- **MediaPipe** - Pose detection
- **OpenCV** - Image processing
- **NumPy** - Numerical computing

## 📂 Project Structure

```
trinova/
├── lib/
│   ├── pages/
│   │   ├── home_page.dart          # Main app with tabs
│   │   ├── pose_camera_page.dart   # Camera & pose detection
│   │   └── auth/                   # Login/register pages
│   ├── services/
│   │   ├── pose_service.dart       # Pose API client
│   │   └── auth_service.dart       # Auth API client
│   └── providers/
│       └── auth_provider.dart      # Auth state
│
├── backend/
│   ├── authentication/             # User management
│   ├── poses/                      # Pose detection API
│   │   ├── views.py               # API endpoints
│   │   └── urls.py                # URL routing
│   └── backend/
│       ├── settings.py            # Django config
│       └── urls.py                # Main routing
│
├── Physio/
│   ├── main.py                    # Standalone CLI
│   └── src/
│       ├── evaluators/            # Pose logic
│       │   ├── tree.py
│       │   ├── cobra.py
│       │   └── warrior2.py
│       └── pose_runner.py         # Webcam interface
│
├── start_backend.sh               # Quick start script
├── PHONE_SETUP_GUIDE.md          # Phone setup instructions
└── RUNNING_GUIDE.md              # Detailed running guide
```

## 🔧 Configuration

### Backend URL
Edit `lib/services/pose_service.dart`:
```dart
// For local testing on computer
static const String baseUrl = 'http://localhost:8000/api/poses';

// For phone on same network (replace with your IP)
static const String baseUrl = 'http://192.168.1.XXX:8000/api/poses';
```

### Camera Permissions
Already configured in:
- `android/app/src/main/AndroidManifest.xml` (Android)
- `ios/Runner/Info.plist` (iOS - needs manual edit)

## 🐛 Troubleshooting

### Backend won't start
```bash
# Check Python dependencies
source env/bin/activate
pip install django djangorestframework opencv-python mediapipe numpy
```

### Camera not working
- Check permissions in phone settings
- Ensure manifest has camera permissions
- Try different camera (front/back)

### Connection refused
- Phone and computer on same WiFi?
- Correct IP in pose_service.dart?
- Firewall blocking port 8000?

See **[PHONE_SETUP_GUIDE.md](PHONE_SETUP_GUIDE.md)** for detailed troubleshooting.

## 📚 Documentation

- [Running Guide](RUNNING_GUIDE.md) - Complete setup and running instructions
- [Phone Setup Guide](PHONE_SETUP_GUIDE.md) - Detailed phone integration guide
- [Physio README](Physio/README.md) - Standalone pose detection info

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is open source and available under the MIT License.

## 👥 Authors

- Nishan Shrestha ([@nishanshrestha04](https://github.com/nishanshrestha04))

## 🙏 Acknowledgments

- **MediaPipe** - Google's ML solutions
- **Flutter** - Google's UI toolkit
- **Django** - Python web framework

---

**Made with ❤️ for yoga enthusiasts**

For support or questions, please open an issue on GitHub.
