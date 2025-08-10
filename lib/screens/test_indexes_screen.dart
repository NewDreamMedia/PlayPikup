import 'package:flutter/material.dart';
import 'package:tennis_connect/utils/firestore_index_test.dart';
import 'package:tennis_connect/constants/app_constants.dart';

class TestIndexesScreen extends StatefulWidget {
  const TestIndexesScreen({super.key});

  @override
  State<TestIndexesScreen> createState() => _TestIndexesScreenState();
}

class _TestIndexesScreenState extends State<TestIndexesScreen> {
  bool _isRunning = false;
  String _results = '';
  Map<String, dynamic>? _testResults;

  Future<void> _runTests() async {
    setState(() {
      _isRunning = true;
      _results = 'Running tests...';
    });

    try {
      final results = await FirestoreIndexTest.testAllIndexes();
      final report = FirestoreIndexTest.generateReport(results);
      
      setState(() {
        _testResults = results;
        _results = report;
        _isRunning = false;
      });
    } catch (e) {
      setState(() {
        _results = 'Error: ${e.toString()}';
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firestore Index Verification'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(
                      Icons.storage,
                      size: 48,
                      color: AppColors.primaryGreen,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Index Verification Tool',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This tool will test all Firestore queries that require indexes',
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isRunning ? null : _runTests,
                        icon: _isRunning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.play_arrow),
                        label: Text(_isRunning ? 'Running Tests...' : 'Run Verification'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            if (_results.isNotEmpty) ...[
              const SizedBox(height: 24),
              Card(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _results,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
            
            if (_testResults != null) ...[
              const SizedBox(height: 24),
              const Text(
                'Detailed Results:',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ..._testResults!.entries.map((entry) {
                final success = entry.value['success'] as bool;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      success ? Icons.check_circle : Icons.error,
                      color: success ? Colors.green : Colors.red,
                      size: 32,
                    ),
                    title: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      success
                          ? 'Query working correctly'
                          : 'Index needed - Click to see error',
                    ),
                    trailing: success
                        ? Text(
                            '${entry.value['documentCount']} docs',
                            style: TextStyle(color: Colors.grey[600]),
                          )
                        : const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: !success
                        ? () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Error: ${entry.key}'),
                                content: SingleChildScrollView(
                                  child: Text(
                                    entry.value['error'].toString(),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                ],
                              ),
                            );
                          }
                        : null,
                  ),
                );
              }).toList(),
            ],
            
            const SizedBox(height: 24),
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'How to fix failed queries:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '1. Check the error message for each failed query\n'
                      '2. Look for a Firebase Console link in the error\n'
                      '3. Click the link to create the index automatically\n'
                      '4. Wait 1-2 minutes for the index to build\n'
                      '5. Run this verification again',
                      style: TextStyle(color: Colors.blue[700]),
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