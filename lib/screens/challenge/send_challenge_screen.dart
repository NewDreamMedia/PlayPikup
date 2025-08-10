import 'package:flutter/material.dart';
import 'package:tennis_connect/models/user_model.dart';
import 'package:tennis_connect/models/match_model.dart';
import 'package:tennis_connect/models/tennis_court.dart';
import 'package:tennis_connect/services/match_challenge_service.dart';
import 'package:tennis_connect/screens/court_discovery_screen.dart';
import 'package:tennis_connect/constants/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SendChallengeScreen extends StatefulWidget {
  final UserModel challengedPlayer;
  final double playerDistance;

  const SendChallengeScreen({
    super.key,
    required this.challengedPlayer,
    required this.playerDistance,
  });

  @override
  State<SendChallengeScreen> createState() => _SendChallengeScreenState();
}

class _SendChallengeScreenState extends State<SendChallengeScreen> {
  final MatchChallengeService _challengeService = MatchChallengeService();
  final TextEditingController _messageController = TextEditingController();
  
  DateTime? _selectedDate;
  String? _selectedTime;
  TennisCourt? _selectedCourt;
  MatchType _matchType = MatchType.singles;
  MatchFormat _matchFormat = MatchFormat.bestOf3;
  int _duration = 60;
  bool _isSubmitting = false;

  final List<String> _timeSlots = [
    '6:00 AM', '7:00 AM', '8:00 AM', '9:00 AM', '10:00 AM', '11:00 AM',
    '12:00 PM', '1:00 PM', '2:00 PM', '3:00 PM', '4:00 PM', '5:00 PM',
    '6:00 PM', '7:00 PM', '8:00 PM', '9:00 PM',
  ];

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
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
      setState(() {
        _selectedCourt = court;
      });
    }
  }

  Future<void> _sendChallenge() async {
    if (_selectedDate == null || _selectedTime == null || _selectedCourt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _challengeService.createChallenge(
        challengedId: widget.challengedPlayer.id,
        challengedName: widget.challengedPlayer.displayName,
        courtId: _selectedCourt!.placeId,
        courtName: _selectedCourt!.name,
        courtAddress: _selectedCourt!.address,
        courtLocation: GeoPoint(
          _selectedCourt!.latitude,
          _selectedCourt!.longitude,
        ),
        proposedDate: _selectedDate,
        proposedTime: _selectedTime,
        duration: _duration,
        matchType: _matchType,
        matchFormat: _matchFormat,
        message: _messageController.text.trim().isEmpty 
            ? null 
            : _messageController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Challenge sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending challenge: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Challenge Player'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Player info card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.lightGreen,
                      backgroundImage: widget.challengedPlayer.photoUrl != null
                          ? NetworkImage(widget.challengedPlayer.photoUrl!)
                          : null,
                      child: widget.challengedPlayer.photoUrl == null
                          ? Text(
                              widget.challengedPlayer.displayName
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGreen,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.challengedPlayer.displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'NTRP ${widget.challengedPlayer.ntrpRating} • ${widget.playerDistance.toStringAsFixed(1)} mi away',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Match details section
            const Text(
              'Match Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Date selection
            ListTile(
              leading: const Icon(Icons.calendar_today, color: AppColors.primaryGreen),
              title: const Text('Date'),
              subtitle: Text(
                _selectedDate != null
                    ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                    : 'Select a date',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _selectDate,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Time selection
            ListTile(
              leading: const Icon(Icons.access_time, color: AppColors.primaryGreen),
              title: const Text('Time'),
              subtitle: Text(_selectedTime ?? 'Select a time'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showTimeSelection(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Court selection
            ListTile(
              leading: const Icon(Icons.sports_tennis, color: AppColors.primaryGreen),
              title: const Text('Court'),
              subtitle: Text(_selectedCourt?.name ?? 'Select a court'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _selectCourt,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Match format section
            const Text(
              'Match Format',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Match type
            Row(
              children: [
                Expanded(
                  child: RadioListTile<MatchType>(
                    title: const Text('Singles'),
                    value: MatchType.singles,
                    groupValue: _matchType,
                    onChanged: (value) {
                      setState(() {
                        _matchType = value!;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: RadioListTile<MatchType>(
                    title: const Text('Doubles'),
                    value: MatchType.doubles,
                    groupValue: _matchType,
                    onChanged: (value) {
                      setState(() {
                        _matchType = value!;
                      });
                    },
                  ),
                ),
              ],
            ),
            
            // Match format dropdown
            DropdownButtonFormField<MatchFormat>(
              value: _matchFormat,
              decoration: const InputDecoration(
                labelText: 'Format',
                border: OutlineInputBorder(),
              ),
              items: MatchFormat.values.map((format) {
                return DropdownMenuItem(
                  value: format,
                  child: Text((format as dynamic).displayName),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _matchFormat = value!;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // Duration
            Row(
              children: [
                const Text('Duration: '),
                Slider(
                  value: _duration.toDouble(),
                  min: 30,
                  max: 180,
                  divisions: 10,
                  label: '$_duration min',
                  onChanged: (value) {
                    setState(() {
                      _duration = value.toInt();
                    });
                  },
                ),
                Text('$_duration min'),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Message (optional)
            TextField(
              controller: _messageController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message (optional)',
                hintText: 'Add a personal message to your challenge...',
                border: OutlineInputBorder(),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Send button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _sendChallenge,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Send Challenge',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTimeSelection() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 300,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: ListView.builder(
          itemCount: _timeSlots.length,
          itemBuilder: (context, index) {
            final time = _timeSlots[index];
            return ListTile(
              title: Text(time),
              onTap: () {
                setState(() {
                  _selectedTime = time;
                });
                Navigator.pop(context);
              },
              trailing: _selectedTime == time
                  ? const Icon(Icons.check, color: AppColors.primaryGreen)
                  : null,
            );
          },
        ),
      ),
    );
  }
}