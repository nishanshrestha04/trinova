import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/google_auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final GoogleAuthService _googleAuthService = GoogleAuthService();

  User? _user;
  bool _isLoading = false;
  bool _isLoggedIn = false;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;

  AuthProvider() {
    _checkAuthStatus();
  }

  // Check if user is already logged in
  Future<void> _checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    _isLoggedIn = await _authService.isLoggedIn();
    if (_isLoggedIn) {
      _user = await _authService.getStoredUser();
    }

    _isLoading = false;
    notifyListeners();
  }

  // Register new user
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    String firstName = '',
    String lastName = '',
  }) async {
    _isLoading = true;
    notifyListeners();

    final result = await _authService.register(
      username: username,
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
    );

    if (result['success']) {
      _user = result['user'];
      _isLoggedIn = true;
    }

    _isLoading = false;
    notifyListeners();

    return result;
  }

  // Login user
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    final result = await _authService.login(
      username: username,
      password: password,
    );

    if (result['success']) {
      _user = result['user'];
      _isLoggedIn = true;
    }

    _isLoading = false;
    notifyListeners();

    return result;
  }

  // Logout user
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    await _authService.logout();
    await _googleAuthService.signOut(); // Also sign out from Google

    _user = null;
    _isLoggedIn = false;
    _isLoading = false;

    notifyListeners();
  }

  // Sign in with Google
  Future<Map<String, dynamic>> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    final result = await _googleAuthService.signInWithGoogle();

    if (result['success']) {
      _user = result['user'];
      _isLoggedIn = true;
    }

    _isLoading = false;
    notifyListeners();

    return result;
  }

  // Refresh user profile
  Future<void> refreshProfile() async {
    if (!_isLoggedIn) return;

    final result = await _authService.getProfile();
    if (result['success']) {
      _user = result['user'];
      notifyListeners();
    }
  }
}
