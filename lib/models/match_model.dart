import 'package:cloud_firestore/cloud_firestore.dart';

enum MatchType { singles, doubles }
enum MatchFormat { bestOf3, bestOf5, proSet, shortSet, practice }
enum MatchStatus { open, full, confirmed, inProgress, completed, cancelled }
enum MatchOutcome { win, loss, draw, noResult }

class MatchModel {
  final String id;
  final String creatorId;
  final String creatorName;
  final String? creatorPartnerId; // for doubles
  final List<String> playerIds;
  final String courtId;
  final String courtName;
  final String courtAddress;
  final GeoPoint courtLocation;
  final DateTime matchDate;
  final String matchTime; // "10:00 AM"
  final int duration; // in minutes
  final MatchType matchType;
  final MatchFormat matchFormat;
  final double minNtrpRating;
  final double maxNtrpRating;
  final double maxDistance; // Maximum distance for player matching (in km)
  final MatchStatus status;
  final Map<String, bool> playerConfirmations; // {userId: confirmed}
  final List<String> invitedPlayerIds;
  final bool isPublic;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? scores; // for completed matches - now stores detailed scores
  final String? winnerId;
  final Map<String, double>? playerRatings; // post-match ratings
  final Map<String, MatchOutcome>? playerOutcomes; // outcomes for each player
  final List<String>? setScores; // e.g., ["6-4", "3-6", "6-2"]
  final DateTime? completedAt; // when the match was completed
  final bool subNeeded; // Whether a substitute is needed
  final String? subNeededReason; // Reason for needing a substitute
  final String? inviteCode; // Invite code for private matches
  final String? cancelReason; // Reason for cancellation

  MatchModel({
    required this.id,
    required this.creatorId,
    required this.creatorName,
    this.creatorPartnerId,
    required this.playerIds,
    required this.courtId,
    required this.courtName,
    required this.courtAddress,
    required this.courtLocation,
    required this.matchDate,
    required this.matchTime,
    required this.duration,
    required this.matchType,
    required this.matchFormat,
    required this.minNtrpRating,
    required this.maxNtrpRating,
    required this.maxDistance,
    required this.status,
    required this.playerConfirmations,
    required this.invitedPlayerIds,
    required this.isPublic,
    this.notes,
    required this.createdAt,
    this.updatedAt,
    this.scores,
    this.winnerId,
    this.playerRatings,
    this.playerOutcomes,
    this.setScores,
    this.completedAt,
    this.subNeeded = false,
    this.subNeededReason,
    this.inviteCode,
    this.cancelReason,
  });

  factory MatchModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MatchModel(
      id: doc.id,
      creatorId: data['creatorId'] ?? '',
      creatorName: data['creatorName'] ?? '',
      creatorPartnerId: data['creatorPartnerId'],
      playerIds: List<String>.from(data['playerIds'] ?? []),
      courtId: data['courtId'] ?? '',
      courtName: data['courtName'] ?? '',
      courtAddress: data['courtAddress'] ?? '',
      courtLocation: data['courtLocation'] ?? const GeoPoint(0, 0),
      matchDate: (data['matchDate'] as Timestamp).toDate(),
      matchTime: data['matchTime'] ?? '',
      duration: data['duration'] ?? 60,
      matchType: MatchType.values.firstWhere(
        (e) => e.name == data['matchType'],
        orElse: () => MatchType.singles,
      ),
      matchFormat: MatchFormat.values.firstWhere(
        (e) => e.name == data['matchFormat'],
        orElse: () => MatchFormat.bestOf3,
      ),
      minNtrpRating: (data['minNtrpRating'] ?? 2.5).toDouble(),
      maxNtrpRating: (data['maxNtrpRating'] ?? 5.0).toDouble(),
      maxDistance: (data['maxDistance'] ?? 10.0).toDouble(),
      status: MatchStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => MatchStatus.open,
      ),
      playerConfirmations: Map<String, bool>.from(data['playerConfirmations'] ?? {}),
      invitedPlayerIds: List<String>.from(data['invitedPlayerIds'] ?? []),
      isPublic: data['isPublic'] ?? true,
      notes: data['notes'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null 
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      scores: data['scores'] != null 
          ? Map<String, dynamic>.from(data['scores']) 
          : null,
      winnerId: data['winnerId'],
      playerRatings: data['playerRatings'] != null 
          ? Map<String, double>.from(data['playerRatings']) 
          : null,
      playerOutcomes: data['playerOutcomes'] != null
          ? (data['playerOutcomes'] as Map<String, dynamic>).map((key, value) => 
              MapEntry(key, MatchOutcome.values.firstWhere(
                (e) => e.name == value,
                orElse: () => MatchOutcome.noResult,
              )))
          : null,
      setScores: data['setScores'] != null
          ? List<String>.from(data['setScores'])
          : null,
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      subNeeded: data['subNeeded'] ?? false,
      subNeededReason: data['subNeededReason'],
      inviteCode: data['inviteCode'],
      cancelReason: data['cancelReason'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'creatorId': creatorId,
      'creatorName': creatorName,
      'creatorPartnerId': creatorPartnerId,
      'playerIds': playerIds,
      'courtId': courtId,
      'courtName': courtName,
      'courtAddress': courtAddress,
      'courtLocation': courtLocation,
      'matchDate': Timestamp.fromDate(matchDate),
      'matchTime': matchTime,
      'duration': duration,
      'matchType': matchType.name,
      'matchFormat': matchFormat.name,
      'minNtrpRating': minNtrpRating,
      'maxNtrpRating': maxNtrpRating,
      'maxDistance': maxDistance,
      'status': status.name,
      'playerConfirmations': playerConfirmations,
      'invitedPlayerIds': invitedPlayerIds,
      'isPublic': isPublic,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'scores': scores,
      'winnerId': winnerId,
      'playerRatings': playerRatings,
      'playerOutcomes': playerOutcomes?.map((key, value) => MapEntry(key, value.name)),
      'setScores': setScores,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'subNeeded': subNeeded,
      'subNeededReason': subNeededReason,
      'inviteCode': inviteCode,
      'cancelReason': cancelReason,
    };
  }

