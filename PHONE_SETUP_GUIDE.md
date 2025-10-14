# YogAI Phone Integration Guide 📱

## Complete Setup for Pose Detection on Your Phone

This guide will help you integrate the Python pose detection backend with your Flutter app so you can use it on your phone.

---

## 🚀 Quick Setup (3 Steps)

### Step 1: Install Dependencies

```bash
cd /home/nishanshrestha/Documents/YogAI/trinova

# Install Flutter dependencies
flutter pub get

# Install Python dependencies in backend environment
source env/bin/activate
cd backend
pip install opencv-python mediapipe numpy
```

### Step 2: Start Backend Server

```bash
# Terminal 1: Start Django backend
cd /home/nishanshrestha/Documents/YogAI/trinova/backend
source ../env/bin/activate
python manage.py runserver 0.0.0.0:8000
```

**Important**: Use `0.0.0.0:8000` to make the server accessible from your phone on the same network!

### Step 3: Configure Flutter App for Your Network

#### Find Your Computer's IP Address:

```bash
# On Linux:
hostname -I

# Or:
ip addr show | grep "inet " | grep -v 127.0.0.1

# Example output: 192.168.1.105
```

#### Update Flutter App:

Edit `/home/nishanshrestha/Documents/YogAI/trinova/lib/services/pose_service.dart`:

```dart
// Change line 8 from:
static const String baseUrl = 'http://localhost:8000/api/poses';

// To your computer's IP (example):
static const String baseUrl = 'http://192.168.1.105:8000/api/poses';
```

**Replace `192.168.1.105` with YOUR computer's actual IP address!**

---

## 📱 Running on Your Phone

### Option 1: Android Phone (Recommended)

```bash
# 1. Connect your Android phone via USB
# 2. Enable Developer Options and USB Debugging on phone
# 3. Check phone is detected:
flutter devices

# 4. Run the app:
flutter run
```

### Option 2: iPhone

```bash
# 1. Connect iPhone via USB
# 2. Trust the computer on iPhone
# 3. Check device is detected:
flutter devices

# 4. Run the app:
flutter run
```

### Option 3: Test on Computer First

```bash
# For Chrome (easier for testing):
flutter run -d chrome

# For Linux desktop:
flutter run -d linux
```

---

## 🎯 How to Use the App

1. **Start the Backend** (must be running first!)
   ```bash
   cd backend
   source ../env/bin/activate
   python manage.py runserver 0.0.0.0:8000
   ```

2. **Launch the App** on your phone or computer
   ```bash
   flutter run
   ```

3. **Login/Register** in the app

4. **Go to Poses Tab** (second icon in bottom navigation)

5. **Choose a Pose** (Tree, Cobra, or Warrior II)

6. **Click "Start Practice"** button

7. **Use the Camera**:
   - **Camera Button** (center): Take a picture and analyze
   - **Gallery Button** (left): Pick an existing photo
   - **Tips Button** (right): View pose instructions

8. **Get Real-time Feedback**:
   - ✅ Score percentage
   - 📝 Pose corrections
   - 💡 Improvement tips

---

## 🔧 Troubleshooting

### Problem: "Failed to connect to backend"

**Solution 1**: Check if backend is running
```bash
# Test backend is running:
curl http://localhost:8000/api/poses/available/

# Should return JSON with poses
```

**Solution 2**: Check firewall
```bash
# Allow port 8000 through firewall:
sudo ufw allow 8000
```

**Solution 3**: Verify IP address in Flutter app
- Make sure you updated `pose_service.dart` with correct IP
- Phone and computer must be on same WiFi network

### Problem: Camera not working

**Solution**: Add permissions to Android/iOS

**For Android** - Edit `android/app/src/main/AndroidManifest.xml`:
```xml
<manifest>
    <!-- Add these permissions -->
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-feature android:name="android.hardware.camera"/>
    <uses-feature android:name="android.hardware.camera.autofocus"/>
    
    <application>
        ...
    </application>
</manifest>
```

