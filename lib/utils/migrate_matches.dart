import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:math';

// Run this script once to migrate existing matches
// Usage: Add this to a temporary button in your app or run as a standalone script

class MatchMigration {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Generate a random 6-character invite code
  static String generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
  }
  
  // Main migration function
  static Future<void> migrateMatches() async {
    try {
      print('Starting match migration...');
      
      // Get all matches
      final QuerySnapshot matchesSnapshot = await _firestore
          .collection('matches')
          .get();
      
      print('Found ${matchesSnapshot.docs.length} matches to migrate');
      
      if (matchesSnapshot.docs.isEmpty) {
        print('No matches found. Migration not needed.');
        return;
      }
      
      // Create a batch for efficient updates
      WriteBatch batch = _firestore.batch();
      int batchCount = 0;
      int updatedCount = 0;
      
      for (final doc in matchesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Check if migration is needed (if new fields don't exist)
        if (!data.containsKey('cancelReason') || 
            !data.containsKey('subNeeded') ||
            !data.containsKey('subNeededReason')) {
          
          // Prepare update data
          Map<String, dynamic> updates = {};
          
          // Add new fields if they don't exist
          if (!data.containsKey('cancelReason')) {
            updates['cancelReason'] = null;
          }
          
          if (!data.containsKey('subNeeded')) {
            updates['subNeeded'] = false;
          }
          
          if (!data.containsKey('subNeededReason')) {
            updates['subNeededReason'] = null;
          }
          
          // Generate invite code for private matches
          if (!data.containsKey('inviteCode')) {
            bool isPublic = data['isPublic'] ?? true;
            updates['inviteCode'] = isPublic ? null : generateInviteCode();
          }
          
          // Add to batch
          batch.update(doc.reference, updates);
          batchCount++;
          updatedCount++;
          
          print('Queued update for match: ${doc.id}');
          
          // Firestore has a limit of 500 operations per batch
          if (batchCount >= 500) {
            await batch.commit();
            print('Committed batch of 500 updates');
            batch = _firestore.batch();
            batchCount = 0;
          }
        } else {
          print('Match ${doc.id} already has new fields, skipping...');
        }
      }
      
      // Commit remaining updates
      if (batchCount > 0) {
        await batch.commit();
        print('Committed final batch of $batchCount updates');
      }
      
      print('Migration completed successfully!');
      print('Total matches updated: $updatedCount');
      
    } catch (e) {
      print('Error during migration: $e');
      throw e;
    }
  }
  
  // Check migration status
  static Future<void> checkMigrationStatus() async {
    try {
      final QuerySnapshot matchesSnapshot = await _firestore
          .collection('matches')
          .limit(10)
          .get();
      
      print('\nChecking migration status (sampling first 10 matches)...\n');
      
      for (final doc in matchesSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('Match ID: ${doc.id}');
        print('  - Has cancelReason: ${data.containsKey('cancelReason')}');
        print('  - Has subNeeded: ${data.containsKey('subNeeded')}');
        print('  - Has subNeededReason: ${data.containsKey('subNeededReason')}');
        print('  - Has inviteCode: ${data.containsKey('inviteCode')}');
        print('  - Is Public: ${data['isPublic'] ?? 'not set'}');
        if (data.containsKey('inviteCode') && data['inviteCode'] != null) {
          print('  - Invite Code: ${data['inviteCode']}');
        }
        print('');
      }
    } catch (e) {
      print('Error checking migration status: $e');
    }
  }
}