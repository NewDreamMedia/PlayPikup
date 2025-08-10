import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tennis_connect/models/match_model.dart';

class FirestoreIndexTest {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Test all queries that require indexes
  static Future<Map<String, dynamic>> testAllIndexes() async {
    final results = <String, dynamic>{};
    final userId = _auth.currentUser?.uid ?? 'test-user-id';
    
    // Test 1: getUserMatches query
    try {
      print('Testing getUserMatches query...');
      final matchesQuery = await _firestore
          .collection('matches')
          .where('playerIds', arrayContains: userId)
          .where('status', whereIn: [
            MatchStatus.open.name,
            MatchStatus.full.name,
            MatchStatus.confirmed.name,
            MatchStatus.inProgress.name,
          ])
          .orderBy('matchDate', descending: false)
          .limit(1)
          .get();
      
      results['getUserMatches'] = {
        'success': true,
        'message': 'Query executed successfully',
        'documentCount': matchesQuery.docs.length
      };
      print('✅ getUserMatches query works!');
    } catch (e) {
      results['getUserMatches'] = {
        'success': false,
        'error': e.toString(),
        'needsIndex': e.toString().contains('index')
      };
      print('❌ getUserMatches query failed: $e');
    }

    // Test 2: getAvailableMatches query
    try {
      print('\nTesting getAvailableMatches query...');
      final availableMatchesQuery = await _firestore
          .collection('matches')
          .where('isPublic', isEqualTo: true)
          .where('status', isEqualTo: MatchStatus.open.name)
          .where('matchDate', isGreaterThan: Timestamp.now())
          .limit(1)
          .get();
      
      results['getAvailableMatches'] = {
        'success': true,
        'message': 'Query executed successfully',
        'documentCount': availableMatchesQuery.docs.length
      };
      print('✅ getAvailableMatches query works!');
    } catch (e) {
      results['getAvailableMatches'] = {
        'success': false,
        'error': e.toString(),
        'needsIndex': e.toString().contains('index')
      };
      print('❌ getAvailableMatches query failed: $e');
    }

    // Test 3: Player discovery query
    try {
      print('\nTesting player discovery query...');
      final playersQuery = await _firestore
          .collection('users')
          .where('isProfilePublic', isEqualTo: true)
          .where('id', isNotEqualTo: userId)
          .limit(1)
          .get();
      
      results['playerDiscovery'] = {
        'success': true,
        'message': 'Query executed successfully',
        'documentCount': playersQuery.docs.length
      };
      print('✅ Player discovery query works!');
    } catch (e) {
      results['playerDiscovery'] = {
        'success': false,
        'error': e.toString(),
        'needsIndex': e.toString().contains('index')
      };
      print('❌ Player discovery query failed: $e');
    }

    // Test 4: Complex match query with matchType
    try {
      print('\nTesting complex match query with matchType...');
      final complexQuery = await _firestore
          .collection('matches')
          .where('isPublic', isEqualTo: true)
          .where('status', isEqualTo: MatchStatus.open.name)
          .where('matchType', isEqualTo: MatchType.singles.name)
          .where('matchDate', isGreaterThan: Timestamp.now())
          .limit(1)
          .get();
      
      results['complexMatchQuery'] = {
        'success': true,
        'message': 'Query executed successfully',
        'documentCount': complexQuery.docs.length
      };
      print('✅ Complex match query works!');
    } catch (e) {
      results['complexMatchQuery'] = {
        'success': false,
        'error': e.toString(),
        'needsIndex': e.toString().contains('index')
      };
      print('❌ Complex match query failed: $e');
    }

    // Test 5: Upcoming matches query
    try {
      print('\nTesting upcoming matches query...');
      final upcomingQuery = await _firestore
          .collection('matches')
          .where('playerIds', arrayContains: userId)
          .where('matchDate', isGreaterThan: Timestamp.now())
          .where('status', whereIn: [
            MatchStatus.confirmed.name,
            MatchStatus.full.name,
          ])
          .limit(1)
          .get();
      
      results['upcomingMatches'] = {
        'success': true,
        'message': 'Query executed successfully',
        'documentCount': upcomingQuery.docs.length
      };
      print('✅ Upcoming matches query works!');
    } catch (e) {
      results['upcomingMatches'] = {
        'success': false,
        'error': e.toString(),
        'needsIndex': e.toString().contains('index')
      };
      print('❌ Upcoming matches query failed: $e');
    }

    return results;
  }

  // Generate summary report
  static String generateReport(Map<String, dynamic> results) {
    final buffer = StringBuffer();
    buffer.writeln('\n🔍 FIRESTORE INDEX VERIFICATION REPORT');
    buffer.writeln('=====================================\n');
    
    int successCount = 0;
    int failureCount = 0;
    
    results.forEach((queryName, result) {
      final success = result['success'] as bool;
      final icon = success ? '✅' : '❌';
      
      if (success) {
        successCount++;
        buffer.writeln('$icon $queryName: SUCCESS');
        buffer.writeln('   Documents found: ${result['documentCount']}');
      } else {
        failureCount++;
        buffer.writeln('$icon $queryName: FAILED');
        buffer.writeln('   Error: ${result['error']}');
        if (result['needsIndex'] == true) {
          buffer.writeln('   ⚠️  This query needs an index!');
        }
      }
      buffer.writeln();
    });
    
    buffer.writeln('SUMMARY:');
    buffer.writeln('--------');
    buffer.writeln('✅ Successful queries: $successCount');
    buffer.writeln('❌ Failed queries: $failureCount');
    
    if (failureCount == 0) {
      buffer.writeln('\n🎉 All indexes are properly configured!');
    } else {
      buffer.writeln('\n⚠️  Some queries still need indexes.');
      buffer.writeln('Check the Firebase Console or use the error links to create them.');
    }
    
    return buffer.toString();
  }

  // Run all tests and print report
  static Future<void> runVerification() async {
    print('Starting Firestore index verification...\n');
    
    try {
      final results = await testAllIndexes();
      final report = generateReport(results);
      print(report);
    } catch (e) {
      print('Error running verification: $e');
    }
  }
}