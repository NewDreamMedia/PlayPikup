import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tennis_connect/models/match_model.dart';

enum ChallengeStatus { pending, accepted, rejected, expired, cancelled }

class MatchChallengeModel {
  final String id;
  final String challengerId;
  final String challengerName;
  final String challengerPhotoUrl;
  final double challengerNtrpRating;
  final String challengedId;
  final String challengedName;
  final String? courtId;
  final String? courtName;
  final String? courtAddress;
  final GeoPoint? courtLocation;
  final DateTime? proposedDate;
  final String? proposedTime;
  final int? duration; // in minutes
  final MatchType matchType;
  final MatchFormat matchFormat;
  final ChallengeStatus status;
  final String? message;
  final String? responseMessage;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final DateTime expiresAt;
  final double distanceInMiles; // Distance between players

  MatchChallengeModel({
    required this.id,
    required this.challengerId,
    required this.challengerName,
    required this.challengerPhotoUrl,
    required this.challengerNtrpRating,
    required this.challengedId,
    required this.challengedName,
    this.courtId,
    this.courtName,
    this.courtAddress,
    this.courtLocation,
    this.proposedDate,
    this.proposedTime,
    this.duration,
    required this.matchType,
    required this.matchFormat,
    required this.status,
    this.message,
    this.responseMessage,
    required this.createdAt,
    this.respondedAt,
    required this.expiresAt,
    required this.distanceInMiles,
  });

  factory MatchChallengeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MatchChallengeModel(
      id: doc.id,
      challengerId: data['challengerId'] ?? '',
      challengerName: data['challengerName'] ?? '',
      challengerPhotoUrl: data['challengerPhotoUrl'] ?? '',
      challengerNtrpRating: (data['challengerNtrpRating'] ?? 3.0).toDouble(),
      challengedId: data['challengedId'] ?? '',
      challengedName: data['challengedName'] ?? '',
      courtId: data['courtId'],
      courtName: data['courtName'],
      courtAddress: data['courtAddress'],
      courtLocation: data['courtLocation'],
      proposedDate: data['proposedDate'] != null 
          ? (data['proposedDate'] as Timestamp).toDate()
          : null,
      proposedTime: data['proposedTime'],
      duration: data['duration'],
      matchType: MatchType.values.firstWhere(
        (e) => e.name == data['matchType'],
        orElse: () => MatchType.singles,
      ),
      matchFormat: MatchFormat.values.firstWhere(
        (e) => e.name == data['matchFormat'],
        orElse: () => MatchFormat.bestOf3,
      ),
      status: ChallengeStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ChallengeStatus.pending,
      ),
      message: data['message'],
      responseMessage: data['responseMessage'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      respondedAt: data['respondedAt'] != null 
          ? (data['respondedAt'] as Timestamp).toDate()
          : null,
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      distanceInMiles: (data['distanceInMiles'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'challengerId': challengerId,
      'challengerName': challengerName,
      'challengerPhotoUrl': challengerPhotoUrl,
      'challengerNtrpRating': challengerNtrpRating,
      'challengedId': challengedId,
      'challengedName': challengedName,
      'courtId': courtId,
      'courtName': courtName,
      'courtAddress': courtAddress,
      'courtLocation': courtLocation,
      'proposedDate': proposedDate != null 
          ? Timestamp.fromDate(proposedDate!)
          : null,
      'proposedTime': proposedTime,
      'duration': duration,
      'matchType': matchType.name,
      'matchFormat': matchFormat.name,
      'status': status.name,
      'message': message,
      'responseMessage': responseMessage,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null 
          ? Timestamp.fromDate(respondedAt!)
          : null,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'distanceInMiles': distanceInMiles,
    };
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  bool get isPending => status == ChallengeStatus.pending && !isExpired;
  
  String get statusDisplay {
    if (isExpired && status == ChallengeStatus.pending) {
      return 'Expired';
    }
    switch (status) {
      case ChallengeStatus.pending:
        return 'Pending';
      case ChallengeStatus.accepted:
        return 'Accepted';
      case ChallengeStatus.rejected:
        return 'Rejected';
      case ChallengeStatus.expired:
        return 'Expired';
      case ChallengeStatus.cancelled:
        return 'Cancelled';
    }
  }
  
  String get timeRemaining {
    if (isExpired) return 'Expired';
    
    final remaining = expiresAt.difference(DateTime.now());
    if (remaining.inDays > 0) {
      return '${remaining.inDays}d ${remaining.inHours % 24}h';
    } else if (remaining.inHours > 0) {
      return '${remaining.inHours}h ${remaining.inMinutes % 60}m';
    } else {
      return '${remaining.inMinutes}m';
    }
  }
}