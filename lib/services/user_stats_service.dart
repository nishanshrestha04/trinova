import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// User Statistics Model
/// Stores all user yoga practice statistics
class UserStats {
  int totalSessions;
  int totalMinutes;
  int currentStreak;
  int longestStreak;
  DateTime? lastSessionDate;
  Map<String, int> poseCounts; // Track count per pose

  UserStats({
    this.totalSessions = 0,
    this.totalMinutes = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastSessionDate,
    Map<String, int>? poseCounts,
  }) : poseCounts = poseCounts ?? {};

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalSessions: json['total_sessions'] ?? 0,
      totalMinutes: json['total_minutes'] ?? 0,
      currentStreak: json['current_streak'] ?? 0,
      longestStreak: json['longest_streak'] ?? 0,
      lastSessionDate: json['last_session_date'] != null
          ? DateTime.parse(json['last_session_date'])
          : null,
      poseCounts: Map<String, int>.from(json['pose_counts'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'total_sessions': totalSessions,
      'total_minutes': totalMinutes,
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'last_session_date': lastSessionDate?.toIso8601String(),
      'pose_counts': poseCounts,
    };
  }
}

/// User Statistics Service
/// Manages user statistics storage via backend API
///
/// IMPORTANT: Statistics are synced with backend for cross-device access
/// - Stats are fetched from server on load
/// - Changes are immediately synced to backend
/// - Falls back to local storage if offline
/// - Different users have separate statistics on server
class UserStatsService {
  static const String _baseUrl = 'http://192.168.18.6:8000/api';
  static const String _statsKeyPrefix = 'user_stats_';

  // Get user-specific stats key for local cache
  String _getUserStatsKey(int userId) {
    return '$_statsKeyPrefix$userId';
  }

