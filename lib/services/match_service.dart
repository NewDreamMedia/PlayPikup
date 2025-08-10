import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tennis_connect/models/match_model.dart';
import 'package:tennis_connect/models/user_model.dart';
import 'package:tennis_connect/services/location_service.dart';

class MatchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();
  
  static const String _matchesCollection = 'matches';
  static const String _usersCollection = 'users';

  // Create a new match
  Future<String> createMatch(MatchModel match) async {
    try {
      final docRef = await _firestore.collection(_matchesCollection).add(
        match.toFirestore()
      );
      return docRef.id;
    } catch (e) {
      print('Error creating match: $e');
      throw Exception('Failed to create match');
    }
  }

  // Update an existing match
  Future<void> updateMatch(String matchId, Map<String, dynamic> updates) async {
    try {
      updates['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection(_matchesCollection).doc(matchId).update(updates);
    } catch (e) {
      print('Error updating match: $e');
      throw Exception('Failed to update match');
    }
  }

  // Join a match
  Future<void> joinMatch(String matchId, String userId) async {
    try {
      final matchDoc = await _firestore.collection(_matchesCollection).doc(matchId).get();
      if (!matchDoc.exists) throw Exception('Match not found');
      
      final match = MatchModel.fromFirestore(matchDoc);
      
      // Check if match is full
      if (match.isFull) {
        throw Exception('Match is already full');
      }
      
      // Check if user already joined
      if (match.playerIds.contains(userId)) {
        throw Exception('You have already joined this match');
      }
      
      // Add user to match
      await _firestore.collection(_matchesCollection).doc(matchId).update({
        'playerIds': FieldValue.arrayUnion([userId]),
        'playerConfirmations.$userId': true,
        'status': match.playerIds.length + 1 >= (match.matchType == MatchType.singles ? 2 : 4) 
            ? MatchStatus.full.name 
            : match.status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error joining match: $e');
      throw e;
    }
  }

  // Leave a match
  Future<void> leaveMatch(String matchId, String userId) async {
    try {
      final matchDoc = await _firestore.collection(_matchesCollection).doc(matchId).get();
      if (!matchDoc.exists) throw Exception('Match not found');
      
      final match = MatchModel.fromFirestore(matchDoc);
      
      // Can't leave if you're the creator
      if (match.creatorId == userId) {
        throw Exception('Creator cannot leave the match. Cancel it instead.');
      }
      
      // Remove user from match
      await _firestore.collection(_matchesCollection).doc(matchId).update({
        'playerIds': FieldValue.arrayRemove([userId]),
        'playerConfirmations.$userId': FieldValue.delete(),
        'status': MatchStatus.open.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error leaving match: $e');
      throw e;
    }
  }

  // Cancel a match (only creator can cancel)
  Future<void> cancelMatch(String matchId, String userId, {String? reason}) async {
    try {
      final matchDoc = await _firestore.collection(_matchesCollection).doc(matchId).get();
      if (!matchDoc.exists) throw Exception('Match not found');
      
      final match = MatchModel.fromFirestore(matchDoc);
      
      if (match.creatorId != userId) {
        throw Exception('Only the creator can cancel the match');
      }
      
      final updates = {
        'status': MatchStatus.cancelled.name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (reason != null && reason.isNotEmpty) {
        updates['cancelReason'] = reason;
      }
      
      await _firestore.collection(_matchesCollection).doc(matchId).update(updates);
      
      // TODO: Send notifications to all participants about cancellation
    } catch (e) {
      print('Error cancelling match: $e');
      throw e;
    }
  }
  
  // Edit match details (only creator can edit)
  Future<void> editMatch(String matchId, String userId, Map<String, dynamic> updates) async {
    try {
      final matchDoc = await _firestore.collection(_matchesCollection).doc(matchId).get();
      if (!matchDoc.exists) throw Exception('Match not found');
      
      final match = MatchModel.fromFirestore(matchDoc);
      
      if (match.creatorId != userId) {
        throw Exception('Only the creator can edit the match');
      }
      
      // Add timestamp
      updates['updatedAt'] = FieldValue.serverTimestamp();
      
      await _firestore.collection(_matchesCollection).doc(matchId).update(updates);
      
      // TODO: Send notifications to participants about changes
    } catch (e) {
      print('Error editing match: $e');
      throw e;
    }
  }
  
  // Toggle substitute needed status
  Future<void> toggleSubstituteNeeded(String matchId, String userId, bool needed, {String? reason}) async {
    try {
      final matchDoc = await _firestore.collection(_matchesCollection).doc(matchId).get();
      if (!matchDoc.exists) throw Exception('Match not found');
      
      final match = MatchModel.fromFirestore(matchDoc);
      
      if (match.creatorId != userId) {
        throw Exception('Only the creator can toggle substitute status');
      }
      
      final updates = {
        'subNeeded': needed,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      if (needed && reason != null && reason.isNotEmpty) {
        updates['subNeededReason'] = reason;
      } else if (!needed) {
        updates['subNeededReason'] = FieldValue.delete();
      }
      
      await _firestore.collection(_matchesCollection).doc(matchId).update(updates);
      
      // TODO: Notify users with matching subAvailability
    } catch (e) {
      print('Error toggling substitute status: $e');
      throw e;
    }
  }
  
  // Add participant to match (only creator can add)
  Future<void> addParticipant(String matchId, String creatorId, String participantId) async {
    try {
      final matchDoc = await _firestore.collection(_matchesCollection).doc(matchId).get();
      if (!matchDoc.exists) throw Exception('Match not found');
      
      final match = MatchModel.fromFirestore(matchDoc);
      
      if (match.creatorId != creatorId) {
        throw Exception('Only the creator can add participants');
      }
      
      if (match.isFull) {
        throw Exception('Match is already full');
      }
      
      if (match.playerIds.contains(participantId)) {
        throw Exception('User is already in the match');
      }
      
      await _firestore.collection(_matchesCollection).doc(matchId).update({
        'playerIds': FieldValue.arrayUnion([participantId]),
        'playerConfirmations.$participantId': true,
        'status': match.playerIds.length + 1 >= (match.matchType == MatchType.singles ? 2 : 4) 
            ? MatchStatus.full.name 
            : match.status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // TODO: Send notification to added participant
    } catch (e) {
      print('Error adding participant: $e');
      throw e;
    }
  }
  
  // Remove participant from match (only creator can remove)
  Future<void> removeParticipant(String matchId, String creatorId, String participantId, {String? reason}) async {
    try {
      final matchDoc = await _firestore.collection(_matchesCollection).doc(matchId).get();
      if (!matchDoc.exists) throw Exception('Match not found');
      
      final match = MatchModel.fromFirestore(matchDoc);
      
      if (match.creatorId != creatorId) {
        throw Exception('Only the creator can remove participants');
      }
      
      if (participantId == creatorId) {
        throw Exception('Creator cannot remove themselves');
      }
      
      if (!match.playerIds.contains(participantId)) {
        throw Exception('User is not in the match');
      }
      
      await _firestore.collection(_matchesCollection).doc(matchId).update({
        'playerIds': FieldValue.arrayRemove([participantId]),
        'playerConfirmations.$participantId': FieldValue.delete(),
        'status': MatchStatus.open.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // TODO: Send notification to removed participant with reason
    } catch (e) {
      print('Error removing participant: $e');
      throw e;
    }
  }
  
  // Send reminder to all participants (only creator can send)
  Future<void> sendMatchReminder(String matchId, String creatorId, String message) async {
    try {
      final matchDoc = await _firestore.collection(_matchesCollection).doc(matchId).get();
      if (!matchDoc.exists) throw Exception('Match not found');
      
      final match = MatchModel.fromFirestore(matchDoc);
      
      if (match.creatorId != creatorId) {
        throw Exception('Only the creator can send reminders');
      }
      
      // Store reminder in a notifications collection (to be implemented with FCM)
      final reminder = {
        'matchId': matchId,
        'message': message,
        'sentBy': creatorId,
        'sentAt': FieldValue.serverTimestamp(),
        'recipients': match.playerIds.where((id) => id != creatorId).toList(),
        'type': 'match_reminder',
      };
      
      await _firestore.collection('notifications').add(reminder);
      
      // TODO: Trigger FCM push notifications to all participants
      
      final recipients = reminder['recipients'] as List;
      print('Reminder sent to ${recipients.length} participants');
    } catch (e) {
      print('Error sending reminder: $e');
      throw e;
    }
  }
  
  // Update match score and outcome
  Future<void> updateMatchScore(
    String matchId,
    List<String> setScores,
    String? winnerId,
    Map<String, MatchOutcome> outcomes,
  ) async {
    try {
      final updates = {
        'setScores': setScores,
        'winnerId': winnerId,
        'playerOutcomes': outcomes.map((key, value) => MapEntry(key, value.name)),
        'status': MatchStatus.completed.name,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      
      await _firestore.collection(_matchesCollection).doc(matchId).update(updates);
      
      // Update user match history
      for (final entry in outcomes.entries) {
        await _updateUserMatchHistory(entry.key, matchId, entry.value);
      }
    } catch (e) {
      print('Error updating match score: $e');
      throw e;
    }
  }
  
  // Update user's match history
  Future<void> _updateUserMatchHistory(String userId, String matchId, MatchOutcome outcome) async {
    try {
      final userDoc = await _firestore.collection(_usersCollection).doc(userId).get();
      if (!userDoc.exists) return;
      
      final userData = userDoc.data()!;
      final matchHistory = List<Map<String, dynamic>>.from(userData['matchHistory'] ?? []);
      
      // Add or update match in history
      final matchIndex = matchHistory.indexWhere((m) => m['matchId'] == matchId);
      final historyEntry = {
        'matchId': matchId,
        'outcome': outcome.name,
        'date': FieldValue.serverTimestamp(),
      };
      
      if (matchIndex >= 0) {
        matchHistory[matchIndex] = historyEntry;
      } else {
        matchHistory.add(historyEntry);
      }
      
      // Update win/loss stats
      int wins = userData['totalWins'] ?? 0;
      int losses = userData['totalLosses'] ?? 0;
      
      if (outcome == MatchOutcome.win) wins++;
      if (outcome == MatchOutcome.loss) losses++;
      
      await _firestore.collection(_usersCollection).doc(userId).update({
        'matchHistory': matchHistory,
        'totalWins': wins,
        'totalLosses': losses,
        'lastMatchDate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user match history: $e');
      // Don't throw - this is not critical
    }
  }
  
  // Get match status display text
  String getMatchStatusText(MatchModel match) {
    final spotsAvailable = match.spotsAvailable;
    final totalSpots = match.matchType == MatchType.singles ? 2 : 4;
    
    switch (match.status) {
      case MatchStatus.open:
        return 'Open: ${match.playerIds.length}/$totalSpots players';
      case MatchStatus.full:
        return 'Full';
      case MatchStatus.confirmed:
        return 'Confirmed';
      case MatchStatus.inProgress:
        return 'In Progress';
      case MatchStatus.completed:
        return 'Completed';
      case MatchStatus.cancelled:
        return match.cancelReason != null 
          ? 'Cancelled: ${match.cancelReason}'
          : 'Cancelled';
    }
  }

  // Get matches for a specific user
  Stream<List<MatchModel>> getUserMatches(String userId) {
    return _firestore
        .collection(_matchesCollection)
        .where('playerIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          // Filter in memory until index is created
          final matches = snapshot.docs
              .map((doc) => MatchModel.fromFirestore(doc))
              .where((match) => [
                    MatchStatus.open.name,
                    MatchStatus.full.name,
                    MatchStatus.confirmed.name,
                    MatchStatus.inProgress.name,
                  ].contains(match.status.name))
              .toList();
          
          // Sort by date
          matches.sort((a, b) => a.matchDate.compareTo(b.matchDate));
          
          return matches;
        });
  }

  // Get available matches based on user location and skill
  Future<List<MatchModel>> getAvailableMatches({
    required String userId,
    required double userLat,
    required double userLng,
    required double userSkillLevel,
    double? maxDistance,
    MatchType? matchType,
  }) async {
    try {
      // Query all matches first, then filter
      // This avoids index requirements
      final querySnapshot = await _firestore
          .collection(_matchesCollection)
          .get();
      
      print('[MatchService] Total matches in database: ${querySnapshot.docs.length}');
      
      // Filter matches based on criteria
      final List<MatchModel> filteredMatches = [];
      final now = DateTime.now();
      
      int publicCount = 0;
      int openCount = 0;
      int futureCount = 0;
      int skillMatchCount = 0;
      
      for (final doc in querySnapshot.docs) {
        final match = MatchModel.fromFirestore(doc);
        
        // Check if public
        if (!match.isPublic) {
          print('[MatchService] Match ${match.id} is not public');
          continue;
        }
        publicCount++;
        
        // Check status
        if (match.status != MatchStatus.open) {
          print('[MatchService] Match ${match.id} status is ${match.status.name}, not open');
          continue;
        }
        openCount++;
        
        // Check if match is upcoming (compare just dates, not time)
        final matchDateOnly = DateTime(match.matchDate.year, match.matchDate.month, match.matchDate.day);
        final todayDateOnly = DateTime(now.year, now.month, now.day);
        if (matchDateOnly.isBefore(todayDateOnly)) {
          print('[MatchService] Match ${match.id} date ${match.matchDate} is in the past');
          continue;
        }
        futureCount++;
        
        // Check match type if specified
        if (matchType != null && match.matchType != matchType) {
          continue;
        }
        
        // Skip if user already joined
        if (match.playerIds.contains(userId)) {
          continue;
        }
        
        // Check skill level
        if (!match.canJoinBySkill(userSkillLevel)) {
          print('[MatchService] Match ${match.id} skill range ${match.minNtrpRating}-${match.maxNtrpRating} does not match user skill ${userSkillLevel}');
          continue;
        }
        skillMatchCount++;
        
        // Calculate distance in miles
        final distanceMeters = _locationService.calculateDistance(
          userLat,
          userLng,
          match.courtLocation.latitude,
          match.courtLocation.longitude,
        );
        
        // Convert to miles
        final distanceMiles = distanceMeters / 1609.34;
        
        // Check distance constraint (both maxDistance and match.maxDistance are in miles)
        if (maxDistance != null && distanceMiles > maxDistance) {
          continue;
        }
        
        // Note: match.maxDistance is stored in km in the model, so convert
        final matchMaxDistanceMiles = match.maxDistance * 0.621371;
        if (distanceMiles > matchMaxDistanceMiles) {
          continue;
        }
        
        filteredMatches.add(match);
      }
      
      print('[MatchService] Filter summary:');
      print('  - Public matches: $publicCount');
      print('  - Open status: $openCount');
      print('  - Future matches: $futureCount');
      print('  - Skill match: $skillMatchCount');
      print('  - Final filtered: ${filteredMatches.length}');
      
      // Sort by date
      filteredMatches.sort((a, b) => a.matchDate.compareTo(b.matchDate));
      
      return filteredMatches;
    } catch (e) {
      print('Error getting available matches: $e');
      return [];
    }
  }

  // Get a single match by ID
  Future<MatchModel?> getMatch(String matchId) async {
    try {
      final doc = await _firestore.collection(_matchesCollection).doc(matchId).get();
      if (doc.exists) {
        return MatchModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting match: $e');
      return null;
    }
  }

  // Stream a single match
  Stream<MatchModel?> streamMatch(String matchId) {
    return _firestore
        .collection(_matchesCollection)
        .doc(matchId)
        .snapshots()
        .map((doc) => doc.exists ? MatchModel.fromFirestore(doc) : null);
  }

  // Find potential players for a match
  Future<List<UserModel>> findPotentialPlayers({
    required String matchId,
    required MatchModel match,
  }) async {
    try {
      // Get all users within skill range
      final usersQuery = await _firestore
          .collection(_usersCollection)
          .where('ntrpRating', isGreaterThanOrEqualTo: match.minNtrpRating)
          .where('ntrpRating', isLessThanOrEqualTo: match.maxNtrpRating)
          .get();
      
      final List<UserModel> potentialPlayers = [];
      
      for (final doc in usersQuery.docs) {
        final user = UserModel.fromFirestore(doc);
        
        // Skip if already in match
        if (match.playerIds.contains(user.id)) continue;
        
        // Calculate distance
        final distance = _locationService.calculateDistance(
          match.courtLocation.latitude,
          match.courtLocation.longitude,
          user.location.latitude,
          user.location.longitude,
        );
        
        // Convert to km
        final distanceKm = distance / 1000;
        
        // Check if within distance limit
        if (distanceKm <= match.maxDistance) {
          potentialPlayers.add(user);
        }
      }
      
      // Sort by distance (closest first)
      potentialPlayers.sort((a, b) {
        final distA = _locationService.calculateDistance(
          match.courtLocation.latitude,
          match.courtLocation.longitude,
          a.location.latitude,
          a.location.longitude,
        );
        final distB = _locationService.calculateDistance(
          match.courtLocation.latitude,
          match.courtLocation.longitude,
          b.location.latitude,
          b.location.longitude,
        );
        return distA.compareTo(distB);
      });
      
      return potentialPlayers;
    } catch (e) {
      print('Error finding potential players: $e');
      return [];
    }
  }

  // Request a substitute for a match
  Future<void> requestSubstitute({
    required String matchId,
    required String reason,
  }) async {
    try {
      await _firestore.collection(_matchesCollection).doc(matchId).update({
        'subNeeded': true,
        'subNeededReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to request substitute: $e');
    }
  }
  
  // Cancel substitute request
  Future<void> cancelSubstituteRequest(String matchId) async {
    try {
      await _firestore.collection(_matchesCollection).doc(matchId).update({
        'subNeeded': false,
        'subNeededReason': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Failed to cancel substitute request: $e');
    }
  }
  
  // Get matches needing substitutes
  Stream<List<MatchModel>> getSubstituteNeededMatches({
    required String userId,
    required double userLat,
    required double userLng,
    double maxDistance = 20.0, // miles
  }) {
    return _firestore
        .collection(_matchesCollection)
        .where('subNeeded', isEqualTo: true)
        .where('status', isEqualTo: MatchStatus.open.name)
        .snapshots()
        .map((snapshot) {
          final matches = snapshot.docs
              .map((doc) => MatchModel.fromFirestore(doc))
              .where((match) {
                // Don't show if user is already in match
                if (match.playerIds.contains(userId)) return false;
                
                // Calculate distance
                final distance = _locationService.calculateDistance(
                  userLat,
                  userLng,
                  match.courtLocation.latitude,
                  match.courtLocation.longitude,
                ) / 1609.34; // Convert to miles
                
                return distance <= maxDistance;
              })
              .toList();
          
          // Sort by match date (soonest first)
          matches.sort((a, b) => a.matchDate.compareTo(b.matchDate));
          
          return matches;
        });
  }

  // Get upcoming matches count for a user
  Future<int> getUpcomingMatchesCount(String userId) async {
    try {
      final query = await _firestore
          .collection(_matchesCollection)
          .where('playerIds', arrayContains: userId)
          .where('matchDate', isGreaterThan: Timestamp.now())
          .where('status', whereIn: [
            MatchStatus.open.name,
            MatchStatus.full.name,
            MatchStatus.confirmed.name,
          ])
          .count()
          .get();
      
      return query.count ?? 0;
    } catch (e) {
      print('Error getting upcoming matches count: $e');
      return 0;
    }
  }

  // Update match status
  Future<void> updateMatchStatus(String matchId, MatchStatus status) async {
    try {
      await _firestore.collection(_matchesCollection).doc(matchId).update({
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating match status: $e');
      throw e;
    }
  }

  // Complete a match and update user statistics
  Future<void> completeMatch({
    required String matchId,
    required Map<String, int> scores,
    required String winnerId,
    Map<String, double>? playerRatings,
  }) async {
    try {
      final matchDoc = await _firestore.collection(_matchesCollection).doc(matchId).get();
      if (!matchDoc.exists) throw Exception('Match not found');
      
      final match = MatchModel.fromFirestore(matchDoc);
      
      // Update match document
      await _firestore.collection(_matchesCollection).doc(matchId).update({
        'status': MatchStatus.completed.name,
        'scores': scores,
        'winnerId': winnerId,
        'playerRatings': playerRatings,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Update each player's statistics and match history
      for (final playerId in match.playerIds) {
        final outcome = playerId == winnerId ? MatchOutcome.win : MatchOutcome.loss;
        await _updateUserMatchHistory(playerId, matchId, outcome);
      }
    } catch (e) {
      print('Error completing match: $e');
      throw e;
    }
  }


  // Helper to get opponent name
  String _getOpponentName(MatchModel match, String userId) {
    // This is simplified - in real app, would fetch opponent's name
    return match.playerIds.firstWhere((id) => id != userId, orElse: () => 'Unknown');
  }

  // Helper to get opponent ID
  String _getOpponentId(MatchModel match, String userId) {
    return match.playerIds.firstWhere((id) => id != userId, orElse: () => '');
  }

  // Check and award achievements based on match completion
  Future<void> _checkAndAwardAchievements(String userId, UserModel user, bool isWinner) async {
    final newAchievements = <String>[];
    
    // First match achievement
    if (user.matchesPlayed == 0 && !user.achievements.contains('first_match')) {
      newAchievements.add('first_match');
    }
    
    // Milestone achievements
    final totalMatches = user.matchesPlayed + 1;
    if (totalMatches == 5 && !user.achievements.contains('5_matches')) {
      newAchievements.add('5_matches');
    } else if (totalMatches == 10 && !user.achievements.contains('10_matches')) {
      newAchievements.add('10_matches');
    } else if (totalMatches == 25 && !user.achievements.contains('25_matches')) {
      newAchievements.add('25_matches');
    } else if (totalMatches == 50 && !user.achievements.contains('50_matches')) {
      newAchievements.add('50_matches');
    }
    
    // Reliability achievement
    if (user.reliabilityScore >= 5.0 && !user.achievements.contains('reliable')) {
      newAchievements.add('reliable');
    }
    
    // Add new achievements to user
    if (newAchievements.isNotEmpty) {
      await _firestore.collection(_usersCollection).doc(userId).update({
        'achievements': FieldValue.arrayUnion(newAchievements),
      });
    }
  }
}