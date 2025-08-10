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

class CreateMatchScreen extends StatefulWidget {
  final TennisCourt? preselectedCourt;

  const CreateMatchScreen({
    super.key,
    this.preselectedCourt,
  });

  @override
  State<CreateMatchScreen> createState() => _CreateMatchScreenState();
}

class _CreateMatchScreenState extends State<CreateMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final _matchService = MatchService();
  
  // Form controllers
  final _notesController = TextEditingController();
  
  // Form data
  MatchType _matchType = MatchType.singles;
  MatchFormat _matchFormat = MatchFormat.bestOf3;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  int _duration = 90; // minutes
  double _minSkillLevel = 2.5;
  double _maxSkillLevel = 4.5;
  double _maxDistance = 10.0; // km
  bool _isPublic = true;
  TennisCourt? _selectedCourt;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedCourt = widget.preselectedCourt;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
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
    
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
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
    
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _selectCourt() async {
    final court = await Navigator.push<TennisCourt>(
      context,
      MaterialPageRoute(
        builder: (context) => const CourtDiscoveryScreen(isSelectionMode: true),
      ),
    );
    
    if (court != null) {
      setState(() => _selectedCourt = court);
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour}:${time.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _createMatch() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCourt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a court'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Provider.of<UserProvider>(context, listen: false).currentUser;
      final authService = Provider.of<AuthService>(context, listen: false);
      
      if (user == null || authService.currentUser == null) {
        throw Exception('User not logged in');
      }

      // Combine date and time
      final matchDateTime = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final match = MatchModel(
        id: '', // Will be set by Firestore
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
        matchTime: _formatTime(_selectedTime),
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
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: DateTime.now(),
      );

      await _matchService.createMatch(match);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Match created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating match: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Match'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Match Type
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Match Type',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<MatchType>(
                      segments: const [
                        ButtonSegment(
                          value: MatchType.singles,
                          label: Text('Singles'),
                          icon: Icon(Icons.person),
                        ),
                        ButtonSegment(
                          value: MatchType.doubles,
                          label: Text('Doubles'),
                          icon: Icon(Icons.group),
                        ),
                      ],
                      selected: {_matchType},
                      onSelectionChanged: (Set<MatchType> selection) {
                        setState(() => _matchType = selection.first);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Match Format
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Match Format',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<MatchFormat>(
                      value: _matchFormat,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      items: MatchFormat.values.map((format) {
                        return DropdownMenuItem(
                          value: format,
                          child: Text(format.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _matchFormat = value!);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Date & Time
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Date & Time',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _selectDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(
                                DateFormat('MMM dd, yyyy').format(_selectedDate),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: _selectTime,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Time',
                                prefixIcon: Icon(Icons.access_time),
                              ),
                              child: Text(_formatTime(_selectedTime)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: _duration,
                      decoration: const InputDecoration(
                        labelText: 'Duration',
                        prefixIcon: Icon(Icons.timer),
                      ),
                      items: [60, 90, 120, 150, 180].map((minutes) {
                        final hours = minutes ~/ 60;
                        final mins = minutes % 60;
                        final text = hours > 0
                            ? '${hours}h ${mins > 0 ? '${mins}m' : ''}'
                            : '${mins}m';
                        return DropdownMenuItem(
                          value: minutes,
                          child: Text(text),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _duration = value!);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Court Selection
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Court',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_selectedCourt != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: AppColors.primaryGreen,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedCourt!.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    _selectedCourt!.address,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                setState(() => _selectedCourt = null);
                              },
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      OutlinedButton.icon(
                        onPressed: _selectCourt,
                        icon: const Icon(Icons.search),
                        label: const Text('Select Court'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Skill Level Requirements
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Skill Level Requirements',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'NTRP Rating Range: ${_minSkillLevel.toStringAsFixed(1)} - ${_maxSkillLevel.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    RangeSlider(
                      values: RangeValues(_minSkillLevel, _maxSkillLevel),
                      min: 1.0,
                      max: 7.0,
                      divisions: 12,
                      activeColor: AppColors.primaryGreen,
                      labels: RangeLabels(
                        _minSkillLevel.toStringAsFixed(1),
                        _maxSkillLevel.toStringAsFixed(1),
                      ),
                      onChanged: (values) {
                        setState(() {
                          _minSkillLevel = values.start;
                          _maxSkillLevel = values.end;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Player Proximity
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Player Proximity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Maximum distance: ${_maxDistance.toStringAsFixed(0)} km',
                      style: const TextStyle(fontSize: 16),
                    ),
                    Slider(
                      value: _maxDistance,
                      min: 1,
                      max: 50,
                      divisions: 49,
                      activeColor: AppColors.primaryGreen,
                      label: '${_maxDistance.toStringAsFixed(0)} km',
                      onChanged: (value) {
                        setState(() => _maxDistance = value);
                      },
                    ),
                    Text(
                      'Only players within this distance can join',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Match Settings
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Match Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      title: const Text('Public Match'),
                      subtitle: const Text('Allow anyone to join'),
                      value: _isPublic,
                      activeColor: AppColors.primaryGreen,
                      onChanged: (value) {
                        setState(() => _isPublic = value);
                      },
                    ),
                    const Divider(),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Additional Notes (Optional)',
                        hintText: 'Any special instructions or requirements...',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Create Button
            ElevatedButton(
              onPressed: _isLoading ? null : _createMatch,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: AppColors.primaryGreen,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Create Match',
                      style: TextStyle(fontSize: 16),
                    ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}