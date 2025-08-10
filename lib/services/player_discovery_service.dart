import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tennis_connect/models/user_model.dart';
import 'package:tennis_connect/services/location_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Player match scoring model
class PlayerMatch {
  final UserModel player;
  final double distance; // in km
  final double matchScore;
  final Map<String, double> scoreBreakdown;

  PlayerMatch({
    required this.player,
    required this.distance,
    required this.matchScore,
    required this.scoreBreakdown,
  });
}

class PlayerDiscoveryService {
  static final PlayerDiscoveryService _instance = PlayerDiscoveryService._internal();
  factory PlayerDiscoveryService() => _instance;
  PlayerDiscoveryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get nearby players within specified radius (in meters)
  Future<List<UserModel>> getNearbyPlayers({
    required double latitude,
    required double longitude,
    double radiusInMiles = 5.0,
    String? skillLevel,
    List<String>? availableDays,
    List<String>? preferredTimes,
  }) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return [];

      // Convert miles to meters for distance calculation
      final radiusInMeters = radiusInMiles * 1609.34;

      // Get all users from Firestore
      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('id', isNotEqualTo: currentUserId)
          .get();

      final List<UserModel> allPlayers = [];
      
      for (final doc in snapshot.docs) {
        try {
          final user = UserModel.fromFirestore(doc);
          
          // Check if user is blocked
          if (user.blockedUsers.contains(currentUserId)) continue;
          
          // Calculate distance
          final distance = _locationService.calculateDistance(
            latitude,
            longitude,
            user.location.latitude,
            user.location.longitude,
          );

          // Filter by distance
          if (distance <= radiusInMeters) {
            // Filter by skill level if specified
            if (skillLevel != null) {
              final skillRange = _getSkillRange(skillLevel);
              if (user.ntrpRating < skillRange['min']! || 
                  user.ntrpRating > skillRange['max']!) {
                continue;
              }
            }

            // Filter by availability if specified
            if (availableDays != null && availableDays.isNotEmpty) {
              bool hasMatchingDay = false;
              for (final day in availableDays) {
                if (user.availability[day] == true) {
                  hasMatchingDay = true;
                  break;
                }
              }
              if (!hasMatchingDay) continue;
            }

            // Filter by preferred times if specified
            if (preferredTimes != null && preferredTimes.isNotEmpty) {
              bool hasMatchingTime = false;
              for (final time in preferredTimes) {
                if (user.preferredPlayingTimes.contains(time)) {
                  hasMatchingTime = true;
                  break;
                }
              }
              if (!hasMatchingTime) continue;
            }

            // Add distance to user object for display
            allPlayers.add(UserModel(
              id: user.id,
              email: user.email,
              displayName: user.displayName,
              photoUrl: user.photoUrl,
              ntrpRating: user.ntrpRating,
              playingStyle: user.playingStyle,
              preferredCourtSurfaces: user.preferredCourtSurfaces,
              availability: user.availability,
              preferredPlayingTimes: user.preferredPlayingTimes,
              city: user.city,
              state: user.state,
              location: user.location,
              reliabilityScore: user.reliabilityScore,
              matchesPlayed: user.matchesPlayed,
              matchesWon: user.matchesWon,
              createdAt: user.createdAt,
              lastActive: user.lastActive,
              isPremium: user.isPremium,
              savedCourts: user.savedCourts,
              blockedUsers: user.blockedUsers,
            ));
          }
        } catch (e) {
          print('Error processing user: $e');
          continue;
        }
      }

      // Sort by distance (closest first)
      allPlayers.sort((a, b) {
        final distA = _locationService.calculateDistance(
          latitude, longitude, a.location.latitude, a.location.longitude);
        final distB = _locationService.calculateDistance(
          latitude, longitude, b.location.latitude, b.location.longitude);
        return distA.compareTo(distB);
      });

