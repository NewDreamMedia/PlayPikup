import 'package:flutter/material.dart';

class AppConstants {
  // App Information
  static const String appName = 'PlayPickup';
  static const String appTagline = 'Find Your Court, Match Your Level, Play Your Game';
  
  // Firebase Collections
  static const String usersCollection = 'users';
  static const String courtsCollection = 'courts';
  static const String matchesCollection = 'matches';
  static const String messagesCollection = 'messages';
  static const String ratingsCollection = 'ratings';
  
  // NTRP Ratings
  static const List<double> ntrpRatings = [
    2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 5.5
  ];
  
  static final Map<double, String> ntrpDescriptions = {
    2.5: 'Beginner - Learning basic shots',
    3.0: 'Intermediate - Consistent shots, developing strategy',
    3.5: 'Intermediate+ - Good shot variety, improving consistency',
    4.0: 'Advanced - Strong shots, good strategy',
    4.5: 'Advanced+ - Power and accuracy, excellent strategy',
    5.0: 'Expert - Tournament level player',
    5.5: 'Expert+ - Competitive tournament player',
  };
  
  // Playing Styles
  static const List<String> playingStyles = [
    'Baseline',
    'Serve and Volley',
    'All-Court',
    'Defensive',
    'Aggressive',
  ];
  
  // Court Surfaces
  static const List<String> courtSurfaces = [
    'Hard Court',
    'Clay',
    'Grass',
    'Indoor Hard',
    'Carpet',
  ];
  
  // Match Formats
  static final Map<String, String> matchFormats = {
    'best_of_3': 'Best of 3 Sets',
    'best_of_1': 'Single Set',
    'pro_set': 'Pro Set (First to 8)',
    'practice': 'Practice Session',
    'tiebreak': '10-Point Tiebreak',
  };
  
  // Days of Week
  static const List<String> daysOfWeek = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  
  // Playing Times
  static const List<String> playingTimes = [
    'Early Morning (6-8 AM)',
    'Morning (8-11 AM)',
    'Midday (11 AM-2 PM)',
    'Afternoon (2-5 PM)',
    'Evening (5-8 PM)',
    'Night (8-10 PM)',
  ];
  
  // Court Amenities
  static const List<String> courtAmenities = [
    'Lighting',
    'Pro Shop',
    'Restrooms',
    'Parking',
    'Water Fountain',
    'Seating',
    'Ball Machine',
    'Locker Rooms',
  ];
  
  // Premium Features
  static const double monthlyPremiumPrice = 9.99;
  static const double yearlyPremiumPrice = 99.99;
  
  // Map Constants
  static const double defaultZoom = 13.0;
  static const double searchRadiusMiles = 25.0;
  
  // Validation
  static const int minPasswordLength = 6;
  static const int maxDisplayNameLength = 30;
  static const int maxMatchNotes = 200;
  
  // Pagination
  static const int matchesPerPage = 20;
  static const int courtsPerPage = 15;
  static const int messagesPerPage = 50;
}

// App Colors
class AppColors {
  static const Color primaryGreen = Color(0xFF2E7D32);
  static const Color lightGreen = Color(0xFF66BB6A);
  static const Color darkGreen = Color(0xFF1B5E20);
  static const Color courtClay = Color(0xFFD84315);
  static const Color courtGrass = Color(0xFF558B2F);
  static const Color courtHard = Color(0xFF0277BD);
  static const Color gold = Color(0xFFFFB300);
  static const Color silver = Color(0xFF9E9E9E);
  static const Color bronze = Color(0xFF8D6E63);
  
  // Status Colors
  static const Color confirmed = Color(0xFF4CAF50);
  static const Color pending = Color(0xFFFFA726);
  static const Color cancelled = Color(0xFFEF5350);
  
  // Background Colors
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color backgroundDark = Color(0xFF121212);
}