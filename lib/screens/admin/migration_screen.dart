import 'package:flutter/material.dart';
import 'package:tennis_connect/utils/migrate_matches.dart';
import 'package:tennis_connect/constants/app_constants.dart';

class MigrationScreen extends StatefulWidget {
  const MigrationScreen({super.key});

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  bool _isMigrating = false;
  String _status = 'Ready to migrate';
  List<String> _logs = [];

  Future<void> _runMigration() async {
    setState(() {
      _isMigrating = true;
      _status = 'Starting migration...';
      _logs.clear();
      _logs.add('Migration started at ${DateTime.now()}');
    });

    try {
      await MatchMigration.migrateMatches();
      
      setState(() {
        _status = 'Migration completed successfully!';
        _logs.add('Migration completed at ${DateTime.now()}');
      });
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Migration completed successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _status = 'Migration failed: $e';
        _logs.add('Error: $e');
      });
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Migration failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isMigrating = false;
      });
    }
  }

  Future<void> _checkStatus() async {
    setState(() {
      _status = 'Checking migration status...';
      _logs.clear();
    });

    try {
      // Capture console output
      await MatchMigration.checkMigrationStatus();
      
      setState(() {
        _status = 'Status check completed';
        _logs.add('Check the console/debug output for details');
      });
    } catch (e) {
      setState(() {
        _status = 'Status check failed: $e';
        _logs.add('Error: $e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Database Migration'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning Card
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Important',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This migration will update all existing matches with new fields:\n'
                      '• cancelReason (for cancelled matches)\n'
                      '• subNeeded (substitute needed flag)\n'
                      '• subNeededReason (reason for substitute)\n'
                      '• inviteCode (for private matches)\n\n'
                      'This is safe to run multiple times - it will skip already migrated matches.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Status Display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Migration Status',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (_isMigrating)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        else
                          Icon(
                            _status.contains('completed') 
                              ? Icons.check_circle 
                              : _status.contains('failed')
                                ? Icons.error
                                : Icons.info,
                            color: _status.contains('completed')
                              ? Colors.green
                              : _status.contains('failed')
                                ? Colors.red
                                : Colors.blue,
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _status,
                            style: TextStyle(
                              color: _status.contains('completed')
                                ? Colors.green
                                : _status.contains('failed')
                                  ? Colors.red
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isMigrating ? null : _checkStatus,
                    icon: const Icon(Icons.info_outline),
                    label: const Text('Check Status'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isMigrating ? null : _runMigration,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(_isMigrating ? 'Migrating...' : 'Run Migration'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Logs Section
            if (_logs.isNotEmpty) ...[
              const Text(
                'Logs',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      return Text(
                        _logs[index],
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Instructions
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.help_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'How to Use',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Click "Check Status" to see if migration is needed\n'
                      '2. Click "Run Migration" to update all matches\n'
                      '3. Check console/debug output for detailed logs\n'
                      '4. Once complete, you can remove this migration screen',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}