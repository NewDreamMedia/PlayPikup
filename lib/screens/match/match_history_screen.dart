import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tennis_connect/models/match_model.dart';
import 'package:tennis_connect/services/match_service.dart';
import 'package:tennis_connect/services/auth_service.dart';
import 'package:tennis_connect/screens/match/score_input_dialog.dart';
import 'package:tennis_connect/constants/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MatchHistoryScreen extends StatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  final MatchService _matchService = MatchService();
  String _filterType = 'all'; // all, wins, losses, cancelled

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;

    if (userId == null) {
      return const Center(
        child: Text('Please login to view your match history'),
      );
    }

    return Column(
      children: [
        // Filter chips
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _buildFilterChip('All', 'all'),
              const SizedBox(width: 8),
              _buildFilterChip('Wins', 'wins'),
              const SizedBox(width: 8),
              _buildFilterChip('Losses', 'losses'),
              const SizedBox(width: 8),
              _buildFilterChip('Cancelled', 'cancelled'),
              const SizedBox(width: 8),
              _buildFilterChip('No Result', 'noResult'),
            ],
          ),
        ),
        
        // Match history list
        Expanded(
          child: StreamBuilder<List<MatchModel>>(
            stream: _getMatchHistory(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              final matches = _filterMatches(snapshot.data ?? [], userId);

              if (matches.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 80,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _filterType == 'all' 
                          ? 'No match history yet'
                          : 'No matches found',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your completed matches will appear here',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }

              // Calculate statistics
              final stats = _calculateStats(matches, userId);

              return Column(
                children: [
                  // Statistics card
                  if (_filterType == 'all')
                    _buildStatsCard(stats),
                  
                  // Match list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: matches.length,
                      itemBuilder: (context, index) {
                        final match = matches[index];
                        return _buildHistoryCard(match, userId);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterType == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filterType = value;
        });
      },
      selectedColor: AppColors.primaryGreen.withOpacity(0.2),
      checkmarkColor: AppColors.primaryGreen,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primaryGreen : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildStatsCard(Map<String, int> stats) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen,
            AppColors.primaryGreen.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Played', stats['total']!.toString(), Icons.sports_tennis),
          _buildStatItem('Wins', stats['wins']!.toString(), Icons.emoji_events),
          _buildStatItem('Losses', stats['losses']!.toString(), Icons.trending_down),
          _buildStatItem(
            'Win Rate',
            stats['total']! > 0 
              ? '${((stats['wins']! / stats['total']!) * 100).toStringAsFixed(0)}%'
              : '0%',
            Icons.analytics,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(MatchModel match, String userId) {
    final isCreator = match.creatorId == userId;
    final outcome = match.playerOutcomes?[userId];
    final isCancelled = match.status == MatchStatus.cancelled;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showMatchDetails(match, userId),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date and outcome
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('EEE, MMM d, yyyy').format(match.matchDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isCancelled)
                    _buildOutcomeBadge('Cancelled', Colors.grey)
                  else if (outcome != null)
                    _buildOutcomeBadge(
                      _getOutcomeText(outcome),
                      _getOutcomeColor(outcome),
                    )
                  else if (match.status == MatchStatus.completed)
                    _buildOutcomeBadge('No Result', Colors.orange),
                ],
              ),
              const SizedBox(height: 12),
              
              // Match type and format
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      match.matchType == MatchType.singles ? 'Singles' : 'Doubles',
                      style: const TextStyle(
                        color: AppColors.primaryGreen,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    match.matchFormat.shortName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Score if available
              if (match.setScores != null && match.setScores!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.scoreboard, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        match.setScores!.join(' • '),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              
              // Court and opponents
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      match.courtName,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Opponents
              FutureBuilder<List<String>>(
                future: _getOpponentNames(match, userId),
                builder: (context, snapshot) {
                  final opponents = snapshot.data ?? ['Loading...'];
                  return Row(
                    children: [
                      Icon(Icons.person, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'vs ${opponents.join(', ')}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                },
              ),
              
              // Action buttons
              if (!isCancelled && match.status == MatchStatus.completed) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (isCreator && match.setScores == null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showScoreInputDialog(match),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Add Score'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                        ),
                      ),
                    if (match.setScores != null) ...[
                      if (isCreator && match.setScores == null)
                        const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _shareMatch(match, userId),
                          icon: const Icon(Icons.share, size: 16),
                          label: const Text('Share'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOutcomeBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  String _getOutcomeText(MatchOutcome outcome) {
    switch (outcome) {
      case MatchOutcome.win:
        return 'WIN';
      case MatchOutcome.loss:
        return 'LOSS';
      case MatchOutcome.draw:
        return 'DRAW';
      case MatchOutcome.noResult:
        return 'No Result';
    }
  }

  Color _getOutcomeColor(MatchOutcome outcome) {
    switch (outcome) {
      case MatchOutcome.win:
        return Colors.green;
      case MatchOutcome.loss:
        return Colors.red;
      case MatchOutcome.draw:
        return Colors.blue;
      case MatchOutcome.noResult:
        return Colors.orange;
    }
  }

  Stream<List<MatchModel>> _getMatchHistory(String userId) {
    return FirebaseFirestore.instance
        .collection('matches')
        .where('playerIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final now = DateTime.now();
          return snapshot.docs
              .map((doc) => MatchModel.fromFirestore(doc))
              .where((match) {
                // Include completed and cancelled matches
                if (match.status == MatchStatus.completed || 
                    match.status == MatchStatus.cancelled) {
                  return true;
                }
                // Include past matches that should be completed
                final matchEndTime = match.matchDate.add(Duration(minutes: match.duration));
                return matchEndTime.isBefore(now);
              })
              .toList()
            ..sort((a, b) => b.matchDate.compareTo(a.matchDate)); // Sort by date descending
        });
  }

  List<MatchModel> _filterMatches(List<MatchModel> matches, String userId) {
    switch (_filterType) {
      case 'wins':
        return matches.where((m) => 
          m.playerOutcomes?[userId] == MatchOutcome.win).toList();
      case 'losses':
        return matches.where((m) => 
          m.playerOutcomes?[userId] == MatchOutcome.loss).toList();
      case 'cancelled':
        return matches.where((m) => 
          m.status == MatchStatus.cancelled).toList();
      case 'noResult':
        return matches.where((m) => 
          m.playerOutcomes?[userId] == MatchOutcome.noResult ||
          (m.status == MatchStatus.completed && m.playerOutcomes?[userId] == null)).toList();
      default:
        return matches;
    }
  }

  Map<String, int> _calculateStats(List<MatchModel> matches, String userId) {
    int wins = 0;
    int losses = 0;
    int total = 0;

    for (final match in matches) {
      if (match.status == MatchStatus.completed) {
        total++;
        final outcome = match.playerOutcomes?[userId];
        if (outcome == MatchOutcome.win) wins++;
        if (outcome == MatchOutcome.loss) losses++;
      }
    }

    return {
      'total': total,
      'wins': wins,
      'losses': losses,
    };
  }

  Future<List<String>> _getOpponentNames(MatchModel match, String currentUserId) async {
    final opponentIds = match.playerIds.where((id) => id != currentUserId).toList();
    final names = <String>[];
    
    for (final id in opponentIds) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(id)
          .get();
      
      if (doc.exists) {
        names.add(doc.data()?['displayName'] ?? 'Unknown');
      }
    }
    
    return names.isEmpty ? ['No opponents'] : names;
  }

  void _showMatchDetails(MatchModel match, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Match Details',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              
              // Match details content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Date', DateFormat('EEEE, MMMM d, yyyy').format(match.matchDate)),
                      _buildDetailRow('Time', match.matchTime),
                      _buildDetailRow('Court', match.courtName),
                      _buildDetailRow('Type', '${match.matchType.name} - ${match.matchFormat.displayName}'),
                      if (match.setScores != null)
                        _buildDetailRow('Score', match.setScores!.join(' • ')),
                      if (match.cancelReason != null)
                        _buildDetailRow('Cancel Reason', match.cancelReason!),
                      if (match.notes != null)
                        _buildDetailRow('Notes', match.notes!),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showScoreInputDialog(MatchModel match) {
    showDialog(
      context: context,
      builder: (context) => ScoreInputDialog(
        match: match,
        onScoreSaved: (scores, winnerId, outcomes) async {
          try {
            await _matchService.updateMatchScore(
              match.id,
              scores,
              winnerId,
              outcomes,
            );
            
            if (!mounted) return;
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Score updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error updating score: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  void _shareMatch(MatchModel match, String userId) async {
    final opponents = await _getOpponentNames(match, userId);
    final outcome = match.playerOutcomes?[userId];
    final outcomeText = outcome != null ? _getOutcomeText(outcome) : '';
    
    final shareText = StringBuffer();
    shareText.writeln('🎾 Tennis Match Summary');
    shareText.writeln('');
    shareText.writeln('📅 ${DateFormat('MMM d, yyyy').format(match.matchDate)}');
    shareText.writeln('📍 ${match.courtName}');
    shareText.writeln('🏆 ${match.matchType == MatchType.singles ? 'Singles' : 'Doubles'} Match');
    
    if (match.setScores != null) {
      shareText.writeln('📊 Score: ${match.setScores!.join(' • ')}');
    }
    
    if (outcomeText.isNotEmpty) {
      shareText.writeln('🎯 Result: $outcomeText');
    }
    
    shareText.writeln('');
    shareText.writeln('Played against: ${opponents.join(', ')}');
    shareText.writeln('');
    shareText.writeln('Shared from Tennis Connect App');
    
    await Share.share(shareText.toString());
  }
}