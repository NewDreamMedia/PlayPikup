import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tennis_connect/models/match_challenge_model.dart';
import 'package:tennis_connect/models/match_model.dart';
import 'package:tennis_connect/models/user_model.dart';
import 'package:tennis_connect/services/location_service.dart';

class MatchChallengeService {
  static final MatchChallengeService _instance = MatchChallengeService._internal();
  factory MatchChallengeService() => _instance;
  MatchChallengeService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocationService _locationService = LocationService();

  // Create a new match challenge
  Future<String> createChallenge({
    required String challengedId,
    required String challengedName,
    String? courtId,
    String? courtName,
    String? courtAddress,
    GeoPoint? courtLocation,
    DateTime? proposedDate,
    String? proposedTime,
    int duration = 60,
    MatchType matchType = MatchType.singles,
    MatchFormat matchFormat = MatchFormat.bestOf3,
    String? message,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not authenticated');

      // Get current user data
      final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      final userData = UserModel.fromFirestore(userDoc);

      // Get challenged user data to calculate distance
      final challengedDoc = await _firestore.collection('users').doc(challengedId).get();
      final challengedData = UserModel.fromFirestore(challengedDoc);

      // Calculate distance between players
      final distanceInMeters = _locationService.calculateDistance(
        userData.location.latitude,
        userData.location.longitude,
        challengedData.location.latitude,
        challengedData.location.longitude,
      );
      final distanceInMiles = distanceInMeters / 1609.34;

      // Create challenge
      final challenge = MatchChallengeModel(
        id: '',
        challengerId: currentUser.uid,
        challengerName: userData.displayName,
        challengerPhotoUrl: userData.photoUrl ?? '',
        challengerNtrpRating: userData.ntrpRating,
        challengedId: challengedId,
        challengedName: challengedName,
        courtId: courtId,
        courtName: courtName,
        courtAddress: courtAddress,
        courtLocation: courtLocation,
        proposedDate: proposedDate,
        proposedTime: proposedTime,
        duration: duration,
        matchType: matchType,
        matchFormat: matchFormat,
        status: ChallengeStatus.pending,
        message: message,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 3)), // Expires in 3 days
        distanceInMiles: distanceInMiles,
      );

      final docRef = await _firestore.collection('match_challenges').add(
        challenge.toFirestore(),
      );

      // Send notification to challenged player
      await _sendChallengeNotification(challengedId, userData.displayName);

