import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tennis_connect/models/match_model.dart';
import 'package:tennis_connect/constants/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ScoreInputDialog extends StatefulWidget {
  final MatchModel match;
  final Function(List<String> scores, String? winnerId, Map<String, MatchOutcome> outcomes) onScoreSaved;

  const ScoreInputDialog({
    super.key,
    required this.match,
    required this.onScoreSaved,
  });

  @override
  State<ScoreInputDialog> createState() => _ScoreInputDialogState();
}

class _ScoreInputDialogState extends State<ScoreInputDialog> {
  final List<List<TextEditingController>> _scoreControllers = [];
  String? _selectedWinner;
  MatchOutcome _matchOutcome = MatchOutcome.noResult;
  int _numberOfSets = 3;
  bool _isLoading = false;
  
  // Player names cache
  final Map<String, String> _playerNames = {};

  @override
  void initState() {
    super.initState();
    _initializeSets();
    _loadPlayerNames();
  }

  void _initializeSets() {
    // Determine number of sets based on format
    switch (widget.match.matchFormat) {
      case MatchFormat.bestOf5:
        _numberOfSets = 5;
        break;
      case MatchFormat.bestOf3:
        _numberOfSets = 3;
        break;
      case MatchFormat.proSet:
      case MatchFormat.shortSet:
        _numberOfSets = 1;
        break;
      case MatchFormat.practice:
        _numberOfSets = 3; // Default to 3 for practice
        break;
    }

    // Initialize controllers for each set
    for (int i = 0; i < _numberOfSets; i++) {
      _scoreControllers.add([
        TextEditingController(), // Player/Team 1 score
        TextEditingController(), // Player/Team 2 score
      ]);
    }
  }

  Future<void> _loadPlayerNames() async {
    for (final playerId in widget.match.playerIds) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(playerId)
          .get();
      
      if (doc.exists) {
        setState(() {
          _playerNames[playerId] = doc.data()?['displayName'] ?? 'Unknown';
        });
      }
    }
  }

  @override
  void dispose() {
    for (final controllers in _scoreControllers) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  List<String> _getSetScores() {
    final scores = <String>[];
    for (final controllers in _scoreControllers) {
      final score1 = controllers[0].text.trim();
      final score2 = controllers[1].text.trim();
      if (score1.isNotEmpty && score2.isNotEmpty) {
        scores.add('$score1-$score2');
      }
    }
    return scores;
  }

  Map<String, MatchOutcome> _determineOutcomes() {
    final outcomes = <String, MatchOutcome>{};
    
    if (_selectedWinner == null) {
      // No result for all players
      for (final playerId in widget.match.playerIds) {
        outcomes[playerId] = MatchOutcome.noResult;
      }
    } else if (widget.match.matchType == MatchType.singles) {
      // Singles match
      for (final playerId in widget.match.playerIds) {
        if (playerId == _selectedWinner) {
          outcomes[playerId] = MatchOutcome.win;
        } else {
          outcomes[playerId] = MatchOutcome.loss;
        }
      }
    } else {
      // Doubles match - need to determine teams
      // For simplicity, assume creator and their partner are team 1
      // This would need more complex logic in a real app
      for (final playerId in widget.match.playerIds) {
        if (playerId == _selectedWinner || playerId == widget.match.creatorPartnerId) {
          outcomes[playerId] = MatchOutcome.win;
        } else {
          outcomes[playerId] = MatchOutcome.loss;
        }
      }
    }
    
    return outcomes;
  }

  void _saveScore() {
    // Validate at least one set has scores
    final scores = _getSetScores();
    if (scores.isEmpty && _matchOutcome != MatchOutcome.noResult) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter at least one set score'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final outcomes = _determineOutcomes();
    
    Navigator.pop(context);
    widget.onScoreSaved(scores, _selectedWinner, outcomes);
  }

  @override
  Widget build(BuildContext context) {
    final isDoubles = widget.match.matchType == MatchType.doubles;
    
    return AlertDialog(
      title: const Text('Enter Match Score'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Match outcome selection
            const Text(
              'Match Result',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            
            // Quick result buttons
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Completed'),
                  selected: _matchOutcome != MatchOutcome.noResult,
                  onSelected: (selected) {
                    setState(() {
                      _matchOutcome = selected ? MatchOutcome.win : MatchOutcome.noResult;
                    });
                  },
                ),
                ChoiceChip(
                  label: const Text('No Result'),
                  selected: _matchOutcome == MatchOutcome.noResult,
                  onSelected: (selected) {
                    setState(() {
                      _matchOutcome = MatchOutcome.noResult;
                      _selectedWinner = null;
                    });
                  },
                ),
              ],
            ),
            
            if (_matchOutcome != MatchOutcome.noResult) ...[
              const SizedBox(height: 16),
              
              // Winner selection
              const Text(
                'Winner',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              
              if (isDoubles) ...[
                // For doubles, show teams
                RadioListTile<String>(
                  title: Text('Team 1: ${_playerNames[widget.match.playerIds[0]] ?? 'Loading...'} & ${_playerNames[widget.match.playerIds[1]] ?? 'Loading...'}'),
                  value: widget.match.playerIds[0],
                  groupValue: _selectedWinner,
                  onChanged: (value) {
                    setState(() {
                      _selectedWinner = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                RadioListTile<String>(
                  title: Text('Team 2: ${_playerNames[widget.match.playerIds[2]] ?? 'Loading...'} & ${_playerNames[widget.match.playerIds[3]] ?? 'Loading...'}'),
                  value: widget.match.playerIds[2],
                  groupValue: _selectedWinner,
                  onChanged: (value) {
                    setState(() {
                      _selectedWinner = value;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                ),
              ] else ...[
                // For singles, show individual players
                ...widget.match.playerIds.map((playerId) {
                  return RadioListTile<String>(
                    title: Text(_playerNames[playerId] ?? 'Loading...'),
                    value: playerId,
                    groupValue: _selectedWinner,
                    onChanged: (value) {
                      setState(() {
                        _selectedWinner = value;
                      });
                    },
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
              ],
              
              const SizedBox(height: 16),
              
              // Score input
              const Text(
                'Set Scores',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              
              // Set score inputs
              Column(
                children: List.generate(_scoreControllers.length, (index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 60,
                          child: Text(
                            'Set ${index + 1}:',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _scoreControllers[index][0],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: '0',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              isDense: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('-', style: TextStyle(fontSize: 18)),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _scoreControllers[index][1],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: InputDecoration(
                              hintText: '0',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              isDense: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(2),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
              
              // Score format hint
              Text(
                _getFormatHint(),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveScore,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryGreen,
          ),
          child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text('Save'),
        ),
      ],
    );
  }

  String _getFormatHint() {
    switch (widget.match.matchFormat) {
      case MatchFormat.bestOf3:
        return 'Best of 3 sets (first to win 2 sets)';
      case MatchFormat.bestOf5:
        return 'Best of 5 sets (first to win 3 sets)';
      case MatchFormat.proSet:
        return 'Pro set (first to 8 games, win by 2)';
      case MatchFormat.shortSet:
        return 'Short set (first to 4 games, win by 2)';
      case MatchFormat.practice:
        return 'Practice session - enter scores as played';
    }
  }
}