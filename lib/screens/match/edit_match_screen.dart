import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tennis_connect/models/match_model.dart';
import 'package:tennis_connect/services/match_service.dart';
import 'package:tennis_connect/constants/app_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditMatchScreen extends StatefulWidget {
  final MatchModel match;

  const EditMatchScreen({super.key, required this.match});

  @override
  State<EditMatchScreen> createState() => _EditMatchScreenState();
}

class _EditMatchScreenState extends State<EditMatchScreen> {
  final _formKey = GlobalKey<FormState>();
  final MatchService _matchService = MatchService();
  
  late MatchType _matchType;
  late MatchFormat _matchFormat;
  late DateTime _matchDate;
  late TimeOfDay _matchTime;
  late int _duration;
  late double _minSkillLevel;
  late double _maxSkillLevel;
  late bool _isPublic;
  late String _notes;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _matchType = widget.match.matchType;
    _matchFormat = widget.match.matchFormat;
    _matchDate = widget.match.matchDate;
    _duration = widget.match.duration;
    _minSkillLevel = widget.match.minNtrpRating;
    _maxSkillLevel = widget.match.maxNtrpRating;
    _isPublic = widget.match.isPublic;
    _notes = widget.match.notes ?? '';
    
    // Parse time from string
    final timeParts = widget.match.matchTime.split(' ');
    final hourMinute = timeParts[0].split(':');
    var hour = int.parse(hourMinute[0]);
    final minute = int.parse(hourMinute[1]);
    final isPM = timeParts.length > 1 && timeParts[1].toUpperCase() == 'PM';
    
    if (isPM && hour != 12) hour += 12;
    if (!isPM && hour == 12) hour = 0;
    
    _matchTime = TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _matchDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null && picked != _matchDate) {
      setState(() {
        _matchDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _matchTime,
    );
    
    if (picked != null && picked != _matchTime) {
      setState(() {
        _matchTime = picked;
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '${hour}:${time.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final updates = <String, dynamic>{
        'matchType': _matchType.name,
        'matchFormat': _matchFormat.name,
        'matchDate': Timestamp.fromDate(_matchDate),
        'matchTime': _formatTime(_matchTime),
        'duration': _duration,
        'minNtrpRating': _minSkillLevel,
        'maxNtrpRating': _maxSkillLevel,
        'isPublic': _isPublic,
        'notes': _notes.isEmpty ? null : _notes,
      };
      
      await _matchService.editMatch(
        widget.match.id,
        widget.match.creatorId,
        updates,
      );
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Match updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating match: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Match'),
        backgroundColor: AppColors.primaryGreen,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<MatchType>(
                        segments: const [
                          ButtonSegment(
                            value: MatchType.singles,
                            label: Text('Singles'),
                          ),
                          ButtonSegment(
                            value: MatchType.doubles,
                            label: Text('Doubles'),
                          ),
                        ],
                        selected: {_matchType},
                        onSelectionChanged: (Set<MatchType> selected) {
                          setState(() {
                            _matchType = selected.first;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Format
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Match Format',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<MatchFormat>(
                        value: _matchFormat,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                        ),
                        items: MatchFormat.values.map((format) {
                          return DropdownMenuItem(
                            value: format,
                            child: Text(format.displayName),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _matchFormat = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Date and Time
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Date & Time',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ListTile(
                              title: const Text('Date'),
                              subtitle: Text(DateFormat('MMM dd, yyyy').format(_matchDate)),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: _selectDate,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: Colors.grey),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ListTile(
                              title: const Text('Time'),
                              subtitle: Text(_formatTime(_matchTime)),
                              trailing: const Icon(Icons.access_time),
                              onTap: _selectTime,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: Colors.grey),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: _duration.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Duration (minutes)',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter duration';
                          }
                          final duration = int.tryParse(value);
                          if (duration == null || duration < 30 || duration > 300) {
                            return 'Duration must be between 30 and 300 minutes';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          _duration = int.tryParse(value) ?? _duration;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Skill Level Range
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Skill Level Range',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'NTRP ${_minSkillLevel.toStringAsFixed(1)} - ${_maxSkillLevel.toStringAsFixed(1)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                      RangeSlider(
                        values: RangeValues(_minSkillLevel, _maxSkillLevel),
                        min: 2.5,
                        max: 5.0,
                        divisions: 10,
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
              
              // Public/Private
              Card(
                child: SwitchListTile(
                  title: const Text('Public Match'),
                  subtitle: Text(
                    _isPublic 
                      ? 'Anyone can join this match' 
                      : 'Only invited players can join',
                  ),
                  value: _isPublic,
                  onChanged: (value) {
                    setState(() {
                      _isPublic = value;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              
              // Notes
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextFormField(
                    initialValue: _notes,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'Add any additional information...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    onChanged: (value) {
                      _notes = value;
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                  ),
                  child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}