import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tennis_connect/services/auth_service.dart';
import 'package:tennis_connect/providers/user_provider.dart';
import 'package:tennis_connect/constants/app_constants.dart';
import 'package:tennis_connect/screens/court_discovery_screen.dart';
import 'package:tennis_connect/screens/matches_page.dart';
import 'package:tennis_connect/screens/profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const CourtDiscoveryScreen(),
    const MatchesPage(),
    const MessagesPage(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Load user data when home screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UserProvider>(context, listen: false).loadCurrentUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primaryGreen,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on),
            label: 'Courts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_tennis),
            label: 'Matches',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.message),
            label: 'Messages',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// Placeholder page
class CourtFinderPage extends StatelessWidget {
  const CourtFinderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Courts'),
        automaticallyImplyLeading: false,
      ),
      body: const Center(
        child: Text('Court Finder - Coming Soon'),
      ),
    );
  }
}

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        automaticallyImplyLeading: false,
      ),
      body: const Center(
        child: Text('Messages - Coming Soon'),
      ),
    );
  }
}

