import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class GoogleAuthService {
  static const String baseUrl = 'http://192.168.1.109:8000/api/auth';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Web Client ID for backend token verification
    serverClientId:
        '834581145049-91fb4igjbc1gf8gn2edbutjpl97vnaea.apps.googleusercontent.com',
  );

  // Sign in with Google
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      print('Starting Google Sign-In...'); // Debug

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        print('User canceled Google Sign-In'); // Debug
        return {'success': false, 'message': 'Sign in cancelled'};
      }

      print('Google user selected: ${googleUser.email}'); // Debug

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      print(
        'Access Token: ${googleAuth.accessToken != null ? "Present" : "Missing"}',
      ); // Debug
      print(
        'ID Token: ${googleAuth.idToken != null ? "Present" : "Missing"}',
      ); // Debug

      // Get the ID token
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        print('Failed to get ID token'); // Debug
        print(
          'This usually means OAuth Client ID is not properly configured',
        ); // Debug
        print(
          'Make sure you have created an Android OAuth Client with correct SHA-1',
        ); // Debug
        print(
          'Or add a Web OAuth Client ID as serverClientId in GoogleSignIn configuration',
        ); // Debug
        return {
          'success': false,
          'message':
              'Failed to get Google ID token. Please check OAuth configuration.',
        };
      }

      print('Got ID token, sending to backend...'); // Debug

      // Send the ID token to your Django backend
      final response = await http.post(
        Uri.parse('$baseUrl/google-login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_token': idToken,
          'email': googleUser.email,
          'display_name': googleUser.displayName,
          'photo_url': googleUser.photoUrl,
        }),
      );

      print('Backend response status: ${response.statusCode}'); // Debug
      print('Backend response body: ${response.body}'); // Debug

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Login successful
        print('Login successful!'); // Debug
        final user = User.fromJson(data['user']);
        await _storeTokens(data['access_token'], data['refresh_token']);
        await _storeUserData(user);

        return {
          'success': true,
          'message': data['message'] ?? 'Login successful',
          'user': user,
        };
      } else {
        print('Backend returned error: ${data['error']}'); // Debug
        return {
          'success': false,
          'message': data['error'] ?? 'Google sign in failed',
        };
      }
    } catch (e) {
      print('Exception during Google Sign-In: $e'); // Debug
      return {'success': false, 'message': 'Error: ${e.toString()}'};
    }
  }

  // Sign out from Google
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }

  // Check if user is currently signed in with Google
  Future<bool> isSignedIn() async {
    return await _googleSignIn.isSignedIn();
  }

  // Store tokens
  Future<void> _storeTokens(String accessToken, String refreshToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }

  // Store user data
  Future<void> _storeUserData(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(user.toJson()));
  }
}
