import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tennis_connect/providers/user_provider.dart';
import 'package:tennis_connect/constants/app_constants.dart';
import 'package:tennis_connect/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MatchPreferencesScreen extends StatefulWidget {
  const MatchPreferencesScreen({super.key});

  @override
  State<MatchPreferencesScreen> createState() => _MatchPreferencesScreenState();
}

class _MatchPreferencesScreenState extends State<MatchPreferencesScreen> {
  // Match Preferences
  List<String> _preferredMatchTypes = [];
  List<String> _preferredCourtSurfaces = [];
  double _maxDistanceKm = 10.0;
  
  // Availability
  Map<String, bool> _availability = {};
  List<String> _preferredPlayingTimes = [];
  List<Map<String, dynamic>> _weeklyAvailability = [];
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<UserProvider>(context, listen: false).currentUser;
    if (user != null) {
      _preferredMatchTypes = List.from(user.preferredMatchTypes);
      _preferredCourtSurfaces = List.from(user.preferredCourtSurfaces);
      _maxDistanceKm = user.maxDistanceKm;
      _availability = Map.from(user.availability);
      _preferredPlayingTimes = List.from(user.preferredPlayingTimes);
      _weeklyAvailability = List.from(user.weeklyAvailability);
    }
  }

  Future<void> _savePreferences() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final authService = AuthService();
      final currentUser = userProvider.currentUser;
      
      if (currentUser == null) {
        throw Exception('No user logged in');
      }
      
      // Prepare update data for match preferences
      final Map<String, dynamic> updateData = {
        'preferredMatchTypes': _preferredMatchTypes,
        'preferredCourtSurfaces': _preferredCourtSurfaces,
        'maxDistanceKm': _maxDistanceKm,
        'availability': _availability,
        'preferredPlayingTimes': _preferredPlayingTimes,
        'weeklyAvailability': _weeklyAvailability,
        'lastActive': FieldValue.serverTimestamp(),
      };
      
      print('Saving match preferences: $updateData');
      
      // Update user document in Firestore
      await authService.updateUserProfile(currentUser.id, updateData);
      
      // Reload user data in provider
      await userProvider.loadCurrentUser();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences saved successfully')),
        );
        
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error saving match preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving preferences: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Preferences'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _savePreferences,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Match Type Preferences
            _buildSectionTitle('Match Types'),
            _buildMatchTypeSelection(),
            const SizedBox(height: 24),

            // Court Surface Preferences
            _buildSectionTitle('Court Surfaces'),
            _buildCourtSurfaceSelection(),
            const SizedBox(height: 24),

            // Distance Preference
            _buildSectionTitle('Maximum Distance'),
            _buildDistanceSlider(),
            const SizedBox(height: 24),

            // Availability
            _buildSectionTitle('Weekly Availability'),
            _buildAvailabilitySection(),
            const SizedBox(height: 24),

            // Preferred Playing Times
            _buildSectionTitle('Preferred Playing Times'),
            _buildPlayingTimesSelection(),
            const SizedBox(height: 24),

            // Detailed Time Slots
            _buildSectionTitle('Specific Time Slots'),
            _buildTimeSlotsList(),
            const SizedBox(height: 32),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _savePreferences,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Save Preferences',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMatchTypeSelection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            title: const Text('Singles'),
            subtitle: const Text('1 vs 1 matches'),
            value: _preferredMatchTypes.contains('singles'),
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _preferredMatchTypes.add('singles');
                } else {
                  _preferredMatchTypes.remove('singles');
                }
              });
            },
            activeColor: AppColors.primaryGreen,
          ),
          CheckboxListTile(
            title: const Text('Doubles'),
            subtitle: const Text('2 vs 2 matches'),
            value: _preferredMatchTypes.contains('doubles'),
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  _preferredMatchTypes.add('doubles');
                } else {
                  _preferredMatchTypes.remove('doubles');
                }
              });
            },
            activeColor: AppColors.primaryGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildCourtSurfaceSelection() {
    final surfaces = ['hard', 'clay', 'grass', 'indoor'];
    final surfaceNames = ['Hard Court', 'Clay', 'Grass', 'Indoor'];
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(surfaces.length, (index) {
        final surface = surfaces[index];
        final isSelected = _preferredCourtSurfaces.contains(surface);
        
        return FilterChip(
          label: Text(surfaceNames[index]),
          selected: isSelected,
          onSelected: (bool selected) {
            setState(() {
              if (selected) {
                _preferredCourtSurfaces.add(surface);
              } else {
                _preferredCourtSurfaces.remove(surface);
              }
            });
          },
          selectedColor: AppColors.primaryGreen.withOpacity(0.2),
          checkmarkColor: AppColors.primaryGreen,
        );
      }),
    );
  }

  Widget _buildDistanceSlider() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Within'),
            Text(
              '${_maxDistanceKm.round()} km',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
        Slider(
          value: _maxDistanceKm,
          min: 1,
          max: 50,
          divisions: 49,
          activeColor: AppColors.primaryGreen,
          onChanged: (value) {
            setState(() {
              _maxDistanceKm = value;
            });
          },
        ),
        Text(
          'Maximum distance you\'re willing to travel for matches',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildAvailabilitySection() {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: List.generate(7, (index) {
          final dayKey = dayKeys[index];
          final isAvailable = _availability[dayKey] ?? false;
          
          return CheckboxListTile(
            title: Text(days[index]),
            value: isAvailable,
            onChanged: (bool? value) {
              setState(() {
                _availability[dayKey] = value ?? false;
              });
            },
            activeColor: AppColors.primaryGreen,
            dense: true,
          );
        }),
      ),
    );
  }

  Widget _buildPlayingTimesSelection() {
    final times = ['morning', 'afternoon', 'evening'];
    final timeNames = ['Morning (6 AM - 12 PM)', 'Afternoon (12 PM - 6 PM)', 'Evening (6 PM - 10 PM)'];
    
    return Column(
      children: List.generate(times.length, (index) {
        final time = times[index];
        final isSelected = _preferredPlayingTimes.contains(time);
        
        return CheckboxListTile(
          title: Text(timeNames[index]),
          value: isSelected,
          onChanged: (bool? value) {
            setState(() {
              if (value == true) {
                _preferredPlayingTimes.add(time);
              } else {
                _preferredPlayingTimes.remove(time);
              }
            });
          },
          activeColor: AppColors.primaryGreen,
        );
      }),
    );
  }

  Widget _buildTimeSlotsList() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Add specific time slots when you\'re regularly available',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        
        // Add time slot button
        OutlinedButton.icon(
          onPressed: _showAddTimeSlotDialog,
          icon: const Icon(Icons.add),
          label: const Text('Add Time Slot'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryGreen,
            side: const BorderSide(color: AppColors.primaryGreen),
          ),
        ),
        
        // List of time slots
        if (_weeklyAvailability.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._weeklyAvailability.map((slot) => _buildTimeSlotItem(slot)),
        ],
      ],
    );
  }

  Widget _buildTimeSlotItem(Map<String, dynamic> slot) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.access_time, color: AppColors.primaryGreen),
        title: Text('${slot['day']} ${slot['startTime']} - ${slot['endTime']}'),
        subtitle: slot['recurring'] == true 
            ? const Text('Recurring weekly')
            : Text('One time: ${slot['date']}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () {
            setState(() {
              _weeklyAvailability.remove(slot);
            });
          },
        ),
      ),
    );
  }

  void _showAddTimeSlotDialog() {
    // TODO: Implement dialog to add specific time slots
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Time Slot'),
        content: const Text('Time slot selection coming soon'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement time slot addition
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}