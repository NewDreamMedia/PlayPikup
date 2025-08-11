import 'package:cloud_firestore/cloud_firestore.dart';

class MatchStatistics {
  final String matchId;
  final Map<String, PlayerStatistics> playerStats; // playerId -> statistics
  final DateTime? recordedAt;

  MatchStatistics({
    required this.matchId,
    required this.playerStats,
    this.recordedAt,
  });

  factory MatchStatistics.fromFirestore(Map<String, dynamic> data) {
    return MatchStatistics(
      matchId: data['matchId'] ?? '',
      playerStats: (data['playerStats'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(
          key,
          PlayerStatistics.fromMap(value as Map<String, dynamic>),
        ),
      ) ?? {},
      recordedAt: data['recordedAt'] != null
          ? (data['recordedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'matchId': matchId,
      'playerStats': playerStats.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'recordedAt': recordedAt != null 
          ? Timestamp.fromDate(recordedAt!)
          : FieldValue.serverTimestamp(),
    };
  }
}

class PlayerStatistics {
  final int aces;
  final int doubleFaults;
  final int winners;
  final int unforcedErrors;
  final int firstServePercentage;
  final int firstServePointsWon;
  final int secondServePointsWon;
  final int breakPointsSaved;
  final int breakPointsConverted;
  final int netPointsWon;
  final int totalPointsWon;
  final String? notes;

  PlayerStatistics({
    this.aces = 0,
    this.doubleFaults = 0,
    this.winners = 0,
    this.unforcedErrors = 0,
    this.firstServePercentage = 0,
    this.firstServePointsWon = 0,
    this.secondServePointsWon = 0,
    this.breakPointsSaved = 0,
    this.breakPointsConverted = 0,
    this.netPointsWon = 0,
    this.totalPointsWon = 0,
    this.notes,
  });

  factory PlayerStatistics.fromMap(Map<String, dynamic> map) {
    return PlayerStatistics(
      aces: map['aces'] ?? 0,
      doubleFaults: map['doubleFaults'] ?? 0,
      winners: map['winners'] ?? 0,
      unforcedErrors: map['unforcedErrors'] ?? 0,
      firstServePercentage: map['firstServePercentage'] ?? 0,
      firstServePointsWon: map['firstServePointsWon'] ?? 0,
      secondServePointsWon: map['secondServePointsWon'] ?? 0,
      breakPointsSaved: map['breakPointsSaved'] ?? 0,
      breakPointsConverted: map['breakPointsConverted'] ?? 0,
      netPointsWon: map['netPointsWon'] ?? 0,
      totalPointsWon: map['totalPointsWon'] ?? 0,
      notes: map['notes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'aces': aces,
      'doubleFaults': doubleFaults,
      'winners': winners,
      'unforcedErrors': unforcedErrors,
      'firstServePercentage': firstServePercentage,
      'firstServePointsWon': firstServePointsWon,
      'secondServePointsWon': secondServePointsWon,
      'breakPointsSaved': breakPointsSaved,
      'breakPointsConverted': breakPointsConverted,
      'netPointsWon': netPointsWon,
      'totalPointsWon': totalPointsWon,
      'notes': notes,
    };
  }
}