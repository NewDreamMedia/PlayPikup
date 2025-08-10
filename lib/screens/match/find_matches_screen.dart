import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:tennis_connect/models/match_model.dart';
import 'package:tennis_connect/models/user_model.dart';
import 'package:tennis_connect/services/match_service.dart';
import 'package:tennis_connect/services/auth_service.dart';
import 'package:tennis_connect/services/location_service.dart';
import 'package:tennis_connect/providers/user_provider.dart';
import 'package:tennis_connect/constants/app_constants.dart';
import 'package:tennis_connect/screens/match/match_details_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';

class FindMatchesScreen extends StatefulWidget {
  const FindMatchesScreen({super.key});

  @override
  State<FindMatchesScreen> createState() => _FindMatchesScreenState();
}

class _FindMatchesScreenState extends State<FindMatchesScreen> with TickerProviderStateMixin {
  final MatchService _matchService = MatchService();
  final LocationService _locationService = LocationService();
  
  // Match data
  List<MatchModel> _allMatches = [];
  List<MatchModel> _filteredMatches = [];
  bool _isLoading = false;
  String? _errorMessage;
  Position? _currentPosition;
  
  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Filters
  MatchType? _filterMatchType;
  double _filterMinSkill = 1.0;
  double _filterMaxSkill = 7.0;
  double _filterMaxDistance = 20.0; // miles
  DateTimeRange? _filterDateRange;
  String _sortBy = 'relevance'; // relevance, distance, time
  bool _showOnlyOpenMatches = true;
  bool _showSubstituteNeeded = false;
  
  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _loadMatches();
  }
  
  void _setupAnimation() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Future<void> _loadMatches() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final user = Provider.of<UserProvider>(context, listen: false).currentUser;
      if (user == null) throw Exception('User not logged in');
      
      _currentPosition = await _locationService.getCurrentLocation();
      print('[FindMatchesScreen] Current position: $_currentPosition');
      if (_currentPosition == null) throw Exception('Unable to get location');
      
      // Get available matches
      print('[FindMatchesScreen] Loading matches with filters:');
      print('  - Max distance: $_filterMaxDistance miles');
      print('  - Match type: $_filterMatchType');
      print('  - Skill range: $_filterMinSkill - $_filterMaxSkill');
      print('  - User skill: ${user.ntrpRating}');
      
      final matches = await _matchService.getAvailableMatches(
        userId: user.id,
        userLat: _currentPosition!.latitude,
        userLng: _currentPosition!.longitude,
        userSkillLevel: user.ntrpRating,
        maxDistance: _filterMaxDistance,
        matchType: _filterMatchType,
      );
      
      setState(() {
        _allMatches = matches;
        print('[FindMatchesScreen] Loaded ${matches.length} available matches');
        _applyFiltersAndSort();
        _isLoading = false;
      });
      
      _animationController.reset();
      _animationController.forward();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  void _applyFiltersAndSort() {
    _filteredMatches = _allMatches.where((match) {
      // Filter by skill level
      if (match.minNtrpRating > _filterMaxSkill || match.maxNtrpRating < _filterMinSkill) {
        return false;
      }
      
      // Filter by date range
      if (_filterDateRange != null) {
        if (match.matchDate.isBefore(_filterDateRange!.start) ||
            match.matchDate.isAfter(_filterDateRange!.end)) {
          return false;
        }
      }
      
      // Filter by open status
      if (_showOnlyOpenMatches && match.status != MatchStatus.open) {
        return false;
      }
      
      // Filter by substitute needed
      if (_showSubstituteNeeded && !match.subNeeded) {
        return false;
      }
      
      return true;
    }).toList();
    
    // Sort matches
    _sortMatches();
  }
  
  void _sortMatches() {
    final user = Provider.of<UserProvider>(context, listen: false).currentUser;
    if (user == null) return;
    
    switch (_sortBy) {
      case 'distance':
        _filteredMatches.sort((a, b) {
          final distA = _calculateDistance(a);
          final distB = _calculateDistance(b);
          return distA.compareTo(distB);
        });
        break;
        
      case 'time':
        _filteredMatches.sort((a, b) => a.matchDate.compareTo(b.matchDate));
        break;
        
      case 'relevance':
      default:
        _filteredMatches.sort((a, b) {
          final scoreA = _calculateRelevanceScore(a, user);
          final scoreB = _calculateRelevanceScore(b, user);
          return scoreB.compareTo(scoreA); // Higher score first
        });
        break;
    }
  }
  
  double _calculateDistance(MatchModel match) {
    if (_currentPosition == null) return double.infinity;
    
    return _locationService.calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      match.courtLocation.latitude,
      match.courtLocation.longitude,
    ) / 1609.34; // Convert to miles
  }
  
  double _calculateRelevanceScore(MatchModel match, UserModel user) {
    double score = 0.0;
    
    // Skill match (40%)
    final skillDiff = ((match.minNtrpRating + match.maxNtrpRating) / 2 - user.ntrpRating).abs();
    final skillScore = skillDiff <= 0.5 ? 1.0 : (skillDiff <= 1.0 ? 0.7 : 0.3);
    score += skillScore * 0.4;
    
    // Proximity (30%)
    final distance = _calculateDistance(match);
    final proximityScore = distance <= 5 ? 1.0 : (distance <= 10 ? 0.7 : (distance <= 20 ? 0.4 : 0.1));
    score += proximityScore * 0.3;
    
    // Time match (20%)
    final daysUntilMatch = match.matchDate.difference(DateTime.now()).inDays;
    final timeScore = daysUntilMatch <= 1 ? 1.0 : (daysUntilMatch <= 3 ? 0.7 : (daysUntilMatch <= 7 ? 0.4 : 0.2));
    score += timeScore * 0.2;
    
    // Match type preference (10%)
    if (user.preferredMatchTypes.contains(match.matchType.name)) {
      score += 0.1;
    }
    
    return score;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Filter bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search and filter row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            Icon(Icons.search, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${_filteredMatches.length} matches found',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.filter_list),
                        color: AppColors.primaryGreen,
                        onPressed: _showFilterDialog,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Quick filters
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickFilterChip(
                        'Open Now',
                        _showOnlyOpenMatches,
                        (value) => setState(() {
                          _showOnlyOpenMatches = value;
                          _applyFiltersAndSort();
                        }),
                      ),
                      const SizedBox(width: 8),
                      _buildQuickFilterChip(
                        'Sub Needed',
                        _showSubstituteNeeded,
                        (value) => setState(() {
                          _showSubstituteNeeded = value;
                          _applyFiltersAndSort();
                        }),
                      ),
                      const SizedBox(width: 8),
                      _buildSortChip(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Main content
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickFilterChip(String label, bool selected, Function(bool) onChanged) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onChanged,
      selectedColor: AppColors.primaryGreen.withOpacity(0.2),
      checkmarkColor: AppColors.primaryGreen,
      labelStyle: TextStyle(
        color: selected ? AppColors.primaryGreen : Colors.grey[700],
      ),
    );
  }
  
  Widget _buildSortChip() {
    final sortOptions = {
      'relevance': 'Best Match',
      'distance': 'Nearest',
      'time': 'Soonest',
    };
    
    return ActionChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sort, size: 16),
          const SizedBox(width: 4),
          Text(sortOptions[_sortBy]!),
        ],
      ),
      onPressed: () {
        showModalBottomSheet(
          context: context,
          builder: (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: sortOptions.entries.map((entry) => ListTile(
              leading: Radio<String>(
                value: entry.key,
                groupValue: _sortBy,
                onChanged: (value) {
                  setState(() {
                    _sortBy = value!;
                    _sortMatches();
                  });
                  Navigator.pop(context);
                },
                activeColor: AppColors.primaryGreen,
              ),
              title: Text(entry.value),
              onTap: () {
                setState(() {
                  _sortBy = entry.key;
                  _sortMatches();
                });
                Navigator.pop(context);
              },
            )).toList(),
          ),
        );
      },
    );
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
              onPressed: _loadMatches,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (_filteredMatches.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No matches found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  // Reset filters
                  _filterMatchType = null;
                  _filterMinSkill = 1.0;
                  _filterMaxSkill = 7.0;
                  _filterMaxDistance = 20.0;
                  _filterDateRange = null;
                  _showOnlyOpenMatches = true;
                  _showSubstituteNeeded = false;
                  _applyFiltersAndSort();
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reset Filters'),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadMatches,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _filteredMatches.length,
          itemBuilder: (context, index) {
            final match = _filteredMatches[index];
            return _buildEnhancedMatchCard(match, index);
          },
        ),
      ),
    );
  }
  
  Widget _buildEnhancedMatchCard(MatchModel match, int index) {
    final distance = _calculateDistance(match);
    final user = Provider.of<UserProvider>(context, listen: false).currentUser;
    final relevanceScore = user != null ? _calculateRelevanceScore(match, user) : 0.0;
    final isNew = match.createdAt.difference(DateTime.now()).inHours.abs() < 24;
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MatchDetailsScreen(
                  match: match,
                  currentUserDistance: distance,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Match type and format
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                match.matchType == MatchType.singles
                                    ? Icons.person
                                    : Icons.people,
                                size: 16,
                                color: AppColors.primaryGreen,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                match.matchType == MatchType.singles ? 'Singles' : 'Doubles',
                                style: const TextStyle(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          match.matchFormat.shortName,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    // Badges
                    Row(
                      children: [
                        if (isNew)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'NEW',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (!match.isPublic) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[700],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock, size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Private',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (match.subNeeded) ...[ 
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_search, size: 12, color: Colors.white),
                                SizedBox(width: 4),
                                Text(
                                  'Sub Needed',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Creator info
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.primaryGreen,
                      child: Text(
                        match.creatorName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            match.creatorName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'NTRP ${match.minNtrpRating.toStringAsFixed(1)} - ${match.maxNtrpRating.toStringAsFixed(1)}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Match score indicator
                    if (relevanceScore > 0.7)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle, size: 16, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              '${(relevanceScore * 100).round()}% Match',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Match details
                Row(
                  children: [
                    // Date & Time
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  DateFormat('EEE, MMM d').format(match.matchDate),
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  match.matchTime,
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
                    ),
                    // Location
                    Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  match.courtName,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '${distance.toStringAsFixed(1)} miles',
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
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Players status
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.group, size: 16, color: Colors.grey[700]),
                          const SizedBox(width: 8),
                          Text(
                            '${match.playerIds.length}/${match.matchType == MatchType.singles ? 2 : 4} players',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (match.spotsAvailable > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${match.spotsAvailable} ${match.spotsAvailable == 1 ? "spot" : "spots"} left',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'FULL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _showFilterDialog() {
    // Create local copies of filter values
    MatchType? tempMatchType = _filterMatchType;
    double tempMinSkill = _filterMinSkill;
    double tempMaxSkill = _filterMaxSkill;
    double tempMaxDistance = _filterMaxDistance;
    DateTimeRange? tempDateRange = _filterDateRange;
    bool tempShowOnlyOpenMatches = _showOnlyOpenMatches;
    bool tempShowSubstituteNeeded = _showSubstituteNeeded;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.9,
            expand: false,
            builder: (context, scrollController) {
              return Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter Matches',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Match Type
                            const Text(
                              'Match Type',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('All'),
                                  selected: tempMatchType == null,
                                  onSelected: (selected) {
                                    setModalState(() {
                                      tempMatchType = null;
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('Singles'),
                                  selected: tempMatchType == MatchType.singles,
                                  onSelected: (selected) {
                                    setModalState(() {
                                      tempMatchType = selected ? MatchType.singles : null;
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('Doubles'),
                                  selected: tempMatchType == MatchType.doubles,
                                  onSelected: (selected) {
                                    setModalState(() {
                                      tempMatchType = selected ? MatchType.doubles : null;
                                    });
                                  },
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Skill Level Range
                            const Text(
                              'Skill Level (NTRP)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${tempMinSkill.toStringAsFixed(1)}'),
                                Expanded(
                                  child: RangeSlider(
                                    values: RangeValues(tempMinSkill, tempMaxSkill),
                                    min: 1.0,
                                    max: 7.0,
                                    divisions: 12,
                                    labels: RangeLabels(
                                      tempMinSkill.toStringAsFixed(1),
                                      tempMaxSkill.toStringAsFixed(1),
                                    ),
                                    onChanged: (values) {
                                      setModalState(() {
                                        tempMinSkill = values.start;
                                        tempMaxSkill = values.end;
                                      });
                                    },
                                    activeColor: AppColors.primaryGreen,
                                  ),
                                ),
                                Text('${tempMaxSkill.toStringAsFixed(1)}'),
                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Distance
                            const Text(
                              'Maximum Distance',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('0 mi'),
                                Expanded(
                                  child: Slider(
                                    value: tempMaxDistance,
                                    min: 1.0,
                                    max: 50.0,
                                    divisions: 49,
                                    label: '${tempMaxDistance.round()} miles',
                                    onChanged: (value) {
                                      setModalState(() {
                                        tempMaxDistance = value;
                                      });
                                    },
                                    activeColor: AppColors.primaryGreen,
                                  ),
                                ),
                                Text('${tempMaxDistance.round()} mi'),
                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Date Range
                            const Text(
                              'Date Range',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final range = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 60)),
                                  initialDateRange: _filterDateRange,
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: AppColors.primaryGreen,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (range != null) {
                                  setModalState(() {
                                    _filterDateRange = range;
                                  });
                                }
                              },
                              icon: const Icon(Icons.calendar_today),
                              label: Text(
                                _filterDateRange == null
                                    ? 'Select date range'
                                    : '${DateFormat('MMM d').format(_filterDateRange!.start)} - ${DateFormat('MMM d').format(_filterDateRange!.end)}',
                              ),
                            ),
                            
                            const SizedBox(height: 32),
                            
                            // Action buttons
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      setModalState(() {
                                        tempMatchType = null;
                                        tempMinSkill = 1.0;
                                        tempMaxSkill = 7.0;
                                        tempMaxDistance = 20.0;
                                        tempDateRange = null;
                                        tempShowOnlyOpenMatches = true;
                                        tempShowSubstituteNeeded = false;
                                      });
                                    },
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    child: const Text('Reset'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        // Apply all temporary values to main state
                                        _filterMatchType = tempMatchType;
                                        _filterMinSkill = tempMinSkill;
                                        _filterMaxSkill = tempMaxSkill;
                                        _filterMaxDistance = tempMaxDistance;
                                        _filterDateRange = tempDateRange;
                                        _showOnlyOpenMatches = tempShowOnlyOpenMatches;
                                        _showSubstituteNeeded = tempShowSubstituteNeeded;
                                        _applyFiltersAndSort();
                                      });
                                      Navigator.pop(context);
                                      // Reload matches with new distance filter
                                      _loadMatches();
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
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}