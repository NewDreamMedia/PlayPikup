import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tennis_connect/models/match_model.dart';
import 'package:tennis_connect/models/tennis_court.dart';
import 'package:tennis_connect/services/auth_service.dart';
import 'package:tennis_connect/services/match_service.dart';
import 'package:tennis_connect/providers/user_provider.dart';
import 'package:tennis_connect/screens/court_discovery_screen.dart';
import 'package:tennis_connect/constants/app_constants.dart';

class CreateMatchWizardScreen extends StatefulWidget {
  final TennisCourt? preselectedCourt;

  const CreateMatchWizardScreen({
    super.key,
    this.preselectedCourt,
  });

  @override
  State<CreateMatchWizardScreen> createState() => _CreateMatchWizardScreenState();
}

class _CreateMatchWizardScreenState extends State<CreateMatchWizardScreen> {
  final _matchService = MatchService();
  final PageController _pageController = PageController();
  
  // Current step
  int _currentStep = 0;
  final int _totalSteps = 5;
  
  // Form data
  MatchType _matchType = MatchType.singles;
  MatchFormat _matchFormat = MatchFormat.bestOf3;
  int _tiebreakPoints = 7; // 7 or 10 point tiebreak
  int _proSetGames = 8; // 8 or 10 games for pro set
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  int _duration = 90; // minutes
  double _minSkillLevel = 2.5;
  double _maxSkillLevel = 4.5;
  double _maxDistance = 10.0; // km
  bool _isPublic = true;
  String _inviteCode = '';
  TennisCourt? _selectedCourt;
  String _notes = '';
  bool _saveAsTemplate = false;
  String _templateName = '';
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCourt = widget.preselectedCourt;
    _generateInviteCode();
    _loadSavedTemplate();
  }

  void _generateInviteCode() {
    // Generate a simple 6-character invite code
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    _inviteCode = List.generate(6, (index) => 
      chars[(DateTime.now().millisecondsSinceEpoch + index) % chars.length]
    ).join();
  }

  Future<void> _loadSavedTemplate() async {
    // TODO: Load user's saved match template if exists
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _createMatch() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = Provider.of<UserProvider>(context, listen: false).currentUser;
      final authService = Provider.of<AuthService>(context, listen: false);
      
      if (user == null || _selectedCourt == null) {
        throw Exception('Missing required data');
      }

      // Save template if requested
      if (_saveAsTemplate) {
        await _saveMatchTemplate();
      }

      // Combine date and time
      final matchDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      // Create match model
      final match = MatchModel(
        id: '',
        creatorId: authService.currentUser!.uid,
        creatorName: user.displayName,
        playerIds: [authService.currentUser!.uid],
        courtId: _selectedCourt!.placeId,
        courtName: _selectedCourt!.name,
        courtAddress: _selectedCourt!.address,
        courtLocation: GeoPoint(
          _selectedCourt!.latitude,
          _selectedCourt!.longitude,
        ),
        matchDate: matchDateTime,
        matchTime: _selectedTime.format(context),
        duration: _duration,
        matchType: _matchType,
        matchFormat: _matchFormat,
        minNtrpRating: _minSkillLevel,
        maxNtrpRating: _maxSkillLevel,
        maxDistance: _maxDistance,
        status: MatchStatus.open,
        playerConfirmations: {authService.currentUser!.uid: true},
        invitedPlayerIds: [],
        isPublic: _isPublic,
        notes: _notes,
        createdAt: DateTime.now(),
        inviteCode: !_isPublic ? _inviteCode : null,
      );

      // Create match
      final matchId = await _matchService.createMatch(match);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isPublic 
              ? 'Match created successfully!' 
              : 'Private match created! Invite code: $_inviteCode'),
            action: !_isPublic ? SnackBarAction(
              label: 'Copy Code',
              onPressed: () {
                // TODO: Copy invite code to clipboard
              },
            ) : null,
          ),
        );
        Navigator.pop(context, matchId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating match: ${e.toString()}')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveMatchTemplate() async {
    // TODO: Save match settings as a template for future use
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Match'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
          ),
        ),
      ),
      body: Column(
        children: [
          // Step indicator
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Step ${_currentStep + 1} of $_totalSteps: ',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                Text(
                  _getStepTitle(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildMatchTypeStep(),
                _buildMatchFormatStep(),
                _buildSkillLevelStep(),
                _buildScheduleStep(),
                _buildReviewStep(),
              ],
            ),
          ),
          
          // Navigation buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep > 0)
                  OutlinedButton.icon(
                    onPressed: _previousStep,
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  )
                else
                  const SizedBox(width: 100),
                
                if (_currentStep < _totalSteps - 1)
                  ElevatedButton.icon(
                    onPressed: _nextStep,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _createMatch,
                    icon: _isLoading 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                    label: Text(_isLoading ? 'Creating...' : 'Create Match'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Match Type';
      case 1:
        return 'Match Format';
      case 2:
        return 'Skill Level';
      case 3:
        return 'Schedule & Location';
      case 4:
        return 'Review & Create';
      default:
        return '';
    }
  }

  Widget _buildMatchTypeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What type of match do you want to play?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          
          // Match type selection
          _buildMatchTypeCard(
            type: MatchType.singles,
            title: 'Singles',
            description: '1 vs 1 match',
            icon: Icons.person,
          ),
          const SizedBox(height: 12),
          _buildMatchTypeCard(
            type: MatchType.doubles,
            title: 'Doubles',
            description: '2 vs 2 match',
            icon: Icons.people,
          ),
          
          const SizedBox(height: 32),
          
          // Public/Private toggle
          const Text(
            'Match Visibility',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Public Match'),
                    subtitle: Text(_isPublic 
                      ? 'Visible to all players in your area'
                      : 'Only players with invite code can join'),
                    value: _isPublic,
                    onChanged: (value) {
                      setState(() {
                        _isPublic = value;
                      });
                    },
                    activeColor: AppColors.primaryGreen,
                  ),
                  if (!_isPublic) ...[
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.vpn_key),
                      title: const Text('Invite Code'),
                      subtitle: Text(_inviteCode),
                      trailing: IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                          setState(() {
                            _generateInviteCode();
                          });
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Info box
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Private matches are perfect for playing with friends or organizing club matches.',
                    style: TextStyle(color: Colors.blue[700], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchTypeCard({
    required MatchType type,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _matchType == type;
    
    return InkWell(
      onTap: () {
        setState(() {
          _matchType = type;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? AppColors.primaryGreen.withOpacity(0.05) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected 
                  ? AppColors.primaryGreen.withOpacity(0.1)
                  : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primaryGreen : Colors.grey[600],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primaryGreen : null,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primaryGreen,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchFormatStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose your match format',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          
          // Format options
          _buildFormatOption(
            format: MatchFormat.bestOf3,
            title: 'Best of 3 Sets',
            description: 'Traditional format, 2 sets to win',
            icon: Icons.looks_3,
          ),
          _buildFormatOption(
            format: MatchFormat.bestOf5,
            title: 'Best of 5 Sets',
            description: 'Extended format, 3 sets to win',
            icon: Icons.looks_5,
          ),
          _buildFormatOption(
            format: MatchFormat.proSet,
            title: 'Pro Set',
            description: 'First to ${_proSetGames} games wins',
            icon: Icons.speed,
          ),
          _buildFormatOption(
            format: MatchFormat.shortSet,
            title: 'Short Set',
            description: 'First to 4 games wins',
            icon: Icons.timer,
          ),
          _buildFormatOption(
            format: MatchFormat.practice,
            title: 'Practice Session',
            description: 'No scoring, just hit around',
            icon: Icons.sports_tennis,
          ),
          
          // Additional settings based on format
          if (_matchFormat == MatchFormat.bestOf3 || _matchFormat == MatchFormat.bestOf5) ...[
            const SizedBox(height: 24),
            const Text(
              'Tiebreak Settings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    RadioListTile<int>(
                      title: const Text('7-point tiebreak'),
                      subtitle: const Text('First to 7 points (win by 2)'),
                      value: 7,
                      groupValue: _tiebreakPoints,
                      onChanged: (value) {
                        setState(() {
                          _tiebreakPoints = value!;
                        });
                      },
                      activeColor: AppColors.primaryGreen,
                    ),
                    RadioListTile<int>(
                      title: const Text('10-point tiebreak'),
                      subtitle: const Text('First to 10 points (win by 2)'),
                      value: 10,
                      groupValue: _tiebreakPoints,
                      onChanged: (value) {
                        setState(() {
                          _tiebreakPoints = value!;
                        });
                      },
                      activeColor: AppColors.primaryGreen,
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          if (_matchFormat == MatchFormat.proSet) ...[
            const SizedBox(height: 24),
            const Text(
              'Pro Set Length',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    RadioListTile<int>(
                      title: const Text('8-game pro set'),
                      subtitle: const Text('First to 8 games (win by 2)'),
                      value: 8,
                      groupValue: _proSetGames,
                      onChanged: (value) {
                        setState(() {
                          _proSetGames = value!;
                        });
                      },
                      activeColor: AppColors.primaryGreen,
                    ),
                    RadioListTile<int>(
                      title: const Text('10-game pro set'),
                      subtitle: const Text('First to 10 games (win by 2)'),
                      value: 10,
                      groupValue: _proSetGames,
                      onChanged: (value) {
                        setState(() {
                          _proSetGames = value!;
                        });
                      },
                      activeColor: AppColors.primaryGreen,
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          // Help tooltip
          const SizedBox(height: 16),
          InkWell(
            onTap: () => _showFormatHelp(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.help_outline, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'What\'s the difference between formats?',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatOption({
    required MatchFormat format,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final isSelected = _matchFormat == format;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            _matchFormat = format;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? AppColors.primaryGreen : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected ? AppColors.primaryGreen.withOpacity(0.05) : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primaryGreen : Colors.grey[600],
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppColors.primaryGreen : null,
                      ),
                    ),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Radio<MatchFormat>(
                value: format,
                groupValue: _matchFormat,
                onChanged: (value) {
                  setState(() {
                    _matchFormat = value!;
                  });
                },
                activeColor: AppColors.primaryGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFormatHelp() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Match Format Guide',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildHelpItem(
              'Best of 3 Sets',
              'Standard tournament format. Each set goes to 6 games (win by 2). Perfect for competitive matches lasting 1.5-2 hours.',
            ),
            _buildHelpItem(
              'Best of 5 Sets',
              'Grand Slam format. Longer matches (2-3+ hours) for serious competition.',
            ),
            _buildHelpItem(
              'Pro Set',
              'Quick format where first to 8 or 10 games wins. Great for time-limited matches (45-60 minutes).',
            ),
            _buildHelpItem(
              'Short Set',
              'Very quick format, first to 4 games. Perfect for lunch breaks (30-45 minutes).',
            ),
            _buildHelpItem(
              'Practice Session',
              'No scoring pressure. Just rally, work on technique, and have fun!',
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AppColors.primaryGreen,
              ),
              child: const Text('Got it!'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillLevelStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set skill level requirements',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps match you with players of similar ability',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          
          // NTRP Range Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.timeline, color: AppColors.primaryGreen),
                      const SizedBox(width: 8),
                      const Text(
                        'NTRP Rating Range',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Visual range display
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            Text(
                              _minSkillLevel.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            Text(
                              _getSkillLevelName(_minSkillLevel),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Icon(Icons.arrow_forward, color: AppColors.primaryGreen),
                        ),
                        Column(
                          children: [
                            Text(
                              _maxSkillLevel.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            Text(
                              _getSkillLevelName(_maxSkillLevel),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Range slider
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Minimum'),
                          Text(
                            _minSkillLevel.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Slider(
                        value: _minSkillLevel,
                        min: 1.0,
                        max: 6.5,
                        divisions: 11,
                        activeColor: AppColors.primaryGreen,
                        onChanged: (value) {
                          setState(() {
                            _minSkillLevel = value;
                            if (_minSkillLevel > _maxSkillLevel) {
                              _maxSkillLevel = _minSkillLevel;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Maximum'),
                          Text(
                            _maxSkillLevel.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Slider(
                        value: _maxSkillLevel,
                        min: 1.5,
                        max: 7.0,
                        divisions: 11,
                        activeColor: AppColors.primaryGreen,
                        onChanged: (value) {
                          setState(() {
                            _maxSkillLevel = value;
                            if (_maxSkillLevel < _minSkillLevel) {
                              _minSkillLevel = _maxSkillLevel;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Quick presets
          const Text(
            'Quick Presets',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPresetChip('Beginner', 2.0, 3.0),
              _buildPresetChip('Intermediate', 3.0, 4.0),
              _buildPresetChip('Advanced', 4.0, 5.0),
              _buildPresetChip('Open Level', 1.0, 7.0),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Info box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'What is NTRP?',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'NTRP (National Tennis Rating Program) is a standard rating system:\n'
                  '• 1.0-2.5: Beginner\n'
                  '• 3.0-3.5: Intermediate\n'
                  '• 4.0-4.5: Advanced\n'
                  '• 5.0+: Expert/Tournament level',
                  style: TextStyle(color: Colors.blue[700], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, double min, double max) {
    return ActionChip(
      label: Text(label),
      onPressed: () {
        setState(() {
          _minSkillLevel = min;
          _maxSkillLevel = max;
        });
      },
      backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
      labelStyle: const TextStyle(color: AppColors.primaryGreen),
    );
  }

  String _getSkillLevelName(double ntrp) {
    if (ntrp < 2.5) return 'Beginner';
    if (ntrp < 3.5) return 'Intermediate';
    if (ntrp < 4.5) return 'Advanced';
    if (ntrp < 5.5) return 'Expert';
    return 'Pro';
  }

  Widget _buildScheduleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'When and where?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          
          // Date selection
          Card(
            child: ListTile(
              leading: const Icon(Icons.calendar_today, color: AppColors.primaryGreen),
              title: const Text('Date'),
              subtitle: Text(DateFormat('EEEE, MMMM d, y').format(_selectedDate)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 60)),
                );
                if (date != null) {
                  setState(() {
                    _selectedDate = date;
                  });
                }
              },
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Time selection
          Card(
            child: ListTile(
              leading: const Icon(Icons.access_time, color: AppColors.primaryGreen),
              title: const Text('Time'),
              subtitle: Text(_selectedTime.format(context)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime,
                );
                if (time != null) {
                  setState(() {
                    _selectedTime = time;
                  });
                }
              },
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Duration selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer, color: AppColors.primaryGreen),
                      const SizedBox(width: 8),
                      const Text(
                        'Duration',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildDurationChip(60, '1 hour'),
                      _buildDurationChip(90, '1.5 hours'),
                      _buildDurationChip(120, '2 hours'),
                      _buildDurationChip(150, '2.5 hours'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Court selection
          const Text(
            'Court Location',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          if (_selectedCourt != null) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on, color: AppColors.primaryGreen),
                title: Text(_selectedCourt!.name),
                subtitle: Text(_selectedCourt!.address),
                trailing: TextButton(
                  onPressed: () => _selectCourt(),
                  child: const Text('Change'),
                ),
              ),
            ),
          ] else ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on, color: Colors.orange),
                title: const Text('No court selected'),
                subtitle: const Text('Tap to select a court'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _selectCourt(),
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Additional notes
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.notes, color: AppColors.primaryGreen),
                      const SizedBox(width: 8),
                      const Text(
                        'Additional Notes (Optional)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Any special instructions or preferences...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      _notes = value;
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationChip(int minutes, String label) {
    final isSelected = _duration == minutes;
    
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _duration = minutes;
          });
        }
      },
      selectedColor: AppColors.primaryGreen,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
      ),
    );
  }

  Future<void> _selectCourt() async {
    final court = await Navigator.push<TennisCourt>(
      context,
      MaterialPageRoute(
        builder: (context) => const CourtDiscoveryScreen(
          isSelectionMode: true,
        ),
      ),
    );
    
    if (court != null) {
      setState(() {
        _selectedCourt = court;
      });
    }
  }

  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review your match',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          
          // Match summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildReviewItem(
                    Icons.sports_tennis,
                    'Match Type',
                    '${_matchType == MatchType.singles ? 'Singles' : 'Doubles'} - ${_matchFormat.displayName}',
                  ),
                  const Divider(),
                  _buildReviewItem(
                    Icons.timeline,
                    'Skill Level',
                    'NTRP ${_minSkillLevel.toStringAsFixed(1)} - ${_maxSkillLevel.toStringAsFixed(1)}',
                  ),
                  const Divider(),
                  _buildReviewItem(
                    Icons.calendar_today,
                    'Date & Time',
                    '${DateFormat('EEE, MMM d').format(_selectedDate)} at ${_selectedTime.format(context)}',
                  ),
                  const Divider(),
                  _buildReviewItem(
                    Icons.timer,
                    'Duration',
                    '$_duration minutes',
                  ),
                  if (_selectedCourt != null) ...[
                    const Divider(),
                    _buildReviewItem(
                      Icons.location_on,
                      'Court',
                      _selectedCourt!.name,
                    ),
                  ],
                  const Divider(),
                  _buildReviewItem(
                    _isPublic ? Icons.public : Icons.lock,
                    'Visibility',
                    _isPublic ? 'Public Match' : 'Private Match (Invite Code: $_inviteCode)',
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Save as template option
          Card(
            child: CheckboxListTile(
              title: const Text('Save as template'),
              subtitle: const Text('Use these settings for future matches'),
              value: _saveAsTemplate,
              onChanged: (value) {
                setState(() {
                  _saveAsTemplate = value!;
                });
              },
              activeColor: AppColors.primaryGreen,
            ),
          ),
          
          if (_saveAsTemplate) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Template Name',
                    hintText: 'e.g., Weekend Singles',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    _templateName = value;
                  },
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // Warning if court not selected
          if (_selectedCourt == null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please select a court before creating the match',
                      style: TextStyle(color: Colors.orange[700]),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primaryGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}