import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tennis_connect/providers/user_provider.dart';
import 'package:tennis_connect/constants/app_constants.dart';
import 'package:tennis_connect/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _isProfilePublic = true;
  bool _showLocation = true;
  bool _showMatchHistory = true;
  List<String> _blockedUsers = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<UserProvider>(context, listen: false).currentUser;
    if (user != null) {
      _isProfilePublic = user.isProfilePublic;
      _showLocation = user.showLocation;
      _showMatchHistory = user.showMatchHistory;
      _blockedUsers = List.from(user.blockedUsers);
    }
  }

  Future<void> _saveSettings() async {
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
      
      // Prepare update data for privacy settings
      final Map<String, dynamic> updateData = {
        'isProfilePublic': _isProfilePublic,
        'showLocation': _showLocation,
        'showMatchHistory': _showMatchHistory,
        'blockedUsers': _blockedUsers,
        'lastActive': FieldValue.serverTimestamp(),
      };
      
      print('Saving privacy settings: $updateData');
      
      // Update user document in Firestore
      await authService.updateUserProfile(currentUser.id, updateData);
      
      // Reload user data in provider
      await userProvider.loadCurrentUser();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Privacy settings updated')),
        );
        
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error saving privacy settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating settings: ${e.toString()}')),
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
        title: const Text('Privacy Settings'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveSettings,
            child: const Text('Save'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Visibility Section
            _buildSection(
              title: 'Profile Visibility',
              icon: Icons.visibility,
              children: [
                SwitchListTile(
                  title: const Text('Public Profile'),
                  subtitle: const Text('Allow all users to view your profile and send match invites'),
                  value: _isProfilePublic,
                  onChanged: (bool value) {
                    setState(() {
                      _isProfilePublic = value;
                    });
                  },
                  activeColor: AppColors.primaryGreen,
                ),
                if (!_isProfilePublic)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Only players you\'ve matched with can view your profile',
                            style: TextStyle(color: Colors.orange[700], fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            // Location Privacy Section
            _buildSection(
              title: 'Location Privacy',
              icon: Icons.location_on,
              children: [
                SwitchListTile(
                  title: const Text('Show Location'),
                  subtitle: const Text('Display your city on your profile'),
                  value: _showLocation,
                  onChanged: (bool value) {
                    setState(() {
                      _showLocation = value;
                    });
                  },
                  activeColor: AppColors.primaryGreen,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Your exact location is never shared. Only city and state are visible.',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ),
              ],
            ),

            // Match History Privacy Section
            _buildSection(
              title: 'Match History',
              icon: Icons.history,
              children: [
                SwitchListTile(
                  title: const Text('Show Match History'),
                  subtitle: const Text('Allow others to see your recent matches'),
                  value: _showMatchHistory,
                  onChanged: (bool value) {
                    setState(() {
                      _showMatchHistory = value;
                    });
                  },
                  activeColor: AppColors.primaryGreen,
                ),
                ListTile(
                  title: const Text('Clear Match History'),
                  subtitle: const Text('Remove all match records from your profile'),
                  trailing: const Icon(Icons.delete_forever, color: Colors.red),
                  onTap: _showClearHistoryDialog,
                ),
              ],
            ),

            // Blocked Users Section
            _buildSection(
              title: 'Blocked Users',
              icon: Icons.block,
              children: [
                if (_blockedUsers.isEmpty)
                  const ListTile(
                    title: Text('No blocked users'),
                    subtitle: Text('Users you block cannot view your profile or send you invites'),
                  )
                else
                  ..._blockedUsers.map((userId) => ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.person),
                    ),
                    title: Text('User $userId'), // In real app, fetch user name
                    trailing: TextButton(
                      onPressed: () => _unblockUser(userId),
                      child: const Text('Unblock'),
                    ),
                  )),
              ],
            ),

            // Data & Privacy Info
            _buildSection(
              title: 'Data & Privacy',
              icon: Icons.security,
              children: [
                ListTile(
                  leading: const Icon(Icons.policy),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // TODO: Navigate to privacy policy
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // TODO: Navigate to terms of service
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Download My Data'),
                  subtitle: const Text('Request a copy of your data'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    // TODO: Implement data download request
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete Account'),
                  subtitle: const Text('Permanently delete your account and data'),
                  onTap: _showDeleteAccountDialog,
                ),
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primaryGreen),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  void _unblockUser(String userId) {
    setState(() {
      _blockedUsers.remove(userId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User unblocked')),
    );
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Match History?'),
        content: const Text(
          'This will remove all match records from your profile. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement clear history
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Match history cleared')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Clear History'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently delete your account and all associated data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: Implement account deletion
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }
}