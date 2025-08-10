import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tennis_connect/models/user_model.dart';

/// Mock auth service for testing when Firebase is unreachable
class MockAuthService {
  static bool _useMockAuth = false;
  static Map<String, Map<String, dynamic>> _mockUsers = {};
  static String? _currentUserId;

  static bool get useMockAuth => _useMockAuth;
  
  static void enableMockMode() {
    _useMockAuth = true;
    print('Mock auth mode enabled - using local authentication');
  }

  static void disableMockMode() {
    _useMockAuth = false;
    print('Mock auth mode disabled - using Firebase authentication');
  }

  static Future<UserCredential?> mockSignUp({
    required String email,
    required String password,
    required String displayName,
    required double ntrpRating,
    required String city,
    required String state,
    required double latitude,
    required double longitude,
  }) async {
    print('Mock signup called for: $email');
    
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));
    
    // Check if user already exists
    if (_mockUsers.containsKey(email)) {
      throw 'An account already exists for that email.';
    }
    
    // Create mock user
    final userId = 'mock_${DateTime.now().millisecondsSinceEpoch}';
    _mockUsers[email] = {
      'id': userId,
      'email': email,
      'displayName': displayName,
      'ntrpRating': ntrpRating,
      'playingStyle': 'all-court',
      'preferredCourtSurfaces': ['Hard Court'],
      'availability': {
        'monday': false,
        'tuesday': false,
        'wednesday': false,
        'thursday': false,
        'friday': false,
        'saturday': true,
        'sunday': true,
      },
      'preferredPlayingTimes': ['Morning (8-11 AM)'],
      'city': city,
      'state': state,
      'location': GeoPoint(latitude, longitude),
      'reliabilityScore': 5.0,
      'matchesPlayed': 0,
      'matchesWon': 0,
      'createdAt': DateTime.now(),
      'lastActive': DateTime.now(),
      'isPremium': false,
      'savedCourts': [],
      'blockedUsers': [],
    };
    
    _currentUserId = userId;
    print('Mock user created successfully: $userId');
    
    // Return null as we can't create a real UserCredential
    return null;
  }

  static Future<UserCredential?> mockSignIn({
    required String email,
    required String password,
  }) async {
    print('Mock signin called for: $email');
    
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Check if user exists
    if (!_mockUsers.containsKey(email)) {
      throw 'No user found for that email.';
    }
    
    final userData = _mockUsers[email]!;
    _currentUserId = userData['id'];
    
    // Update last active
    userData['lastActive'] = DateTime.now();
    
    print('Mock signin successful: ${userData['id']}');
    return null;
  }

  static String? getCurrentUserId() {
    return _currentUserId;
  }

  static Map<String, dynamic>? getCurrentUserData() {
    if (_currentUserId == null) return null;
    
    for (final userData in _mockUsers.values) {
      if (userData['id'] == _currentUserId) {
        return userData;
      }
    }
    return null;
  }

  static void signOut() {
    _currentUserId = null;
    print('Mock user signed out');
  }

  // Add some test users
  static void addTestUsers() {
    _mockUsers['test@example.com'] = {
      'id': 'test_user_1',
      'email': 'test@example.com',
      'displayName': 'Test User',
      'ntrpRating': 3.5,
      'playingStyle': 'all-court',
      'preferredCourtSurfaces': ['Hard Court'],
      'availability': {
        'monday': true,
        'tuesday': true,
        'wednesday': true,
        'thursday': true,
        'friday': true,
        'saturday': true,
        'sunday': true,
      },
      'preferredPlayingTimes': ['Morning (8-11 AM)', 'Evening (5-8 PM)'],
      'city': 'San Francisco',
      'state': 'CA',
      'location': const GeoPoint(37.7749, -122.4194),
      'reliabilityScore': 4.8,
      'matchesPlayed': 25,
      'matchesWon': 15,
      'createdAt': DateTime.now().subtract(const Duration(days: 30)),
      'lastActive': DateTime.now(),
      'isPremium': false,
      'savedCourts': [],
      'blockedUsers': [],
    };
  }
}