  // Get auth token
  Future<String?> _getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('access_token');
    } catch (e) {
      return null;
    }
  }

  // Refresh access token using refresh token
  Future<bool> _refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');

      if (refreshToken == null) {
        return false;
      }

      final response = await http
          .post(
            Uri.parse('$_baseUrl/auth/token/refresh/'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'refresh': refreshToken}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newAccessToken = data['access'];

        // Store new access token
        await prefs.setString('access_token', newAccessToken);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  // Get user ID
  Future<int?> _getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString('user_data');
      if (userData != null) {
        final Map<String, dynamic> data = json.decode(userData);
        return data['id'];
      }
    } catch (e) {
      // Silent error handling
    }
    return null;
  }

  // Load stats from backend API (with local cache fallback)
  Future<UserStats> loadStats({int? userId}) async {
    try {
      var token = await _getAuthToken();
      final uid = userId ?? await _getUserId();

      if (token == null || uid == null) {
        return UserStats(); // Return empty stats if not authenticated
      }

      // Try to fetch from server
      try {
        var response = await http
            .get(
              Uri.parse('$_baseUrl/stats/'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
            )
            .timeout(const Duration(seconds: 10));

        // If token expired, try to refresh and retry once
        if (response.statusCode == 401) {
          final refreshed = await _refreshToken();

          if (refreshed) {
            token = await _getAuthToken();
            response = await http
                .get(
                  Uri.parse('$_baseUrl/stats/'),
                  headers: {
                    'Authorization': 'Bearer $token',
                    'Content-Type': 'application/json',
                  },
                )
                .timeout(const Duration(seconds: 10));
          } else {
            return await _loadLocalStats(uid);
          }
        }

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true && data['stats'] != null) {
            final stats = UserStats.fromJson(data['stats']);
            // Cache locally
            await _saveLocalStats(stats, uid);
            return stats;
          }
        }
      } catch (e) {
        // Silent error, fallback to local cache
      }

      // Fallback to local cache
      return await _loadLocalStats(uid);
    } catch (e) {
      return UserStats();
    }
  }

  // Load from local storage (cache)
  Future<UserStats> _loadLocalStats(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsKey = _getUserStatsKey(userId);
      final statsJson = prefs.getString(statsKey);

      if (statsJson != null) {
        final Map<String, dynamic> data = json.decode(statsJson);
        return UserStats.fromJson(data);
      }
    } catch (e) {
      // Silent error handling
    }
    return UserStats();
  }

  // Save to local storage (cache)
  Future<void> _saveLocalStats(UserStats stats, int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsKey = _getUserStatsKey(userId);
      final statsJson = json.encode(stats.toJson());
      await prefs.setString(statsKey, statsJson);
    } catch (e) {
      // Silent error handling
    }
  }

  // Save stats - deprecated, stats are now updated via specific actions
  Future<void> saveStats(UserStats stats, {int? userId}) async {
    // This method is kept for backwards compatibility but does nothing
    // Stats are now updated via recordSession and updateDailyStreak
  }

  // Record a completed session (syncs to backend)
  Future<UserStats> recordSession({
    required int durationMinutes,
    required List<String> posesCompleted,
    int? userId,
  }) async {
    try {
      var token = await _getAuthToken();
      final uid = userId ?? await _getUserId();

      if (token == null || uid == null) {
        return UserStats();
      }

      // Send to backend
      var response = await http
          .post(
            Uri.parse('$_baseUrl/session/'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'duration_minutes': durationMinutes,
              'poses_completed': posesCompleted,
            }),
          )
          .timeout(const Duration(seconds: 10));

      // If token expired, try to refresh and retry once
      if (response.statusCode == 401) {
        final refreshed = await _refreshToken();

        if (refreshed) {
          token = await _getAuthToken();
          response = await http
              .post(
                Uri.parse('$_baseUrl/session/'),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                },
                body: json.encode({
                  'duration_minutes': durationMinutes,
                  'poses_completed': posesCompleted,
                }),
              )
              .timeout(const Duration(seconds: 10));
        } else {
          return UserStats();
        }
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['stats'] != null) {
          final stats = UserStats.fromJson(data['stats']);
          // Cache locally
          await _saveLocalStats(stats, uid);
          return stats;
        }
      }
    } catch (e) {
      // Silent error handling
    }

    // Return current stats on failure
    return await loadStats(userId: userId);
  }

  // Update daily streak when user completes at least one pose
  Future<UserStats> updateDailyStreak({
    int? userId,
    String? poseName,
    int? durationMinutes,
  }) async {
    try {
      var token = await _getAuthToken();
      final uid = userId ?? await _getUserId();

      if (token == null || uid == null) {
        return UserStats();
      }

      // Prepare request body
      final body = <String, dynamic>{};
      if (poseName != null) body['pose_name'] = poseName;
      if (durationMinutes != null) body['duration_minutes'] = durationMinutes;

      // Send to backend
      var response = await http
          .post(
            Uri.parse('$_baseUrl/streak/'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 10));

      // If token expired, try to refresh and retry once
      if (response.statusCode == 401) {
        final refreshed = await _refreshToken();

        if (refreshed) {
          token = await _getAuthToken();
          response = await http
              .post(
                Uri.parse('$_baseUrl/streak/'),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                },
                body: json.encode(body),
              )
              .timeout(const Duration(seconds: 10));
        } else {
          return UserStats();
        }
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['stats'] != null) {
          final stats = UserStats.fromJson(data['stats']);
          // Cache locally
          await _saveLocalStats(stats, uid);
          return stats;
        }
      }
    } catch (e) {
      // Silent error handling
    }

    // Return current stats on failure
    return await loadStats(userId: userId);
  }

  // Get today's stats
  Future<Map<String, int>> getTodayStats({int? userId}) async {
    final stats = await loadStats(userId: userId);
    final now = DateTime.now();

    if (stats.lastSessionDate == null) {
      return {'sessions': 0, 'minutes': 0};
    }

    final isToday =
        stats.lastSessionDate!.year == now.year &&
        stats.lastSessionDate!.month == now.month &&
        stats.lastSessionDate!.day == now.day;

    if (isToday) {
      return {'sessions': 1, 'minutes': stats.totalMinutes};
    }

    return {'sessions': 0, 'minutes': 0};
  }

  // Clear stats for specific user (clears local cache only)
  Future<void> clearStats({int? userId}) async {
    try {
      final uid = userId ?? await _getUserId();
      if (uid != null) {
        final prefs = await SharedPreferences.getInstance();
        final statsKey = _getUserStatsKey(uid);
        await prefs.remove(statsKey);
      }
    } catch (e) {
      // Silent error handling
    }
  }

  // Clear all local stats cache (admin/debug only)
  Future<void> clearAllStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      for (final key in keys) {
        if (key.startsWith(_statsKeyPrefix)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
      // Silent error handling
    }
  }
}