      return allPlayers;
    } catch (e) {
      print('Error getting nearby players: $e');
      return [];
    }
  }

  // Get nearby players based on current location
  Future<List<UserModel>> getNearbyPlayersByCurrentLocation({
    double radiusInMiles = 5.0,
    String? skillLevel,
    List<String>? availableDays,
    List<String>? preferredTimes,
  }) async {
    final position = await _locationService.getCurrentLocation();
    if (position == null) {
      throw Exception('Unable to get current location');
    }

    return getNearbyPlayers(
      latitude: position.latitude,
      longitude: position.longitude,
      radiusInMiles: radiusInMiles,
      skillLevel: skillLevel,
      availableDays: availableDays,
      preferredTimes: preferredTimes,
    );
  }

  // Update user location
  Future<void> updateUserLocation({
    required String userId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'location': GeoPoint(latitude, longitude),
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating user location: $e');
      throw e;
    }
  }

  // Get skill level range for filtering
  Map<String, double> _getSkillRange(String skillLevel) {
    switch (skillLevel) {
      case 'beginner':
        return {'min': 1.0, 'max': 2.5};
      case 'intermediate':
        return {'min': 3.0, 'max': 4.0};
      case 'advanced':
        return {'min': 4.5, 'max': 5.0};
      case 'expert':
        return {'min': 5.5, 'max': 7.0};
      default:
        return {'min': 1.0, 'max': 7.0};
    }
  }

  // Check if a player is available now
  bool isPlayerAvailableNow(UserModel player) {
    final now = DateTime.now();
    final dayOfWeek = _getDayName(now.weekday);
    final timeOfDay = _getTimeOfDay(now.hour);

    return player.availability[dayOfWeek] == true &&
           player.preferredPlayingTimes.contains(timeOfDay);
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'monday';
      case 2: return 'tuesday';
      case 3: return 'wednesday';
      case 4: return 'thursday';
      case 5: return 'friday';
      case 6: return 'saturday';
      case 7: return 'sunday';
      default: return 'monday';
    }
  }

  String _getTimeOfDay(int hour) {
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  // Smart player matching with weighted scoring algorithm
  Future<List<PlayerMatch>> getSmartPlayerMatches({
    required UserModel currentUser,
    double radiusInMiles = 10.0,
    double skillWeight = 0.5,
    double proximityWeight = 0.3,
    double availabilityWeight = 0.2,
  }) async {
    try {
      // Validate weights sum to 1.0
      final totalWeight = skillWeight + proximityWeight + availabilityWeight;
      if ((totalWeight - 1.0).abs() > 0.01) {
        throw ArgumentError('Weights must sum to 1.0');
      }

      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return [];

      // Get current location
      final position = await _locationService.getCurrentLocation();
      if (position == null) {
        throw Exception('Unable to get current location');
      }

      // Convert miles to km for consistency
      final radiusInKm = radiusInMiles * 1.60934;

      // Get all potential players
      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .where('isProfilePublic', isEqualTo: true)
          .where('id', isNotEqualTo: currentUserId)
          .get();

      final List<PlayerMatch> playerMatches = [];

      for (final doc in snapshot.docs) {
        try {
          final player = UserModel.fromFirestore(doc);
          
          // Skip blocked users
          if (player.blockedUsers.contains(currentUserId) || 
              currentUser.blockedUsers.contains(player.id)) {
            continue;
          }

          // Calculate distance
          final distanceInMeters = _locationService.calculateDistance(
            position.latitude,
            position.longitude,
            player.location.latitude,
            player.location.longitude,
          );
          final distanceInKm = distanceInMeters / 1000;

          // Skip if outside radius
          if (distanceInKm > radiusInKm) continue;

          // Calculate match scores
          final skillScore = _calculateSkillScore(currentUser, player);
          final proximityScore = _calculateProximityScore(distanceInKm, radiusInKm);
          final availabilityScore = _calculateAvailabilityScore(currentUser, player);

          // Calculate weighted total score
          final totalScore = (skillScore * skillWeight) +
                           (proximityScore * proximityWeight) +
                           (availabilityScore * availabilityWeight);

          playerMatches.add(PlayerMatch(
            player: player,
            distance: distanceInKm,
            matchScore: totalScore,
            scoreBreakdown: {
              'skill': skillScore,
              'proximity': proximityScore,
              'availability': availabilityScore,
            },
          ));
        } catch (e) {
          print('Error processing player: $e');
          continue;
        }
      }

      // Sort by match score (highest first)
      playerMatches.sort((a, b) => b.matchScore.compareTo(a.matchScore));

      return playerMatches;
    } catch (e) {
      print('Error getting smart player matches: $e');
      return [];
    }
  }

  // Calculate skill compatibility score (0-1)
  double _calculateSkillScore(UserModel user1, UserModel user2) {
    final skillDiff = (user1.ntrpRating - user2.ntrpRating).abs();
    
    // Perfect match: same skill level
    if (skillDiff == 0) return 1.0;
    
    // Good match: within 0.5 NTRP points
    if (skillDiff <= 0.5) return 0.9;
    
    // Acceptable match: within 1.0 NTRP points
    if (skillDiff <= 1.0) return 0.7;
    
    // Fair match: within 1.5 NTRP points
    if (skillDiff <= 1.5) return 0.5;
    
    // Poor match: more than 1.5 NTRP points apart
    return 0.3 - (skillDiff - 1.5) * 0.1;
  }

  // Calculate proximity score (0-1)
  double _calculateProximityScore(double distanceKm, double maxDistanceKm) {
    if (distanceKm <= 0) return 1.0;
    
    // Linear decay: closer = higher score
    final score = 1.0 - (distanceKm / maxDistanceKm);
    return score.clamp(0.0, 1.0);
  }

  // Calculate availability overlap score (0-1)
  double _calculateAvailabilityScore(UserModel user1, UserModel user2) {
    double score = 0.0;
    int totalFactors = 0;

    // Check day availability overlap
    int matchingDays = 0;
    int totalDays = 0;
    user1.availability.forEach((day, isAvailable) {
      if (isAvailable) {
        totalDays++;
        if (user2.availability[day] == true) {
          matchingDays++;
        }
      }
    });
    
    if (totalDays > 0) {
      score += matchingDays / totalDays;
      totalFactors++;
    }

    // Check time preference overlap
    int matchingTimes = 0;
    for (final time in user1.preferredPlayingTimes) {
      if (user2.preferredPlayingTimes.contains(time)) {
        matchingTimes++;
      }
    }
    
    if (user1.preferredPlayingTimes.isNotEmpty) {
      score += matchingTimes / user1.preferredPlayingTimes.length;
      totalFactors++;
    }

    // Check court surface preference overlap
    int matchingSurfaces = 0;
    for (final surface in user1.preferredCourtSurfaces) {
      if (user2.preferredCourtSurfaces.contains(surface)) {
        matchingSurfaces++;
      }
    }
    
    if (user1.preferredCourtSurfaces.isNotEmpty) {
      score += matchingSurfaces / user1.preferredCourtSurfaces.length * 0.5; // Weight surface preference less
      totalFactors++;
    }

    // Average the scores
    return totalFactors > 0 ? score / totalFactors : 0.0;
  }

  // Quick match: Find best match for immediate play
  Future<PlayerMatch?> findQuickMatch({
    required UserModel currentUser,
    double maxDistanceKm = 5.0,
  }) async {
    try {
      // Get matches with adjusted weights for quick play
      final matches = await getSmartPlayerMatches(
        currentUser: currentUser,
        radiusInMiles: maxDistanceKm / 1.60934,
        skillWeight: 0.4,        // Skill still important
        proximityWeight: 0.4,    // Proximity very important for quick match
        availabilityWeight: 0.2, // Current availability important
      );

      // Filter for players available now
      final now = DateTime.now();
      final currentDay = _getDayName(now.weekday);
      final currentTime = _getTimeOfDay(now.hour);

      final availableNowMatches = matches.where((match) {
        return match.player.availability[currentDay] == true &&
               match.player.preferredPlayingTimes.contains(currentTime) &&
               match.matchScore >= 0.6; // Minimum match quality threshold
      }).toList();

      // Return best match if available
      return availableNowMatches.isNotEmpty ? availableNowMatches.first : null;
    } catch (e) {
      print('Error finding quick match: $e');
      return null;
    }
  }
}