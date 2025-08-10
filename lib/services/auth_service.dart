import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tennis_connect/models/user_model.dart';
import 'package:tennis_connect/services/mock_auth_service.dart';
import 'package:tennis_connect/services/notification_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Auth state changes stream
  Stream<User?> get authStateChanges {
    if (MockAuthService.useMockAuth) {
      // Return a stream that emits mock auth state
      return Stream.value(null); // Will be handled by AuthWrapper
    }
    return _auth.authStateChanges();
  }

  // Current user
  User? get currentUser {
    if (MockAuthService.useMockAuth) {
      return null; // Mock auth doesn't have real User objects
    }
    return _auth.currentUser;
  }

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
    required double ntrpRating,
    required String city,
    required String state,
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Check if we should use mock auth (for testing when network is unavailable)
      if (MockAuthService.useMockAuth) {
        return await MockAuthService.mockSignUp(
          email: email,
          password: password,
          displayName: displayName,
          ntrpRating: ntrpRating,
          city: city,
          state: state,
          latitude: latitude,
          longitude: longitude,
        );
      }
      // Create user with email and password
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await userCredential.user!.updateDisplayName(displayName);

      // Create user document in Firestore
      final user = UserModel(
        id: userCredential.user!.uid,
        email: email,
        displayName: displayName,
        ntrpRating: ntrpRating,
        playingStyle: 'all-court',
        preferredCourtSurfaces: ['Hard Court'],
        availability: {
          'monday': false,
          'tuesday': false,
          'wednesday': false,
          'thursday': false,
          'friday': false,
          'saturday': true,
          'sunday': true,
        },
        preferredPlayingTimes: ['Morning (8-11 AM)'],
        city: city,
        state: state,
        location: GeoPoint(latitude, longitude),
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(user.toFirestore());

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      // Check if it's a network error
      if (e.toString().contains('Failed host lookup') || 
          e.toString().contains('SocketException') ||
          e.toString().contains('Network is unreachable')) {
        print('Network error detected, enabling mock auth mode');
        MockAuthService.enableMockMode();
        MockAuthService.addTestUsers(); // Add test users
        
        // Retry with mock auth
        return await MockAuthService.mockSignUp(
          email: email,
          password: password,
          displayName: displayName,
          ntrpRating: ntrpRating,
          city: city,
          state: state,
          latitude: latitude,
          longitude: longitude,
        );
      }
      throw e;
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update last active
      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .update({
        'lastActive': FieldValue.serverTimestamp(),
      });
      
      // Initialize notifications for the user
      await NotificationService().initialize();

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with Apple
  Future<UserCredential?> signInWithApple() async {
    try {
      // Generate nonce
      final rawNonce = _generateNonce();
      final nonce = sha256.convert(utf8.encode(rawNonce)).toString();

      // Request Apple ID credential
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      // Create OAuth credential
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      // Sign in with Firebase
      final userCredential = await _auth.signInWithCredential(oauthCredential);

      // Check if user document exists
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        // Create new user document
        final user = UserModel(
          id: userCredential.user!.uid,
          email: appleCredential.email ?? userCredential.user!.email ?? '',
          displayName: _buildFullName(
            appleCredential.givenName,
            appleCredential.familyName,
          ) ?? userCredential.user!.displayName ?? 'Tennis Player',
          ntrpRating: 3.5, // Default rating
          playingStyle: 'all-court',
          preferredCourtSurfaces: ['Hard Court'],
          availability: {
            'monday': false,
            'tuesday': false,
            'wednesday': false,
            'thursday': false,
            'friday': false,
            'saturday': true,
            'sunday': true,
          },
          preferredPlayingTimes: ['Morning (8-11 AM)'],
          city: '', // To be updated in profile
          state: '', // To be updated in profile
          location: const GeoPoint(0, 0), // To be updated in profile
          createdAt: DateTime.now(),
          lastActive: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(user.toFirestore());
      } else {
        // Update last active
        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .update({
          'lastActive': FieldValue.serverTimestamp(),
        });
      }

      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      throw _handleAppleSignInException(e);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An unexpected error occurred. Please try again.';
    }
  }

  // Generate a secure random nonce
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  // Build full name from given and family names
  String? _buildFullName(String? givenName, String? familyName) {
    if (givenName == null && familyName == null) return null;
    if (givenName == null) return familyName;
    if (familyName == null) return givenName;
    return '$givenName $familyName';
  }

  // Sign out
  Future<void> signOut() async {
    // Clear FCM token before signing out
    await NotificationService().clearToken();
    await _auth.signOut();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Get user data
  Future<UserModel?> getUserData(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    try {
      print('[AuthService] updateUserProfile called with userId: $userId');
      print('[AuthService] Update data: $data');
      
      // Check if user is authenticated
      final currentUser = _auth.currentUser;
      print('[AuthService] Current auth user: ${currentUser?.uid}');
      print('[AuthService] Is user authenticated: ${currentUser != null}');
      
      if (currentUser == null) {
        throw Exception('No authenticated user found');
      }
      
      if (currentUser.uid != userId) {
        throw Exception('User ID mismatch: auth=${currentUser.uid}, requested=$userId');
      }
      
      print('[AuthService] Executing Firestore update...');
      await _firestore
          .collection('users')
          .doc(userId)
          .update(data);
      print('[AuthService] Firestore update completed successfully');
    } catch (e) {
      print('[AuthService] Error updating user profile: $e');
      print('[AuthService] Error type: ${e.runtimeType}');
      throw e;
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      default:
        return 'An error occurred. Please try again.';
    }
  }

  // Handle Apple Sign In exceptions
  String _handleAppleSignInException(SignInWithAppleAuthorizationException e) {
    switch (e.code) {
      case AuthorizationErrorCode.canceled:
        return 'Sign in was canceled.';
      case AuthorizationErrorCode.failed:
        return 'Sign in failed. Please try again.';
      case AuthorizationErrorCode.invalidResponse:
        return 'Invalid response from Apple. Please try again.';
      case AuthorizationErrorCode.notHandled:
        return 'Sign in not handled. Please try again.';
      case AuthorizationErrorCode.notInteractive:
        return 'Sign in requires user interaction.';
      case AuthorizationErrorCode.unknown:
      default:
        return 'An unknown error occurred. Please try again.';
    }
  }
}