import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:mapbox_search/mapbox_search.dart' as mapbox;
import 'package:tennis_connect/config/api_keys.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  late final mapbox.GeoCoding _mapboxGeoCoding = mapbox.GeoCoding(
    apiKey: ApiKeys.mapboxAccessToken,
    limit: 10,
  );

  // Check and request location permissions
  Future<bool> checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // Get current user location
  Future<Position?> getCurrentLocation() async {
    final hasPermission = await checkLocationPermission();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting current location: $e');
      return null;
    }
  }

  // Geocode address to coordinates using Geocoding package
  Future<geocoding.Location?> geocodeAddress(String address) async {
    try {
      List<geocoding.Location> locations = await geocoding.locationFromAddress(address);
      if (locations.isNotEmpty) {
        return locations.first;
      }
    } catch (e) {
      print('Error geocoding address: $e');
    }
    return null;
  }

  // Reverse geocode coordinates to address
  Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (placemarks.isNotEmpty) {
        geocoding.Placemark place = placemarks[0];
        return '${place.street}, ${place.locality}, ${place.administrativeArea} ${place.postalCode}';
      }
    } catch (e) {
      print('Error reverse geocoding: $e');
    }
    return null;
  }

  // Search locations using Mapbox
  Future<List<mapbox.MapBoxPlace>> searchLocations(String query) async {
    try {
      final response = await _mapboxGeoCoding.getPlaces(
        query,
      );
      return response.success ?? [];
    } catch (e) {
      print('Error searching locations with Mapbox: $e');
      return [];
    }
  }

  // Calculate distance between two points
  double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  // Convert meters to miles
  double metersToMiles(double meters) {
    return meters * 0.000621371;
  }

  // Convert meters to kilometers
  double metersToKilometers(double meters) {
    return meters / 1000;
  }
  
  // Convert miles to meters
  double milesToMeters(double miles) {
    return miles * 1609.344;
  }
  
  // Convert kilometers to meters
  double kilometersToMeters(double kilometers) {
    return kilometers * 1000;
  }
  
  // Format distance based on unit preference
  String formatDistance(double meters, {bool useMiles = false}) {
    if (useMiles) {
      final miles = metersToMiles(meters);
      if (miles < 0.1) {
        // Show in feet for very short distances
        final feet = meters * 3.28084;
        return '${feet.toStringAsFixed(0)} ft';
      } else if (miles < 1) {
        return '${miles.toStringAsFixed(2)} mi';
      } else {
        return '${miles.toStringAsFixed(1)} mi';
      }
    } else {
      final km = metersToKilometers(meters);
      if (meters < 1000) {
        return '${meters.toStringAsFixed(0)} m';
      } else {
        return '${km.toStringAsFixed(1)} km';
      }
    }
  }
}