import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:tennis_connect/models/match_model.dart';
import 'package:tennis_connect/services/match_service.dart';
import 'package:tennis_connect/services/auth_service.dart';
import 'package:tennis_connect/screens/match/create_match_screen.dart';
import 'package:tennis_connect/screens/match/create_match_wizard_screen.dart';
import 'package:tennis_connect/screens/match/edit_match_screen.dart';
import 'package:tennis_connect/screens/match/match_details_screen.dart';
import 'package:tennis_connect/screens/match/match_history_screen.dart';
import 'package:tennis_connect/screens/player_matching_screen.dart';
import 'package:tennis_connect/screens/match/find_matches_screen.dart';
import 'package:tennis_connect/constants/app_constants.dart';

class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final MatchService _matchService = MatchService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matches'),
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.primaryGreen,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Matches'),
            Tab(text: 'History'),
            Tab(text: 'Find Matches'),
            Tab(text: 'Find Players'),
          ],
          indicatorColor: Colors.white,
          isScrollable: true,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // My Matches Tab
          _buildMyMatchesTab(userId),
          // Match History Tab
          const MatchHistoryScreen(),
          // Find Matches Tab
          _buildFindMatchesTab(userId),
          // Find Players Tab
          const PlayerMatchingScreen(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Show dialog to choose between quick create and wizard
          final useWizard = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Create Match'),
              content: const Text('How would you like to create your match?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Quick Create'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                  ),
                  child: const Text('Step-by-Step'),
                ),
              ],
            ),
          );
          
          if (useWizard != null) {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => useWizard 
                  ? const CreateMatchWizardScreen()
                  : const CreateMatchScreen(),
              ),
            );
            
            if (result != null) {
              // Refresh matches if a new one was created
              setState(() {});
            }
          }
        },
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.add),
        label: const Text('Create Match'),
      ),
    );
  }

  Widget _buildMyMatchesTab(String? userId) {
    if (userId == null) {
      return const Center(
        child: Text('Please login to view your matches'),
      );
    }

    return StreamBuilder<List<MatchModel>>(
      stream: _matchService.getUserMatches(userId).map((matches) {
        // Filter out completed and past matches for My Matches tab
        final now = DateTime.now();
        return matches.where((match) {
          if (match.status == MatchStatus.completed || 
              match.status == MatchStatus.cancelled) {
            return false;
          }
          // Keep upcoming matches
          return true;
        }).toList();
      }),
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

        final matches = snapshot.data ?? [];

        if (matches.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.sports_tennis,
                  size: 80,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'No matches yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create or join a match to get started!',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final match = matches[index];
            return _buildMatchCard(match, isMyMatch: true);
          },
        );
      },
    );
  }

  Widget _buildFindMatchesTab(String? userId) {
    if (userId == null) {
      return const Center(
        child: Text('Please login to find matches'),
      );
    }

    // Use the new FindMatchesScreen
    return const FindMatchesScreen();
  }

  Widget _buildMatchCard(MatchModel match, {required bool isMyMatch}) {
    final isCreator = match.creatorId == Provider.of<AuthService>(context, listen: false).currentUser?.uid;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MatchDetailsScreen(
                match: match,
                currentUserDistance: 0, // TODO: Calculate actual distance
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Match Type and Status with badges
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          match.matchType == MatchType.singles ? 'Singles' : 'Doubles',
                          style: const TextStyle(
                            color: AppColors.primaryGreen,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (match.subNeeded) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning, size: 12, color: Colors.orange),
                              SizedBox(width: 4),
                              Text(
                                'Sub Needed',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  _buildStatusChip(match.status),
                ],
              ),
              const SizedBox(height: 12),
              
              // Court Name
              Row(
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      match.courtName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Date and Time
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('EEE, MMM d').format(match.matchDate),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    match.formattedTimeRange,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Format and Skill Level
              Row(
                children: [
                  Icon(Icons.sports_tennis, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    match.matchFormat.shortName,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.star, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'NTRP ${match.minNtrpRating}-${match.maxNtrpRating}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Players
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.group, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${match.playerIds.length}/${match.matchType == MatchType.singles ? 2 : 4} players',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  if (isCreator)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Created by you',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                ],
              ),
              
              // Show cancel reason if cancelled
              if (match.status == MatchStatus.cancelled && match.cancelReason != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cancelled: ${match.cancelReason}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              // Action buttons for creators
              if (isCreator && match.status != MatchStatus.cancelled && match.status != MatchStatus.completed && isMyMatch) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditMatchScreen(match: match),
                            ),
                          );
                          
                          if (result == true) {
                            setState(() {});
                          }
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _showCancelDialog(match);
                        },
                        icon: const Icon(Icons.cancel, size: 16),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  void _showCancelDialog(MatchModel match) {
    final TextEditingController reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Match'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to cancel this match?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g., Rain expected, Court unavailable',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                await _matchService.cancelMatch(
                  match.id, 
                  match.creatorId,
                  reason: reasonController.text.trim(),
                );
                
                if (!mounted) return;
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Match cancelled successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
                
                setState(() {});
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Cancel Match'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(MatchStatus status) {
    Color color;
    String text;
    
    switch (status) {
      case MatchStatus.open:
        color = Colors.green;
        text = 'Open';
        break;
      case MatchStatus.full:
        color = Colors.orange;
        text = 'Full';
        break;
      case MatchStatus.confirmed:
        color = Colors.blue;
        text = 'Confirmed';
        break;
      case MatchStatus.inProgress:
        color = Colors.purple;
        text = 'In Progress';
        break;
      case MatchStatus.completed:
        color = Colors.grey;
        text = 'Completed';
        break;
      case MatchStatus.cancelled:
        color = Colors.red;
        text = 'Cancelled';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}