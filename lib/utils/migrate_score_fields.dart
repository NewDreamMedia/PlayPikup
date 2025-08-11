import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

/// Migration script to add new score-related fields to existing matches
/// Run this once to update your existing matches in Firebase
class MigrateScoreFields {
  static Future<void> migrateMatches() async {
    try {
      print('Starting score fields migration...');
      
      final firestore = FirebaseFirestore.instance;
      final matchesCollection = firestore.collection('matches');
      
      // Get all matches
      final QuerySnapshot snapshot = await matchesCollection.get();
      print('Found ${snapshot.docs.length} matches to check');
      
      int updatedCount = 0;
      int skippedCount = 0;
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final updates = <String, dynamic>{};
        
        // Check and add missing fields
        if (!data.containsKey('proposedScores')) {
          updates['proposedScores'] = null;
        }
        
        if (!data.containsKey('scoreVerified')) {
          // If match has scores, mark as verified (legacy data)
          updates['scoreVerified'] = data.containsKey('setScores') && data['setScores'] != null;
        }
        
        if (!data.containsKey('scoreSubmittedBy')) {
          // If match has scores, assume creator submitted them (legacy data)
          updates['scoreSubmittedBy'] = data.containsKey('setScores') && data['setScores'] != null 
              ? data['creatorId'] 
              : null;
        }
        
        if (!data.containsKey('scoreApprovals')) {
          // If match has scores, auto-approve for all players (legacy data)
          if (data.containsKey('setScores') && data['setScores'] != null) {
            final Map<String, bool> approvals = {};
            final playerIds = List<String>.from(data['playerIds'] ?? []);
            for (final playerId in playerIds) {
              approvals[playerId] = true;
            }
            updates['scoreApprovals'] = approvals;
          } else {
            updates['scoreApprovals'] = null;
          }
        }
        
        // Only update if there are changes
        if (updates.isNotEmpty) {
          await doc.reference.update(updates);
          updatedCount++;
          print('Updated match ${doc.id} with new score fields');
        } else {
          skippedCount++;
          print('Match ${doc.id} already has all score fields, skipping...');
        }
      }
      
      print('\n=== Migration Summary ===');
      print('Total matches processed: ${snapshot.docs.length}');
      print('Matches updated: $updatedCount');
      print('Matches skipped: $skippedCount');
      print('Migration completed successfully!');
      
    } catch (e) {
      print('Error during migration: $e');
      rethrow;
    }
  }
  
  /// Check the current state of score fields in the database
  static Future<void> checkMigrationStatus() async {
    try {
      print('\nChecking migration status...');
      
      final firestore = FirebaseFirestore.instance;
      final matchesCollection = firestore.collection('matches');
      
      // Get a sample of matches
      final QuerySnapshot snapshot = await matchesCollection.limit(10).get();
      
      print('Checking first ${snapshot.docs.length} matches:');
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        print('\nMatch ID: ${doc.id}');
        print('  - Has proposedScores: ${data.containsKey('proposedScores')}');
        print('  - Has scoreVerified: ${data.containsKey('scoreVerified')} (value: ${data['scoreVerified']})');
        print('  - Has scoreSubmittedBy: ${data.containsKey('scoreSubmittedBy')} (value: ${data['scoreSubmittedBy']})');
        print('  - Has scoreApprovals: ${data.containsKey('scoreApprovals')}');
        print('  - Has setScores: ${data.containsKey('setScores')} (value: ${data['setScores']})');
        print('  - Status: ${data['status']}');
      }
      
    } catch (e) {
      print('Error checking migration status: $e');
      rethrow;
    }
  }
}

/// Widget to run the migration from the app
class ScoreFieldsMigrationScreen extends StatefulWidget {
  const ScoreFieldsMigrationScreen({super.key});

  @override
  State<ScoreFieldsMigrationScreen> createState() => _ScoreFieldsMigrationScreenState();
}

class _ScoreFieldsMigrationScreenState extends State<ScoreFieldsMigrationScreen> {
  bool _isRunning = false;
  String _status = 'Ready to migrate';
  
  Future<void> _runMigration() async {
    setState(() {
      _isRunning = true;
      _status = 'Running migration...';
    });
    
    try {
      await MigrateScoreFields.migrateMatches();
      setState(() {
        _status = 'Migration completed successfully!';
      });
      
      // Check status after migration
      await MigrateScoreFields.checkMigrationStatus();
      
    } catch (e) {
      setState(() {
        _status = 'Migration failed: $e';
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }
  
  Future<void> _checkStatus() async {
    setState(() {
      _isRunning = true;
      _status = 'Checking status...';
    });
    
    try {
      await MigrateScoreFields.checkMigrationStatus();
      setState(() {
        _status = 'Status check completed - check console for details';
      });
    } catch (e) {
      setState(() {
        _status = 'Status check failed: $e';
      });
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Score Fields Migration'),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Score Fields Migration Tool',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _status,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              if (_isRunning)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: _runMigration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                      ),
                      child: const Text(
                        'Run Migration',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _checkStatus,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                      ),
                      child: const Text(
                        'Check Status',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 40),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'What this migration does:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text('• Adds proposedScores field for score suggestions'),
                      Text('• Adds scoreVerified field for verification tracking'),
                      Text('• Adds scoreSubmittedBy to track who added scores'),
                      Text('• Adds scoreApprovals for multi-player verification'),
                      Text('• Preserves all existing match data'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}