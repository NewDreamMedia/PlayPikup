import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tennis_connect/models/user_model.dart';
import 'package:tennis_connect/providers/user_provider.dart';
import 'package:tennis_connect/services/player_discovery_service.dart';
import 'package:tennis_connect/services/location_service.dart';
import 'package:tennis_connect/services/match_challenge_service.dart';
import 'package:tennis_connect/constants/app_constants.dart';
import 'package:tennis_connect/screens/challenge/send_challenge_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PlayerMatchingScreen extends StatefulWidget {
  const PlayerMatchingScreen({super.key});

  @override
  State<PlayerMatchingScreen> createState() => _PlayerMatchingScreenState();
}

class _PlayerMatchingScreenState extends State<PlayerMatchingScreen> with TickerProviderStateMixin {
  final PlayerDiscoveryService _playerService = PlayerDiscoveryService();
  final LocationService _locationService = LocationService();
  final MatchChallengeService _challengeService = MatchChallengeService();
  
  List<PlayerMatch> _playerMatches = [];
  bool _isLoading = false;
  String? _errorMessage;
  Position? _currentPosition;
  
  // Animation controllers for cards
  late AnimationController _cardAnimationController;
  late Animation<double> _cardAnimation;
  
  // Filter settings
  double _radiusInMiles = 10.0;
  String _filterMode = 'smart'; // 'smart', 'distance', 'skill', 'availability'
  
