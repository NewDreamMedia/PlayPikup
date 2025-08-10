// This is the optimized version to use AFTER creating indexes
// Save this for reference - you can rename and use it once indexes are ready

  // Get matches for a specific user (OPTIMIZED VERSION)
  Stream<List<MatchModel>> getUserMatches(String userId) {
    return _firestore
        .collection(_matchesCollection)
        .where('playerIds', arrayContains: userId)
        .where('status', whereIn: [
          MatchStatus.open.name,
          MatchStatus.full.name,
          MatchStatus.confirmed.name,
          MatchStatus.inProgress.name,
        ])
        .orderBy('matchDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MatchModel.fromFirestore(doc))
            .toList());
  }

  // Get available matches (OPTIMIZED VERSION)
  Future<List<MatchModel>> getAvailableMatches({
    required String userId,
    required double userLat,
    required double userLng,
    required double userSkillLevel,
    double? maxDistance,
    MatchType? matchType,
  }) async {
    // Query for open public matches
    Query query = _firestore
        .collection(_matchesCollection)
        .where('isPublic', isEqualTo: true)
        .where('status', isEqualTo: MatchStatus.open.name)
        .where('matchDate', isGreaterThan: Timestamp.now());
    
    if (matchType != null) {
      query = query.where('matchType', isEqualTo: matchType.name);
    }
    
    final querySnapshot = await query.get();
    // ... rest of the filtering logic
  }