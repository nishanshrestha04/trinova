# 🔧 Quick Fix Applied!

## ✅ Problem Solved

**Issue**: Connection refused to localhost
**Solution**: Updated to use your computer's IP address

---

## 📝 What Was Changed

**File**: `lib/services/pose_service.dart`

**Before**:
```dart
static const String baseUrl = 'http://localhost:8000/api/poses';
```

**After**:
```dart
static const String baseUrl = 'http://192.168.18.6:8000/api/poses';
```

---

## 🚀 Next Steps

### **IMPORTANT: Restart Your Flutter App**

If your app is currently running, you need to **restart it** (not hot reload) for the changes to take effect:

#### **Option 1: In Terminal**
Press `r` for hot restart, or `R` for full restart

#### **Option 2: Stop and Restart**
1. Press `q` to quit the current app
2. Run again:
   ```bash
   flutter run -d chrome
   # OR for phone:
   flutter run
   ```

#### **Option 3: VS Code**
- Click the restart button (🔄) in the debug toolbar
- Or press `Ctrl+Shift+F5` (full restart)

---

## ✅ Verify It Works

After restarting:

1. **Open the app**
2. **Go to Poses tab** (2nd icon)
3. **Tap "Start Practice"** on any pose
4. **Take a photo** with camera
5. **Should now analyze successfully!** 🎉

---

## 🔍 Test Backend Connection

You can verify the backend is accessible:

```bash
# Test from terminal:
curl http://192.168.18.6:8000/api/poses/available/

# Should see JSON with 3 poses: tree, cobra, warrior
```

---

## 📱 Important Notes

### **Your Computer's IP**: `192.168.18.6`

This IP works when:
- ✅ Testing on Chrome on the same computer
- ✅ Testing on your phone (on same WiFi network)
- ✅ Backend is running with: `python manage.py runserver 0.0.0.0:8000`

### **If IP Changes**

If you restart your router or computer, your IP might change. To check:
```bash
hostname -I
```

Then update `lib/services/pose_service.dart` with the new IP.

---

## 🐛 If Still Not Working

### 1. **Check Backend is Running**
```bash
# Should see Django server logs
cd /home/nishanshrestha/Documents/YogAI/trinova/backend
python manage.py runserver 0.0.0.0:8000
```

### 2. **Check Firewall**
```bash
# Allow port 8000:
sudo ufw allow 8000
```

### 3. **Verify Same WiFi Network**
- Computer and phone must be on the SAME WiFi
- Turn off VPN if active

### 4. **Check Flutter App Restarted**
- Make sure you did FULL restart (not just hot reload)
- The baseUrl change requires restart

---

## 💡 Alternative URLs

### **For Testing on Same Computer (Chrome)**
```dart
// This works ONLY when running on the same computer
static const String baseUrl = 'http://localhost:8000/api/poses';
```

### **For Testing on Phone/Different Device**
```dart
// Use computer's IP address (current setting)
static const String baseUrl = 'http://192.168.18.6:8000/api/poses';
```

### **For Production (Future)**
```dart
// Deploy backend and use public URL
static const String baseUrl = 'https://your-app.herokuapp.com/api/poses';
```

---

## ✨ Summary

✅ **Fixed**: Updated IP address from `localhost` to `192.168.18.6`
✅ **Backend**: Verified it's running and accessible
✅ **Next**: Restart your Flutter app to apply changes

**You should now be able to analyze poses without connection errors!** 🎉

---

**Need more help?** 
Check the terminal where your backend is running for any error messages.
