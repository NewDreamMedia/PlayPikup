import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tennis_connect/providers/user_provider.dart';
import 'package:tennis_connect/services/auth_service.dart';
import 'package:tennis_connect/constants/app_constants.dart';
import 'package:tennis_connect/screens/profile/edit_profile_screen.dart';
import 'package:tennis_connect/screens/profile/privacy_settings_screen.dart';
import 'package:tennis_connect/screens/profile/match_preferences_screen.dart';
import 'package:tennis_connect/screens/profile/achievements_screen.dart';
import 'package:tennis_connect/screens/debug/test_database_connection.dart';
import 'package:tennis_connect/screens/admin/migration_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final user = userProvider.currentUser;
    final authService = Provider.of<AuthService>(context, listen: false);

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrivacySettingsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await authService.signOut();
              userProvider.clearUser();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header Section
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: AppColors.primaryGreen,
                        backgroundImage: user.photoUrl != null
                            ? NetworkImage(user.photoUrl!)
                            : null,
                        child: user.photoUrl == null
                            ? Text(
                                user.displayName[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 40,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const EditProfileScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${user.city}, ${user.state}',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Skill Level Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.primaryGreen),
                    ),
                    child: Text(
                      'NTRP ${user.ntrpRating} - ${_getSkillLevelText(user.ntrpRating)}',
                      style: TextStyle(
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Stats Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatCard('Matches', user.matchesPlayed.toString()),
                  _buildStatCard('Wins', user.matchesWon.toString()),
                  _buildStatCard(
                    'Win Rate',
                    user.matchesPlayed > 0
                        ? '${((user.matchesWon / user.matchesPlayed) * 100).round()}%'
                        : '0%',
                  ),
                  _buildStatCard(
                    'Reliability',
                    '${user.reliabilityScore.toStringAsFixed(1)}★',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Achievement Badges Section
            if (user.achievements.isNotEmpty) ...[
              _buildSectionHeader('Achievements', onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AchievementsScreen(),
                  ),
                );
              }),
              Container(
                height: 80,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: user.achievements.length > 5 ? 5 : user.achievements.length,
                  itemBuilder: (context, index) {
                    return _buildAchievementBadge(user.achievements[index]);
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Profile Sections
            _buildProfileSection(
              title: 'Match Preferences',
              icon: Icons.sports_tennis,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MatchPreferencesScreen(),
                  ),
                );
              },
              children: [
                _buildInfoRow('Playing Style', user.playingStyle),
                _buildInfoRow('Match Types', user.preferredMatchTypes.join(', ')),
                _buildInfoRow('Court Surfaces', user.preferredCourtSurfaces.join(', ')),
                _buildInfoRow('Max Distance', '${user.maxDistanceKm} km'),
              ],
            ),

            _buildProfileSection(
              title: 'Availability',
              icon: Icons.calendar_today,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MatchPreferencesScreen(),
                  ),
                );
              },
              children: [
                _buildInfoRow('Preferred Times', user.preferredPlayingTimes.join(', ')),
                _buildAvailabilityGrid(user.availability),
              ],
            ),

            // Match History Section (if public)
            if (user.showMatchHistory && user.matchHistory.isNotEmpty) ...[
              _buildSectionHeader('Recent Matches'),
              ...user.matchHistory.take(5).map((match) => 
                _buildMatchHistoryItem(match),
              ),
            ],

            const SizedBox(height: 24),
            
            // Temporary Admin Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  // Migration Button
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MigrationScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.update),
                    label: const Text('Database Migration'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Test Button
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TestDatabaseConnectionScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: const Text('Test Database Connection'),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
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
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (onTap != null)
            TextButton(
              onPressed: onTap,
              child: const Text('See All'),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: AppColors.primaryGreen),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (onTap != null)
                    const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityGrid(Map<String, bool> availability) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayKeys = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Row(
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
      ),
    );
  }

  Widget _buildAchievementBadge(String achievementId) {
    // This would be enhanced with actual achievement data
    final achievementIcons = {
      'first_match': Icons.sports_tennis,
      '5_matches': Icons.looks_5,
      'punctual': Icons.access_time,
      'win_streak': Icons.local_fire_department,
      'social': Icons.people,
    };

    return Container(
      margin: const EdgeInsets.only(right: 12),
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.primaryGreen, width: 2),
      ),
      child: Icon(
        achievementIcons[achievementId] ?? Icons.emoji_events,
        color: AppColors.primaryGreen,
        size: 30,
      ),
    );
  }

  Widget _buildMatchHistoryItem(Map<String, dynamic> match) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'vs ${match['opponentName'] ?? 'Unknown'}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              Text(
                '${match['matchType'] ?? 'Singles'} • ${match['score'] ?? 'No score'}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          Text(
            match['date'] ?? '',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  String _getSkillLevelText(double ntrp) {
    if (ntrp < 2.5) return 'Beginner';
    if (ntrp < 3.5) return 'Intermediate';
    if (ntrp < 4.5) return 'Advanced';
    return 'Expert';
  }
}