      return docRef.id;
    } catch (e) {
      print('Error creating challenge: $e');
      throw e;
    }
  }

  // Get challenges for current user (both sent and received)
  Stream<List<MatchChallengeModel>> getUserChallenges() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('match_challenges')
        .where(Filter.or(
          Filter('challengerId', isEqualTo: currentUserId),
          Filter('challengedId', isEqualTo: currentUserId),
        ))
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MatchChallengeModel.fromFirestore(doc))
            .toList());
  }

  // Get pending challenges for current user
  Stream<List<MatchChallengeModel>> getPendingChallenges() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return Stream.value([]);

    return _firestore
        .collection('match_challenges')
        .where('challengedId', isEqualTo: currentUserId)
        .where('status', isEqualTo: ChallengeStatus.pending.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MatchChallengeModel.fromFirestore(doc))
            .where((challenge) => !challenge.isExpired)
            .toList());
  }

  // Accept a challenge
  Future<void> acceptChallenge({
    required String challengeId,
    String? responseMessage,
  }) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) throw Exception('User not authenticated');

      // Get challenge data
      final challengeDoc = await _firestore
          .collection('match_challenges')
          .doc(challengeId)
          .get();
      
      if (!challengeDoc.exists) throw Exception('Challenge not found');
      
      final challenge = MatchChallengeModel.fromFirestore(challengeDoc);
      
      // Check if current user is the challenged player
      if (challenge.challengedId != currentUserId) {
        throw Exception('Unauthorized to accept this challenge');
      }

      // Check if challenge is expired
      if (challenge.isExpired) {
        throw Exception('Challenge has expired');
      }

      // Update challenge status
      await _firestore.collection('match_challenges').doc(challengeId).update({
        'status': ChallengeStatus.accepted.name,
        'responseMessage': responseMessage,
        'respondedAt': FieldValue.serverTimestamp(),
      });

      // Create a match from the challenge
      if (challenge.proposedDate != null && challenge.courtId != null) {
        await _createMatchFromChallenge(challenge);
      }

      // Send notification to challenger
      await _sendAcceptanceNotification(challenge.challengerId, challenge.challengedName);
    } catch (e) {
      print('Error accepting challenge: $e');
      throw e;
    }
  }

  // Reject a challenge
  Future<void> rejectChallenge({
    required String challengeId,
    String? responseMessage,
  }) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) throw Exception('User not authenticated');

      await _firestore.collection('match_challenges').doc(challengeId).update({
        'status': ChallengeStatus.rejected.name,
        'responseMessage': responseMessage,
        'respondedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error rejecting challenge: $e');
      throw e;
    }
  }

  // Cancel a challenge
  Future<void> cancelChallenge(String challengeId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) throw Exception('User not authenticated');

      await _firestore.collection('match_challenges').doc(challengeId).update({
        'status': ChallengeStatus.cancelled.name,
      });
    } catch (e) {
      print('Error cancelling challenge: $e');
      throw e;
    }
  }

  // Create a match from accepted challenge
  Future<void> _createMatchFromChallenge(MatchChallengeModel challenge) async {
    try {
      final match = MatchModel(
        id: '',
        creatorId: challenge.challengerId,
        creatorName: challenge.challengerName,
        playerIds: [challenge.challengerId, challenge.challengedId],
        courtId: challenge.courtId!,
        courtName: challenge.courtName!,
        courtAddress: challenge.courtAddress!,
        courtLocation: challenge.courtLocation!,
        matchDate: challenge.proposedDate!,
        matchTime: challenge.proposedTime!,
        duration: challenge.duration ?? 60,
        matchType: challenge.matchType,
        matchFormat: challenge.matchFormat,
        minNtrpRating: 1.0,
        maxNtrpRating: 7.0,
        maxDistance: 50.0,
        status: MatchStatus.confirmed,
        playerConfirmations: {
          challenge.challengerId: true,
          challenge.challengedId: true,
        },
        invitedPlayerIds: [],
        isPublic: false,
        notes: 'Match created from challenge',
        createdAt: DateTime.now(),
      );

      await _firestore.collection('matches').add(match.toFirestore());
    } catch (e) {
      print('Error creating match from challenge: $e');
    }
  }

  // Send notifications (placeholder - implement with FCM)
  Future<void> _sendChallengeNotification(String userId, String challengerName) async {
    // TODO: Implement with Firebase Cloud Messaging
    print('Sending challenge notification to $userId from $challengerName');
  }

  Future<void> _sendAcceptanceNotification(String userId, String accepterName) async {
    // TODO: Implement with Firebase Cloud Messaging
    print('Sending acceptance notification to $userId from $accepterName');
  }

  // Check if user can challenge another user
  Future<bool> canChallengeUser(String targetUserId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return false;

      // Check for existing pending challenges between users
      final existingChallenges = await _firestore
          .collection('match_challenges')
          .where(Filter.or(
            Filter.and(
              Filter('challengerId', isEqualTo: currentUserId),
              Filter('challengedId', isEqualTo: targetUserId),
            ),
            Filter.and(
              Filter('challengerId', isEqualTo: targetUserId),
              Filter('challengedId', isEqualTo: currentUserId),
            ),
          ))
          .where('status', isEqualTo: ChallengeStatus.pending.name)
          .get();

      return existingChallenges.docs.isEmpty;
    } catch (e) {
      print('Error checking challenge eligibility: $e');
      return false;
    }
  }
}