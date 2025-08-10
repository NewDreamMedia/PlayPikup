import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tennis_connect/providers/user_provider.dart';
import 'package:tennis_connect/constants/app_constants.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).currentUser;
    
    // Define all available achievements
    final allAchievements = [
      Achievement(
        id: 'first_match',
        name: 'First Match',
        description: 'Played your first match',
        icon: Icons.sports_tennis,
        category: 'Milestones',
      ),
      Achievement(
        id: '5_matches',
        name: 'Getting Started',
        description: 'Completed 5 matches',
        icon: Icons.looks_5,
        category: 'Milestones',
      ),
      Achievement(
        id: '10_matches',
        name: 'Regular Player',
        description: 'Completed 10 matches',
        icon: Icons.trending_up,
        category: 'Milestones',
      ),
      Achievement(
        id: '25_matches',
        name: 'Tennis Enthusiast',
        description: 'Completed 25 matches',
        icon: Icons.star,
        category: 'Milestones',
      ),
      Achievement(
        id: '50_matches',
        name: 'Dedicated Player',
        description: 'Completed 50 matches',
        icon: Icons.emoji_events,
        category: 'Milestones',
      ),
      Achievement(
        id: 'punctual',
        name: 'Punctual Player',
        description: 'Always on time for matches',
        icon: Icons.access_time,
        category: 'Reliability',
      ),
      Achievement(
        id: 'reliable',
        name: 'Reliable Partner',
        description: 'Maintained 5.0 reliability score',
        icon: Icons.verified,
        category: 'Reliability',
      ),
      Achievement(
        id: 'win_streak_3',
        name: 'On Fire',
        description: 'Won 3 matches in a row',
        icon: Icons.local_fire_department,
        category: 'Performance',
      ),
      Achievement(
        id: 'win_streak_5',
        name: 'Unstoppable',
        description: 'Won 5 matches in a row',
        icon: Icons.whatshot,
        category: 'Performance',
      ),
      Achievement(
        id: 'social',
        name: 'Social Butterfly',
        description: 'Played with 10 different partners',
        icon: Icons.people,
        category: 'Social',
      ),
      Achievement(
        id: 'explorer',
        name: 'Court Explorer',
        description: 'Played at 5 different courts',
        icon: Icons.explore,
        category: 'Explorer',
      ),
      Achievement(
        id: 'early_bird',
        name: 'Early Bird',
        description: 'Played 10 morning matches',
        icon: Icons.wb_sunny,
        category: 'Playing Style',
      ),
      Achievement(
        id: 'night_owl',
        name: 'Night Owl',
        description: 'Played 10 evening matches',
        icon: Icons.nightlight,
        category: 'Playing Style',
      ),
    ];

    // Group achievements by category
    final achievementsByCategory = <String, List<Achievement>>{};
    for (final achievement in allAchievements) {
      achievementsByCategory.putIfAbsent(achievement.category, () => []);
      achievementsByCategory[achievement.category]!.add(achievement);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
      ),
      body: ListView(
        children: [
          // Stats Header
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.primaryGreen.withOpacity(0.1),
            child: Column(
              children: [
                Text(
                  '${user?.achievements.length ?? 0}',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const Text(
                  'Achievements Earned',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: (user?.achievements.length ?? 0) / allAchievements.length,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                ),
                const SizedBox(height: 4),
                Text(
                  '${((user?.achievements.length ?? 0) / allAchievements.length * 100).round()}% Complete',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          // Achievements by Category
          ...achievementsByCategory.entries.map((entry) {
            final category = entry.key;
            final achievements = entry.value;
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...achievements.map((achievement) {
                  final isEarned = user?.achievements.contains(achievement.id) ?? false;
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    elevation: isEarned ? 2 : 0,
                    color: isEarned ? Colors.white : Colors.grey[100],
                    child: ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isEarned 
                              ? AppColors.primaryGreen.withOpacity(0.1)
                              : Colors.grey[300],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isEarned ? AppColors.primaryGreen : Colors.grey[400]!,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          achievement.icon,
                          color: isEarned ? AppColors.primaryGreen : Colors.grey[400],
                          size: 24,
                        ),
                      ),
                      title: Text(
                        achievement.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isEarned ? Colors.black : Colors.grey[600],
                        ),
                      ),
                      subtitle: Text(
                        achievement.description,
                        style: TextStyle(
                          color: isEarned ? Colors.grey[700] : Colors.grey[500],
                        ),
                      ),
                      trailing: isEarned
                          ? const Icon(
                              Icons.check_circle,
                              color: AppColors.primaryGreen,
                            )
                          : Icon(
                              Icons.lock_outline,
                              color: Colors.grey[400],
                            ),
                    ),
                  );
                }),
              ],
            );
          }),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class Achievement {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final String category;

  Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
  });
}