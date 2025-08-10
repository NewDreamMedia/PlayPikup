import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String? photoUrl;
  final double ntrpRating;
  final String playingStyle; // baseline, serve-and-volley, all-court
  final List<String> preferredCourtSurfaces; // hard, clay, grass, indoor
  final Map<String, bool> availability; // {'monday': true, 'tuesday': false, ...}
  final List<String> preferredPlayingTimes; // morning, afternoon, evening
  final String city;
  final String state;
  final GeoPoint location;
  final double reliabilityScore;
  final int matchesPlayed;
  final int matchesWon;
  final DateTime createdAt;
  final DateTime lastActive;
  final bool isPremium;
  final List<String> savedCourts;
  final List<String> blockedUsers;
  
  // New fields for PPU Profile
  final String skillLevel; // beginner, intermediate, advanced, or NTRP
  final List<String> preferredMatchTypes; // singles, doubles, both
  final double maxDistanceKm; // max distance willing to travel for matches
  final List<Map<String, dynamic>> weeklyAvailability; // detailed time slots
  final List<Map<String, dynamic>> matchHistory; // recent match records
  final bool isProfilePublic; // profile visibility setting
  final bool showLocation; // location privacy setting
  final bool showMatchHistory; // match history privacy setting
  final List<String> achievements; // achievement badge IDs

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.ntrpRating,
    required this.playingStyle,
    required this.preferredCourtSurfaces,
    required this.availability,
    required this.preferredPlayingTimes,
    required this.city,
    required this.state,
    required this.location,
    this.reliabilityScore = 5.0,
    this.matchesPlayed = 0,
    this.matchesWon = 0,
    required this.createdAt,
    required this.lastActive,
    this.isPremium = false,
    this.savedCourts = const [],
    this.blockedUsers = const [],
    this.skillLevel = 'intermediate',
    this.preferredMatchTypes = const ['singles', 'doubles'],
    this.maxDistanceKm = 10.0,
    this.weeklyAvailability = const [],
    this.matchHistory = const [],
    this.isProfilePublic = true,
    this.showLocation = true,
    this.showMatchHistory = true,
    this.achievements = const [],
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      photoUrl: data['photoUrl'],
      ntrpRating: (data['ntrpRating'] ?? 3.0).toDouble(),
      playingStyle: data['playingStyle'] ?? 'all-court',
      preferredCourtSurfaces: List<String>.from(data['preferredCourtSurfaces'] ?? []),
      availability: Map<String, bool>.from(data['availability'] ?? {}),
      preferredPlayingTimes: List<String>.from(data['preferredPlayingTimes'] ?? []),
      city: data['city'] ?? '',
      state: data['state'] ?? '',
      location: data['location'] ?? const GeoPoint(0, 0),
      reliabilityScore: (data['reliabilityScore'] ?? 5.0).toDouble(),
      matchesPlayed: data['matchesPlayed'] ?? 0,
      matchesWon: data['matchesWon'] ?? 0,
      createdAt: data['createdAt'] != null 
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastActive: data['lastActive'] != null 
          ? (data['lastActive'] as Timestamp).toDate()
          : DateTime.now(),
      isPremium: data['isPremium'] ?? false,
      savedCourts: List<String>.from(data['savedCourts'] ?? []),
      blockedUsers: List<String>.from(data['blockedUsers'] ?? []),
      skillLevel: data['skillLevel'] ?? 'intermediate',
      preferredMatchTypes: List<String>.from(data['preferredMatchTypes'] ?? ['singles', 'doubles']),
      maxDistanceKm: (data['maxDistanceKm'] ?? 10.0).toDouble(),
      weeklyAvailability: List<Map<String, dynamic>>.from(data['weeklyAvailability'] ?? []),
      matchHistory: List<Map<String, dynamic>>.from(data['matchHistory'] ?? []),
      isProfilePublic: data['isProfilePublic'] ?? true,
      showLocation: data['showLocation'] ?? true,
      showMatchHistory: data['showMatchHistory'] ?? true,
      achievements: List<String>.from(data['achievements'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'ntrpRating': ntrpRating,
      'playingStyle': playingStyle,
      'preferredCourtSurfaces': preferredCourtSurfaces,
      'availability': availability,
      'preferredPlayingTimes': preferredPlayingTimes,
      'city': city,
      'state': state,
      'location': location,
      'reliabilityScore': reliabilityScore,
      'matchesPlayed': matchesPlayed,
      'matchesWon': matchesWon,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastActive': Timestamp.fromDate(lastActive),
      'isPremium': isPremium,
      'savedCourts': savedCourts,
      'blockedUsers': blockedUsers,
      'skillLevel': skillLevel,
      'preferredMatchTypes': preferredMatchTypes,
      'maxDistanceKm': maxDistanceKm,
      'weeklyAvailability': weeklyAvailability,
      'matchHistory': matchHistory,
      'isProfilePublic': isProfilePublic,
      'showLocation': showLocation,
      'showMatchHistory': showMatchHistory,
      'achievements': achievements,
    };
  }
}