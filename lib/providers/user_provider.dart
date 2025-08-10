import 'package:flutter/material.dart';
import 'package:tennis_connect/models/user_model.dart';
import 'package:tennis_connect/services/auth_service.dart';
import 'package:tennis_connect/services/mock_auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProvider extends ChangeNotifier {
  UserModel? _currentUser;
  final AuthService _authService = AuthService();

  UserModel? get currentUser => _currentUser;

  // Load current user data
  Future<void> loadCurrentUser() async {
    // Check if using mock auth
    if (MockAuthService.useMockAuth) {
      final mockUserData = MockAuthService.getCurrentUserData();
      if (mockUserData != null) {
        _currentUser = UserModel(
          id: mockUserData['id'],
          email: mockUserData['email'],
          displayName: mockUserData['displayName'],
          photoUrl: mockUserData['photoUrl'],
          ntrpRating: mockUserData['ntrpRating'],
          playingStyle: mockUserData['playingStyle'],
          preferredCourtSurfaces: List<String>.from(mockUserData['preferredCourtSurfaces']),
          availability: Map<String, bool>.from(mockUserData['availability']),
          preferredPlayingTimes: List<String>.from(mockUserData['preferredPlayingTimes']),
          city: mockUserData['city'],
          state: mockUserData['state'],
          location: mockUserData['location'],
          reliabilityScore: mockUserData['reliabilityScore'],
          matchesPlayed: mockUserData['matchesPlayed'],
          matchesWon: mockUserData['matchesWon'],
          createdAt: mockUserData['createdAt'],
          lastActive: mockUserData['lastActive'],
          isPremium: mockUserData['isPremium'],
          savedCourts: List<String>.from(mockUserData['savedCourts']),
          blockedUsers: List<String>.from(mockUserData['blockedUsers']),
        );
        notifyListeners();
      }
      return;
    }
    
    // Normal Firebase auth
    final firebaseUser = _authService.currentUser;
    if (firebaseUser != null) {
      _currentUser = await _authService.getUserData(firebaseUser.uid);
      notifyListeners();
    }
  }

  // Update current user
  void updateCurrentUser(UserModel user) {
    _currentUser = user;
    notifyListeners();
  }

  // Clear user data (on logout)
  void clearUser() {
    _currentUser = null;
    notifyListeners();
  }

  // Update specific user fields
  Future<void> updateUserField(String field, dynamic value) async {
    if (_currentUser != null) {
      await _authService.updateUserProfile(
        _currentUser!.id,
        {field: value},
      );
      await loadCurrentUser(); // Reload user data
    }
  }
}