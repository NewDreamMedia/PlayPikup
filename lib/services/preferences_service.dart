import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  static const String _distanceUnitKey = 'distance_unit';
  static const String _searchRadiusKey = 'search_radius';
  
  // Get distance unit preference (true = miles, false = km)
  Future<bool> getUseMiles() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_distanceUnitKey) ?? false; // Default to km
  }
  
  // Set distance unit preference
  Future<void> setUseMiles(bool useMiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_distanceUnitKey, useMiles);
  }
  
  // Get last search radius
  Future<String> getSearchRadius() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_searchRadiusKey) ?? '5'; // Default to 5
  }
  
  // Set last search radius
  Future<void> setSearchRadius(String radius) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_searchRadiusKey, radius);
  }
  
  // Clear all preferences
  Future<void> clearPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}