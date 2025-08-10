import 'package:flutter/material.dart';
import 'package:tennis_connect/models/user_model.dart';
import 'package:tennis_connect/services/player_discovery_service.dart';
import 'package:tennis_connect/services/location_service.dart';
import 'package:tennis_connect/services/match_challenge_service.dart';
import 'package:tennis_connect/constants/app_constants.dart';
import 'package:tennis_connect/screens/challenge/send_challenge_screen.dart';
import 'package:geolocator/geolocator.dart';

class PlayerDiscoveryScreen extends StatefulWidget {
  const PlayerDiscoveryScreen({super.key});

  @override
  State<PlayerDiscoveryScreen> createState() => _PlayerDiscoveryScreenState();
}

class _PlayerDiscoveryScreenState extends State<PlayerDiscoveryScreen> {
  final PlayerDiscoveryService _playerService = PlayerDiscoveryService();
  final LocationService _locationService = LocationService();
  final MatchChallengeService _challengeService = MatchChallengeService();
  
  List<UserModel> _nearbyPlayers = [];
  bool _isLoading = false;
  String? _errorMessage;
  Position? _currentPosition;
  
  // Filter settings
  double _radiusInMiles = 5.0;
  String? _selectedSkillLevel;
  List<String> _selectedDays = [];
  List<String> _selectedTimes = [];
  
  final List<String> _skillLevels = ['beginner', 'intermediate', 'advanced', 'expert'];
  final List<String> _weekDays = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
  final List<String> _timesOfDay = ['morning', 'afternoon', 'evening'];

  @override
  void initState() {
    super.initState();
    _loadNearbyPlayers();
  }

  Future<void> _loadNearbyPlayers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _currentPosition = await _locationService.getCurrentLocation();
      if (_currentPosition == null) {
        setState(() {
          _errorMessage = 'Unable to get your location. Please enable location services.';
          _isLoading = false;
        });
        return;
      }

      final players = await _playerService.getNearbyPlayers(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        radiusInMiles: _radiusInMiles,
        skillLevel: _selectedSkillLevel,
        availableDays: _selectedDays.isEmpty ? null : _selectedDays,
        preferredTimes: _selectedTimes.isEmpty ? null : _selectedTimes,
      );

      setState(() {
        _nearbyPlayers = players;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading nearby players. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Players',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              // Distance slider
              Text('Distance: ${_radiusInMiles.toStringAsFixed(1)} miles'),
              Slider(
                value: _radiusInMiles,
                min: 1.0,
                max: 25.0,
                divisions: 24,
                label: '${_radiusInMiles.toStringAsFixed(1)} mi',
                onChanged: (value) {
                  setModalState(() => _radiusInMiles = value);
                },
              ),
              
              const Divider(),
              
              // Skill level
              const Text('Skill Level', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: _skillLevels.map((level) => ChoiceChip(
                  label: Text(level.substring(0, 1).toUpperCase() + level.substring(1)),
                  selected: _selectedSkillLevel == level,
                  onSelected: (selected) {
                    setModalState(() {
                      _selectedSkillLevel = selected ? level : null;
                    });
                  },
                )).toList(),
              ),
              
              const Divider(),
              
              // Available days
              const Text('Available Days', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: _weekDays.map((day) => FilterChip(
                  label: Text(day.substring(0, 3).toUpperCase()),
                  selected: _selectedDays.contains(day),
                  onSelected: (selected) {
                    setModalState(() {
                      if (selected) {
                        _selectedDays.add(day);
                      } else {
                        _selectedDays.remove(day);
                      }
                    });
                  },
                )).toList(),
              ),
              
              const Divider(),
              
              // Preferred times
              const Text('Preferred Times', style: TextStyle(fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8,
                children: _timesOfDay.map((time) => FilterChip(
                  label: Text(time.substring(0, 1).toUpperCase() + time.substring(1)),
                  selected: _selectedTimes.contains(time),
                  onSelected: (selected) {
                    setModalState(() {
                      if (selected) {
                        _selectedTimes.add(time);
                      } else {
                        _selectedTimes.remove(time);
                      }
                    });
                  },
                )).toList(),
              ),
              
              const SizedBox(height: 20),
              
              // Apply button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {}); // Update main state
                    Navigator.pop(context);
                    _loadNearbyPlayers();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _challengePlayer(UserModel player) async {
    final canChallenge = await _challengeService.canChallengeUser(player.id);
    
    if (!canChallenge) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already have a pending challenge with this player'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SendChallengeScreen(
          challengedPlayer: player,
          playerDistance: _getDistanceToPlayer(player),
        ),
      ),
    );
  }

  double _getDistanceToPlayer(UserModel player) {
    if (_currentPosition == null) return 0;
    
    final distanceInMeters = _locationService.calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      player.location.latitude,
      player.location.longitude,
    );
    
    return distanceInMeters / 1609.34; // Convert to miles
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Players'),
        backgroundColor: AppColors.primaryGreen,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryGreen,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadNearbyPlayers,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_nearbyPlayers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No players found nearby',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showFilterDialog,
              icon: const Icon(Icons.tune),
              label: const Text('Adjust Filters'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNearbyPlayers,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _nearbyPlayers.length,
        itemBuilder: (context, index) {
          final player = _nearbyPlayers[index];
          return _buildPlayerCard(player);
        },
      ),
    );
  }

  Widget _buildPlayerCard(UserModel player) {
    final distance = _getDistanceToPlayer(player);
    final isAvailableNow = _playerService.isPlayerAvailableNow(player);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Player avatar
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.lightGreen,
                  backgroundImage: player.photoUrl != null
                      ? NetworkImage(player.photoUrl!)
                      : null,
                  child: player.photoUrl == null
                      ? Text(
                          player.displayName.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGreen,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                
                // Player info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            player.displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isAvailableNow)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Available',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'NTRP ${player.ntrpRating}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${distance.toStringAsFixed(1)} mi',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Challenge button
                ElevatedButton(
                  onPressed: () => _challengePlayer(player),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Challenge'),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Player details
            Text(
              'Style: ${player.playingStyle.replaceAll('-', ' ').toUpperCase()}',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 4),
            
            // Availability summary
            Wrap(
              spacing: 8,
              children: [
                if (player.reliabilityScore > 4.0)
                  Chip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: Colors.green),
                        const SizedBox(width: 4),
                        Text('${player.reliabilityScore.toStringAsFixed(1)} Reliability'),
                      ],
                    ),
                    backgroundColor: Colors.green.withOpacity(0.1),
                  ),
                Chip(
                  label: Text('${player.matchesPlayed} Matches'),
                  backgroundColor: Colors.blue.withOpacity(0.1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}