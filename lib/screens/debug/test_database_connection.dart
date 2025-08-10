import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:tennis_connect/providers/user_provider.dart';
import 'package:tennis_connect/services/location_service.dart';
import 'package:tennis_connect/models/match_model.dart';

class TestDatabaseConnectionScreen extends StatefulWidget {
  const TestDatabaseConnectionScreen({super.key});

  @override
  State<TestDatabaseConnectionScreen> createState() => _TestDatabaseConnectionScreenState();
}

class _TestDatabaseConnectionScreenState extends State<TestDatabaseConnectionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
      _results = [];
    });

    try {
      // Test 1: Basic connection
      _results.add({
        'test': 'Database Connection',
        'status': 'Testing...',
      });

      final testQuery = await _firestore.collection('matches').limit(1).get();
      _results[0]['status'] = 'Connected ✓';
      _results[0]['details'] = 'Successfully connected to Firestore';

      // Test 2: Count all matches
      _results.add({
        'test': 'Total Matches Count',
        'status': 'Counting...',
      });

      final allMatches = await _firestore.collection('matches').get();
      _results[1]['status'] = '${allMatches.docs.length} matches';
      _results[1]['details'] = 'Total matches in database';

      // Test 3: Count public matches
      _results.add({
        'test': 'Public Matches',
        'status': 'Counting...',
      });

      final publicMatches = allMatches.docs.where((doc) {
        final data = doc.data();
        return data['isPublic'] == true;
      }).toList();

      _results[2]['status'] = '${publicMatches.length} matches';
      _results[2]['details'] = 'Matches marked as public';

      // Test 4: Count open matches
      _results.add({
        'test': 'Open Matches',
        'status': 'Counting...',
      });

      final openMatches = publicMatches.where((doc) {
        final data = doc.data();
        return data['status'] == 'open';
      }).toList();

      _results[3]['status'] = '${openMatches.length} matches';
      _results[3]['details'] = 'Public matches with open status';

      // Test 5: Count future matches
      _results.add({
        'test': 'Future Matches',
        'status': 'Counting...',
      });

      final now = DateTime.now();
      final futureMatches = openMatches.where((doc) {
        final data = doc.data();
        final matchDate = (data['matchDate'] as Timestamp).toDate();
        final matchDateOnly = DateTime(matchDate.year, matchDate.month, matchDate.day);
        final todayDateOnly = DateTime(now.year, now.month, now.day);
        return !matchDateOnly.isBefore(todayDateOnly);
      }).toList();

      _results[4]['status'] = '${futureMatches.length} matches';
      _results[4]['details'] = 'Open matches scheduled for today or future';

      // Test 6: Show match creators
      if (futureMatches.isNotEmpty) {
        _results.add({
          'test': 'Match Creators',
          'status': 'Analyzing...',
        });

        final creators = <String>{};
        for (final doc in futureMatches) {
          creators.add(doc.data()['creatorId'] ?? 'Unknown');
        }

        _results[5]['status'] = '${creators.length} unique creators';
        _results[5]['details'] = 'Different users who created matches';
      }

      // Test 7: Current user check
      final user = Provider.of<UserProvider>(context, listen: false).currentUser;
      if (user != null) {
        _results.add({
          'test': 'Current User',
          'status': user.id,
          'details': 'Your user ID for comparison',
        });
      }

    } catch (e) {
      _results.add({
        'test': 'Error',
        'status': 'Failed',
        'details': e.toString(),
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Database Connection'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _testConnection,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: Colors.blue,
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Test Database Connection'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final result = _results[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result['test'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          result['status'],
                          style: TextStyle(
                            color: result['status'].contains('✓') 
                                ? Colors.green 
                                : result['status'] == 'Failed'
                                    ? Colors.red
                                    : Colors.blue,
                            fontSize: 14,
                          ),
                        ),
                        if (result['details'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            result['details'],
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}