  bool get isFull {
    if (matchType == MatchType.singles) return playerIds.length >= 2;
    return playerIds.length >= 4;
  }

  int get spotsAvailable {
    final maxPlayers = matchType == MatchType.singles ? 2 : 4;
    return maxPlayers - playerIds.length;
  }
  
  // Check if user can join based on skill level
  bool canJoinBySkill(double userSkillLevel) {
    return userSkillLevel >= minNtrpRating && userSkillLevel <= maxNtrpRating;
  }
  
  // Check if match is upcoming
  bool get isUpcoming => matchDate.isAfter(DateTime.now());
  
  // Get formatted match time range
  String get formattedTimeRange {
    final endTime = _calculateEndTime();
    return '$matchTime - $endTime';
  }
  
  String _calculateEndTime() {
    // Parse time (assuming format like "10:00 AM")
    final timeParts = matchTime.split(' ');
    final hourMinute = timeParts[0].split(':');
    var hour = int.parse(hourMinute[0]);
    final minute = int.parse(hourMinute[1]);
    final isPM = timeParts.length > 1 && timeParts[1].toUpperCase() == 'PM';
    
    if (isPM && hour != 12) hour += 12;
    if (!isPM && hour == 12) hour = 0;
    
    final totalMinutes = hour * 60 + minute + duration;
    var endHour = totalMinutes ~/ 60;
    final endMinute = totalMinutes % 60;
    
    final endIsPM = endHour >= 12;
    if (endHour > 12) endHour -= 12;
    if (endHour == 0) endHour = 12;
    
    return '${endHour}:${endMinute.toString().padLeft(2, '0')} ${endIsPM ? 'PM' : 'AM'}';
  }
}

// Extension for match format display
extension MatchFormatExtension on MatchFormat {
  String get displayName {
    switch (this) {
      case MatchFormat.bestOf3:
        return 'Best of 3 Sets';
      case MatchFormat.bestOf5:
        return 'Best of 5 Sets';
      case MatchFormat.proSet:
        return 'Pro Set (8 games)';
      case MatchFormat.shortSet:
        return 'Short Set (4 games)';
      case MatchFormat.practice:
        return 'Practice Session';
    }
  }
  
  String get shortName {
    switch (this) {
      case MatchFormat.bestOf3:
        return '3 Sets';
      case MatchFormat.bestOf5:
        return '5 Sets';
      case MatchFormat.proSet:
        return 'Pro Set';
      case MatchFormat.shortSet:
        return 'Short Set';
      case MatchFormat.practice:
        return 'Practice';
    }
  }
}