  // Quick match
  PlayerMatch? _quickMatch;
  bool _isSearchingQuickMatch = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadPlayerMatches();
  }

  void _setupAnimations() {
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _cardAnimation = CurvedAnimation(
      parent: _cardAnimationController,
      curve: Curves.easeInOut,
    );
    _cardAnimationController.forward();
  }

  @override
  void dispose() {
    _cardAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadPlayerMatches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final currentUser = Provider.of<UserProvider>(context, listen: false).currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      _currentPosition = await _locationService.getCurrentLocation();
      if (_currentPosition == null) {
        throw Exception('Unable to get location');
      }

      // Get smart matches
      final matches = await _playerService.getSmartPlayerMatches(
        currentUser: currentUser,
        radiusInMiles: _radiusInMiles,
      );

      setState(() {
        _playerMatches = matches;
        _isLoading = false;
      });
      
      // Restart animation for new cards
      _cardAnimationController.reset();
      _cardAnimationController.forward();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _findQuickMatch() async {
    setState(() {
      _isSearchingQuickMatch = true;
    });

    try {
      final currentUser = Provider.of<UserProvider>(context, listen: false).currentUser;
      if (currentUser == null) return;

      final quickMatch = await _playerService.findQuickMatch(
        currentUser: currentUser,
        maxDistanceKm: 5.0,
      );

      setState(() {
        _quickMatch = quickMatch;
        _isSearchingQuickMatch = false;
      });

      if (quickMatch != null) {
        _showQuickMatchDialog(quickMatch);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No players available for quick match right now'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSearchingQuickMatch = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error finding quick match: ${e.toString()}')),
      );
    }
  }

  void _showQuickMatchDialog(PlayerMatch match) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quick Match Found! 🎾'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: match.player.photoUrl != null
                  ? CachedNetworkImageProvider(match.player.photoUrl!)
                  : null,
              child: match.player.photoUrl == null
                  ? Text(
                      match.player.displayName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 32),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              match.player.displayName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'NTRP ${match.player.ntrpRating} • ${match.distance.toStringAsFixed(1)} km away',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${(match.matchScore * 100).round()}% Match',
                style: const TextStyle(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Not Now'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendChallenge(match.player);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            child: const Text('Send Challenge'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Players'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Quick Match Button
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _isSearchingQuickMatch ? null : _findQuickMatch,
                icon: _isSearchingQuickMatch
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.flash_on, size: 24),
                label: Text(
                  _isSearchingQuickMatch ? 'Finding Match...' : 'Quick Match',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          
          // Filter chips
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip('Smart Match', 'smart'),
                const SizedBox(width: 8),
                _buildFilterChip('Nearest', 'distance'),
                const SizedBox(width: 8),
                _buildFilterChip('Best Skill Match', 'skill'),
                const SizedBox(width: 8),
                _buildFilterChip('Available Now', 'availability'),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Main content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String mode) {
    final isSelected = _filterMode == mode;
    
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _filterMode = mode;
            _sortPlayerMatches();
          });
        }
      },
      selectedColor: AppColors.primaryGreen.withOpacity(0.2),
      checkmarkColor: AppColors.primaryGreen,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primaryGreen : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  void _sortPlayerMatches() {
    switch (_filterMode) {
      case 'distance':
        _playerMatches.sort((a, b) => a.distance.compareTo(b.distance));
        break;
      case 'skill':
        _playerMatches.sort((a, b) => 
          b.scoreBreakdown['skill']!.compareTo(a.scoreBreakdown['skill']!));
        break;
      case 'availability':
        _playerMatches.sort((a, b) => 
          b.scoreBreakdown['availability']!.compareTo(a.scoreBreakdown['availability']!));
        break;
      default: // 'smart'
        _playerMatches.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    }
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPlayerMatches,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_playerMatches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No players found in your area',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try expanding your search radius',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _showFilterDialog,
              icon: const Icon(Icons.settings),
              label: const Text('Adjust Filters'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPlayerMatches,
      child: AnimatedBuilder(
        animation: _cardAnimation,
        builder: (context, child) {
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: _playerMatches.length,
            itemBuilder: (context, index) {
              final match = _playerMatches[index];
              return FadeTransition(
                opacity: _cardAnimation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: _cardAnimation,
                    curve: Interval(
                      index * 0.1,
                      1.0,
                      curve: Curves.easeOut,
                    ),
                  )),
                  child: _buildPlayerCard(match),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPlayerCard(PlayerMatch match) {
    final player = match.player;
    final matchPercentage = (match.matchScore * 100).round();
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () => _showPlayerDetails(match),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  // Player avatar
                  Hero(
                    tag: 'player_${player.id}',
                    child: CircleAvatar(
                      radius: 35,
                      backgroundImage: player.photoUrl != null
                          ? CachedNetworkImageProvider(player.photoUrl!)
                          : null,
                      backgroundColor: AppColors.primaryGreen,
                      child: player.photoUrl == null
                          ? Text(
                              player.displayName[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 28,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Player info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                player.displayName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Match percentage badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _getMatchColor(matchPercentage).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _getMatchColor(matchPercentage),
                                ),
                              ),
                              child: Text(
                                '$matchPercentage% Match',
                                style: TextStyle(
                                  color: _getMatchColor(matchPercentage),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star, size: 16, color: Colors.orange[400]),
                            const SizedBox(width: 4),
                            Text(
                              'NTRP ${player.ntrpRating}',
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              '${match.distance.toStringAsFixed(1)} km',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          player.playingStyle.replaceAll('-', ' ').toUpperCase(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Match breakdown
              _buildMatchBreakdown(match),
              
              const SizedBox(height: 16),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showPlayerDetails(match),
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('View Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryGreen,
                        side: const BorderSide(color: AppColors.primaryGreen),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _sendChallenge(player),
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('Challenge'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchBreakdown(PlayerMatch match) {
    final breakdown = match.scoreBreakdown;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildScoreRow('Skill Match', breakdown['skill']!, Icons.timeline),
          const SizedBox(height: 8),
          _buildScoreRow('Proximity', breakdown['proximity']!, Icons.near_me),
          const SizedBox(height: 8),
          _buildScoreRow('Availability', breakdown['availability']!, Icons.schedule),
        ],
      ),
    );
  }

  Widget _buildScoreRow(String label, double score, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ),
        SizedBox(
          width: 100,
          child: LinearProgressIndicator(
            value: score,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              _getScoreColor(score),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(score * 100).round()}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: _getScoreColor(score),
          ),
        ),
      ],
    );
  }

  Color _getMatchColor(int percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }

  Color _getScoreColor(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.6) return Colors.orange;
    return Colors.red;
  }

  void _showPlayerDetails(PlayerMatch match) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: _PlayerDetailsSheet(playerMatch: match),
      ),
    );
  }

  void _sendChallenge(UserModel player) {
    // Find the player match to get distance
    final playerMatch = _playerMatches.firstWhere(
      (match) => match.player.id == player.id,
      orElse: () => PlayerMatch(
        player: player,
        distance: 0.0,
        matchScore: 0.0,
        scoreBreakdown: {},
      ),
    );
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SendChallengeScreen(
          challengedPlayer: player,
          playerDistance: playerMatch.distance,
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Search Radius'),
                Text('${_radiusInMiles.round()} miles'),
              ],
            ),
            Slider(
              value: _radiusInMiles,
              min: 1,
              max: 25,
              divisions: 24,
              onChanged: (value) {
                setState(() {
                  _radiusInMiles = value;
                });
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadPlayerMatches();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

// Player details sheet widget
class _PlayerDetailsSheet extends StatelessWidget {
  final PlayerMatch playerMatch;

  const _PlayerDetailsSheet({required this.playerMatch});

  @override
  Widget build(BuildContext context) {
    final player = playerMatch.player;
    
    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        
        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Player header
                Center(
                  child: Column(
                    children: [
                      Hero(
                        tag: 'player_${player.id}',
                        child: CircleAvatar(
                          radius: 60,
                          backgroundImage: player.photoUrl != null
                              ? CachedNetworkImageProvider(player.photoUrl!)
                              : null,
                          backgroundColor: AppColors.primaryGreen,
                          child: player.photoUrl == null
                              ? Text(
                                  player.displayName[0].toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 40,
                                    color: Colors.white,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        player.displayName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            '${player.city}, ${player.state}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Stats
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStat('NTRP', player.ntrpRating.toString()),
                    _buildStat('Matches', player.matchesPlayed.toString()),
                    _buildStat('Win Rate', 
                      player.matchesPlayed > 0
                        ? '${((player.matchesWon / player.matchesPlayed) * 100).round()}%'
                        : 'N/A'),
                    _buildStat('Reliability', '${player.reliabilityScore}★'),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // Playing details
                _buildSection(
                  'Playing Style',
                  player.playingStyle.replaceAll('-', ' ').toUpperCase(),
                ),
                
                _buildSection(
                  'Preferred Surfaces',
                  player.preferredCourtSurfaces.join(', ').toUpperCase(),
                ),
                
                _buildSection(
                  'Available Times',
                  player.preferredPlayingTimes.join(', ').toUpperCase(),
                ),
                
                // Availability grid
                const Text(
                  'Weekly Availability',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildAvailabilityGrid(player.availability),
                
                const SizedBox(height: 32),
                
                // Match compatibility
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${(playerMatch.matchScore * 100).round()}% Overall Match',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${playerMatch.distance.toStringAsFixed(1)} km away',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityGrid(Map<String, bool> availability) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final isAvailable = availability[dayKeys[index]] ?? false;
        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isAvailable ? AppColors.primaryGreen : Colors.grey[300],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              days[index],
              style: TextStyle(
                fontSize: 12,
                color: isAvailable ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }),
    );
  }
}