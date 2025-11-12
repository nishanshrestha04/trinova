import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class PoseService {
  // Change this to your computer's IP address when testing on phone
  // Find your IP: Linux: `ip addr show` or `hostname -I`
  // Updated: Using your computer's IP for network access
  static const String baseUrl = 'http://192.168.1.109:8000/api/poses';

  // For localhost testing (Chrome on same computer):
  // static const String baseUrl = 'http://localhost:8000/api/poses';

  /// Get list of available yoga poses
  static Future<List<Map<String, dynamic>>> getAvailablePoses() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/available/'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['poses']);
      } else {
        throw Exception('Failed to load poses: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching poses: $e');
    }
  }

  /// Analyze a pose image
  /// [poseName] should be 'tree', 'cobra', or 'warrior'
  /// [imageBytes] should be the image as bytes
  static Future<Map<String, dynamic>> analyzePoseImage(
    String poseName,
    Uint8List imageBytes,
  ) async {
    try {
      // Convert image to base64
      String base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse('$baseUrl/analyze/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'pose': poseName, 'image': base64Image}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Analysis failed');
      }
    } catch (e) {
      throw Exception('Error analyzing pose: $e');
    }
  }

  /// Get tips for a specific pose
  static Future<Map<String, dynamic>> getPoseTips(String poseName) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tips/$poseName/'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['tips'];
      } else {
        throw Exception('Failed to load tips: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching tips: $e');
    }
  }
}