**For iOS** - Edit `ios/Runner/Info.plist`:
```xml
<dict>
    <!-- Add these keys -->
    <key>NSCameraUsageDescription</key>
    <string>We need camera access for yoga pose detection</string>
    <key>NSPhotoLibraryUsageDescription</key>
    <string>We need photo library access to analyze your poses</string>
    ...
</dict>
```

### Problem: "No person detected"

**Solutions**:
- Ensure good lighting
- Stand 6-8 feet from camera
- Make sure full body is visible in frame
- Try different camera angles

### Problem: Backend errors in analysis

**Solution**: Check Python dependencies
```bash
cd /home/nishanshrestha/Documents/YogAI/trinova
source env/bin/activate
pip list | grep -E "opencv|mediapipe|numpy"

# If missing, reinstall:
pip install opencv-python mediapipe numpy
```

---

## 📡 Network Requirements

### Same WiFi Network
- ✅ Phone and computer must be on **same WiFi network**
- ✅ No VPN should be active
- ✅ Firewall should allow port 8000

### Check Connection
```bash
# From your computer, test the API:
curl http://localhost:8000/api/poses/available/

# From your phone browser, test (replace with your IP):
http://192.168.1.105:8000/api/poses/available/
```

---

## 🎨 Features

### Available Yoga Poses:
1. **Tree Pose (Vrikshasana)** 🌳
   - Difficulty: Beginner
   - Benefits: Balance, leg strength, focus

2. **Cobra Pose (Bhujangasana)** 🐍
   - Difficulty: Beginner
   - Benefits: Spine strength, chest opening, posture

3. **Warrior II (Virabhadrasana II)** ⚔️
   - Difficulty: Intermediate
   - Benefits: Leg strength, stamina, hip flexibility

### AI-Powered Analysis:
- ✅ Real-time pose detection using MediaPipe
- ✅ Accurate scoring (0-100%)
- ✅ Detailed feedback and corrections
- ✅ Support for camera or gallery photos

---

## 📝 API Endpoints

Your backend provides these endpoints:

```
GET  /api/poses/available/          - List all poses
POST /api/poses/analyze/            - Analyze pose image
GET  /api/poses/tips/<pose_name>/   - Get pose tips
```

### Test API:
```bash
# Get available poses:
curl http://localhost:8000/api/poses/available/

# Get tips for tree pose:
curl http://localhost:8000/api/poses/tips/tree/
```

---

## 🔐 Security Notes

**For Development**: Current setup is fine
**For Production**: You should:
1. Use HTTPS instead of HTTP
2. Add authentication to pose endpoints
3. Use environment variables for API URLs
4. Deploy backend to cloud (e.g., Heroku, AWS, DigitalOcean)

---

## 🌐 Deployment (Future)

### Deploy Backend to Cloud:
1. **Heroku**: Free tier available
2. **DigitalOcean**: $5/month droplet
3. **AWS EC2**: Free tier for 1 year
4. **Google Cloud**: Free tier available

Once deployed, update `pose_service.dart`:
```dart
static const String baseUrl = 'https://your-app.herokuapp.com/api/poses';
```

---

## 📊 Performance Tips

1. **Image Size**: App automatically resizes to medium quality for faster upload
2. **Network**: Use WiFi for best performance
3. **Lighting**: Natural light works best
4. **Distance**: Stand 6-8 feet from camera

---

## 🆘 Still Having Issues?

1. **Check Backend Logs**:
   ```bash
   # Watch backend logs for errors:
   cd backend
   python manage.py runserver
   ```

2. **Check Flutter Logs**:
   ```bash
   # Watch app logs:
   flutter logs
   ```

3. **Test Each Component**:
   - ✅ Backend running?
   - ✅ Phone on same network?
   - ✅ Correct IP in pose_service.dart?
   - ✅ Camera permissions granted?

---

## 📚 Additional Resources

- **Flutter Camera**: https://pub.dev/packages/camera
- **MediaPipe Pose**: https://google.github.io/mediapipe/solutions/pose
- **Django REST**: https://www.django-rest-framework.org/

---

**Happy Practicing! 🧘‍♀️✨**

For questions or issues, check the backend terminal for error messages.
