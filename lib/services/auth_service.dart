import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import 'package:http_parser/http_parser.dart';

class AuthService {
  static const String baseUrl = 'http://192.168.1.109:8000/api/auth';

  // Get stored tokens
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('refresh_token');
  }

  // Store tokens
  Future<void> _storeTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  // Clear tokens
  Future<void> _clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_data');
  }

  // Store user data
  Future<void> _storeUserData(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(user.toJson()));
  }

  // Get stored user data
  Future<User?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_data');
    if (userData != null) {
      return User.fromJson(jsonDecode(userData));
    }
    return null;
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final accessToken = await getAccessToken();
    return accessToken != null;
  }

  // Register new user
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    String firstName = '',
    String lastName = '',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'first_name': firstName,
          'last_name': lastName,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Registration successful
        final user = User.fromJson(data['user']);
        await _storeTokens(data['access_token'], data['refresh_token']);
        await _storeUserData(user);

        return {'success': true, 'message': data['message'], 'user': user};
      } else {
        // Registration failed
        return {
          'success': false,
          'message': data['error'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: Please check your internet connection',
      };
    }
  }

  // Login user
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Login successful
        final user = User.fromJson(data['user']);
        await _storeTokens(data['access_token'], data['refresh_token']);
        await _storeUserData(user);

        return {'success': true, 'message': data['message'], 'user': user};
      } else if (response.statusCode == 401) {
        // Invalid credentials
        return {
          'success': false,
          'message':
              'Invalid username or password. Please check your credentials and try again.',
        };
      } else {
        // Other login errors
        return {
          'success': false,
          'message': data['error'] ?? 'Login failed. Please try again.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message':
            'Network error. Please check your internet connection and try again.',
      };
    }
  }

  // Logout user
  Future<Map<String, dynamic>> logout() async {
    try {
      final refreshToken = await getRefreshToken();

      if (refreshToken != null) {
        await http.post(
          Uri.parse('$baseUrl/logout/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${await getAccessToken()}',
          },
          body: jsonEncode({'refresh_token': refreshToken}),
        );
      }

      await _clearTokens();

      return {'success': true, 'message': 'Logged out successfully'};
    } catch (e) {
      // Clear tokens even if the API call fails
      await _clearTokens();
      return {'success': true, 'message': 'Logged out successfully'};
    }
  }

  // Get user profile
  Future<Map<String, dynamic>> getProfile() async {
    try {
      final accessToken = await getAccessToken();

      if (accessToken == null) {
        return {'success': false, 'message': 'No access token found'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/profile/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final user = User.fromJson(data['user']);
        await _storeUserData(user);

        return {'success': true, 'user': user};
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Failed to get profile',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Network error: Please check your internet connection',
      };
    }
  }

  // Update user profile
  Future<Map<String, dynamic>> updateProfile({
    required String firstName,
    required String lastName,
    required String username,
    File? profilePicture,
  }) async {
    try {
      final accessToken = await getAccessToken();

      if (accessToken == null) {
        return {'success': false, 'message': 'No access token found'};
      }

      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/profile/update/'),
      );

      // Add headers
      request.headers['Authorization'] = 'Bearer $accessToken';

      // Add text fields
      request.fields['first_name'] = firstName;
      request.fields['last_name'] = lastName;
      request.fields['username'] = username;

      // Add profile picture if provided
      if (profilePicture != null) {
        var pic = await http.MultipartFile.fromPath(
          'profile_picture',
          profilePicture.path,
          contentType: MediaType('image', 'jpeg'),
        );
        request.files.add(pic);
      }

      // Send request
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final user = User.fromJson(data['user']);
        await _storeUserData(user);

        return {
          'success': true,
          'message': data['message'] ?? 'Profile updated successfully',
          'user': user,
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Failed to update profile',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }
}
