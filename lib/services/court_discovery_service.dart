import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tennis_connect/config/api_keys.dart';
import 'package:tennis_connect/models/tennis_court.dart';
import 'package:tennis_connect/services/location_service.dart';

class CourtDiscoveryService {
  static final CourtDiscoveryService _instance = CourtDiscoveryService._internal();
  factory CourtDiscoveryService() => _instance;
  CourtDiscoveryService._internal();

  final Dio _dio = Dio();
  final LocationService _locationService = LocationService();
  
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';

  // Search for tennis courts near a location
  Future<List<TennisCourt>> searchTennisCourts({
    required double latitude,
    required double longitude,
    int radius = 5000, // Default 5km radius
    String? pageToken,
  }) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/nearbysearch/json',
        queryParameters: {
          'location': '$latitude,$longitude',
          'radius': radius,
          'keyword': 'tennis courts',
          'type': 'establishment',
          'key': ApiKeys.googlePlacesApiKey,
          if (pageToken != null) 'pagetoken': pageToken,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = response.data['results'];
        
        // Calculate distance for each court
        return results.map((courtData) {
          final courtLat = courtData['geometry']['location']['lat'];
          final courtLng = courtData['geometry']['location']['lng'];
          
          final distance = _locationService.calculateDistance(
            latitude,
            longitude,
            courtLat,
            courtLng,
          );
          
          return TennisCourt.fromGooglePlaces(courtData, distance: distance);
        }).toList()
          ..sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
      }
      
      return [];
    } catch (e) {
      print('Error searching tennis courts: $e');
      
      // Return mock data for testing when network is unavailable
      if (e.toString().contains('Failed host lookup') || 
          e.toString().contains('SocketException')) {
        print('Network unavailable, returning mock data for testing');
        return _getMockTennisCourts(latitude, longitude);
      }
      
      return [];
    }
  }

  // Search tennis courts by text query
  Future<List<TennisCourt>> searchCourtsByQuery({
    required String query,
    double? latitude,
    double? longitude,
    int radius = 50000, // 50km default for text search
  }) async {
    try {
      // First, check if the query looks like an address or zipcode
      // If so, geocode it first to get coordinates
      if (_looksLikeAddress(query)) {
        final coordinates = await _geocodeAddress(query);
        if (coordinates != null) {
          // Search for tennis courts near the geocoded location
          final courts = await searchTennisCourts(
            latitude: coordinates['lat']!,
            longitude: coordinates['lng']!,
            radius: radius,
          );
          
          // If no results with nearby search, try text search as fallback
          if (courts.isEmpty) {
            return _performTextSearch(query, latitude, longitude, radius);
          }
          
          return courts;
        }
      }
      
      // Otherwise, do a text search for tennis courts
      return _performTextSearch(query, latitude, longitude, radius);
    } catch (e) {
      print('Error searching courts by query: $e');
      return [];
    }
  }

  // Get detailed information about a specific court
  Future<TennisCourt?> getCourtDetails(String placeId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/details/json',
        queryParameters: {
          'place_id': placeId,
          'fields': 'place_id,name,formatted_address,geometry,rating,'
              'user_ratings_total,photos,opening_hours,formatted_phone_number,'
              'website,reviews,types',
          'key': ApiKeys.googlePlacesApiKey,
        },
      );

      if (response.statusCode == 200 && response.data['result'] != null) {
        final courtData = response.data['result'];
        
        // Parse reviews
        final List<Review> reviews = [];
        if (courtData['reviews'] != null) {
          for (var reviewData in courtData['reviews']) {
            reviews.add(Review.fromJson(reviewData));
          }
        }

        final court = TennisCourt.fromGooglePlaces(courtData);
        
        return TennisCourt(
          placeId: court.placeId,
          name: court.name,
          address: court.address,
          latitude: court.latitude,
          longitude: court.longitude,
          rating: court.rating,
          userRatingsTotal: court.userRatingsTotal,
          phoneNumber: courtData['formatted_phone_number'],
          website: courtData['website'],
          types: court.types,
          photoReference: court.photoReference,
          isOpenNow: court.isOpenNow,
          weekdayText: courtData['opening_hours']?['weekday_text'] != null
              ? List<String>.from(courtData['opening_hours']['weekday_text'])
              : null,
          reviews: reviews,
        );
      }
      
      return null;
    } catch (e) {
      print('Error getting court details: $e');
      return null;
    }
  }

  // Search courts near user's current location
  Future<List<TennisCourt>> searchNearbyCourtsByCurrentLocation({
    int radius = 5000,
  }) async {
    final position = await _locationService.getCurrentLocation();
    if (position == null) {
      // Return mock data with default coordinates for testing
      print('Unable to get location, using mock data with default coordinates');
      return _getMockTennisCourts(37.7749, -122.4194); // San Francisco coordinates
    }

    return searchTennisCourts(
      latitude: position.latitude,
      longitude: position.longitude,
      radius: radius,
    );
  }

  // Get photo URL for a place
  String getPhotoUrl(String? photoReference, {int maxWidth = 400}) {
    if (photoReference == null) return '';
    
    return '$_baseUrl/photo'
        '?maxwidth=$maxWidth'
        '&photo_reference=$photoReference'
        '&key=${ApiKeys.googlePlacesApiKey}';
  }

  // Autocomplete for location search
  Future<List<Map<String, dynamic>>> getLocationAutocomplete(String input) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/autocomplete/json',
        queryParameters: {
          'input': input,
          'types': '(cities)',
          'key': ApiKeys.googlePlacesApiKey,
        },
      );

      if (response.statusCode == 200) {
        final predictions = response.data['predictions'] as List;
        return predictions.map((p) => {
          'description': p['description'],
          'place_id': p['place_id'],
        }).toList();
      }
      
      return [];
    } catch (e) {
      print('Error getting autocomplete suggestions: $e');
      return [];
    }
  }

  // Get coordinates for a place ID
  Future<Map<String, double>?> getPlaceCoordinates(String placeId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl/details/json',
        queryParameters: {
          'place_id': placeId,
          'fields': 'geometry',
          'key': ApiKeys.googlePlacesApiKey,
        },
      );

      if (response.statusCode == 200 && response.data['result'] != null) {
        final location = response.data['result']['geometry']['location'];
        return {
          'latitude': location['lat'].toDouble(),
          'longitude': location['lng'].toDouble(),
        };
      }
      
      return null;
    } catch (e) {
      print('Error getting place coordinates: $e');
      return null;
    }
  }

  // Check if query looks like an address or zipcode
  bool _looksLikeAddress(String query) {
    // Check for zipcode patterns (5 digits or 5+4 format)
    final zipcodePattern = RegExp(r'^\d{5}(-\d{4})?$');
    if (zipcodePattern.hasMatch(query.trim())) {
      return true;
    }
    
    // Check for common address indicators
    final addressKeywords = ['street', 'st', 'avenue', 'ave', 'road', 'rd', 
                           'boulevard', 'blvd', 'drive', 'dr', 'lane', 'ln',
                           'way', 'court', 'ct', 'plaza', 'square', 'park'];
    
    final lowerQuery = query.toLowerCase();
    for (final keyword in addressKeywords) {
      if (lowerQuery.contains(' $keyword') || lowerQuery.endsWith(' $keyword')) {
        return true;
      }
    }
    
    // Check if it contains numbers (common in addresses)
    if (RegExp(r'\d+').hasMatch(query)) {
      return true;
    }
    
    return false;
  }

  // Geocode an address to get coordinates
  Future<Map<String, double>?> _geocodeAddress(String address) async {
    try {
      final response = await _dio.get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {
          'address': address,
          'key': ApiKeys.googleMapsApiKey,
        },
      );

      if (response.statusCode == 200 && response.data['results'].isNotEmpty) {
        final location = response.data['results'][0]['geometry']['location'];
        return {
          'lat': location['lat'].toDouble(),
          'lng': location['lng'].toDouble(),
        };
      }
      
      return null;
    } catch (e) {
      print('Error geocoding address: $e');
      return null;
    }
  }

  // Perform text search for tennis courts
  Future<List<TennisCourt>> _performTextSearch(
    String query,
    double? latitude,
    double? longitude,
    int radius,
  ) async {
    try {
      final queryParams = {
        'query': 'tennis courts near $query',
        'type': 'establishment',
        'key': ApiKeys.googlePlacesApiKey,
      };

      // Add location bias if coordinates provided
      if (latitude != null && longitude != null) {
        queryParams['location'] = '$latitude,$longitude';
        queryParams['radius'] = radius.toString();
      }

      final response = await _dio.get(
        '$_baseUrl/textsearch/json',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> results = response.data['results'];
        
        return results.map((courtData) {
          double? distance;
          if (latitude != null && longitude != null) {
            final courtLat = courtData['geometry']['location']['lat'];
            final courtLng = courtData['geometry']['location']['lng'];
            
            distance = _locationService.calculateDistance(
              latitude,
              longitude,
              courtLat,
              courtLng,
            );
          }
          
          return TennisCourt.fromGooglePlaces(courtData, distance: distance);
        }).toList()
          ..sort((a, b) => (a.distance ?? double.infinity)
              .compareTo(b.distance ?? double.infinity));
      }
      
      return [];
    } catch (e) {
      print('Error performing text search: $e');
      return [];
    }
  }

  // Mock data for testing when network is unavailable
  List<TennisCourt> _getMockTennisCourts(double latitude, double longitude) {
    final mockCourts = [
      {
        'place_id': 'mock_1',
        'name': 'Sunset Tennis Club',
        'formatted_address': '123 Tennis Court Way, San Francisco, CA 94110',
        'geometry': {
          'location': {
            'lat': latitude + 0.01,
            'lng': longitude + 0.01,
          }
        },
        'rating': 4.5,
        'user_ratings_total': 127,
        'types': ['tennis_court', 'sports_complex'],
        'opening_hours': {
          'open_now': true,
        }
      },
      {
        'place_id': 'mock_2',
        'name': 'Golden Gate Tennis Center',
        'formatted_address': '456 Park Avenue, San Francisco, CA 94122',
        'geometry': {
          'location': {
            'lat': latitude - 0.015,
            'lng': longitude + 0.008,
          }
        },
        'rating': 4.2,
        'user_ratings_total': 89,
        'types': ['tennis_court', 'park'],
        'opening_hours': {
          'open_now': true,
        }
      },
      {
        'place_id': 'mock_3',
        'name': 'Bay Area Racquet Club',
        'formatted_address': '789 Sport Center Dr, San Francisco, CA 94103',
        'geometry': {
          'location': {
            'lat': latitude + 0.02,
            'lng': longitude - 0.01,
          }
        },
        'rating': 4.7,
        'user_ratings_total': 205,
        'types': ['tennis_court', 'gym'],
        'opening_hours': {
          'open_now': false,
        }
      },
      {
        'place_id': 'mock_4',
        'name': 'Mission Tennis Courts',
        'formatted_address': '321 Mission St, San Francisco, CA 94110',
        'geometry': {
          'location': {
            'lat': latitude - 0.008,
            'lng': longitude - 0.012,
          }
        },
        'rating': 3.9,
        'user_ratings_total': 45,
        'types': ['tennis_court'],
        'opening_hours': {
          'open_now': true,
        }
      },
      {
        'place_id': 'mock_5',
        'name': 'Presidio Tennis Club',
        'formatted_address': '654 Presidio Blvd, San Francisco, CA 94129',
        'geometry': {
          'location': {
            'lat': latitude + 0.025,
            'lng': longitude + 0.015,
          }
        },
        'rating': 4.8,
        'user_ratings_total': 312,
        'types': ['tennis_court', 'country_club'],
        'opening_hours': {
          'open_now': true,
        }
      },
    ];

    return mockCourts.map((courtData) {
      final geometry = courtData['geometry'] as Map<String, dynamic>;
      final location = geometry['location'] as Map<String, dynamic>;
      final courtLat = location['lat'] as double;
      final courtLng = location['lng'] as double;
      
      final distance = _locationService.calculateDistance(
        latitude,
        longitude,
        courtLat,
        courtLng,
      );
      
      return TennisCourt.fromGooglePlaces(courtData, distance: distance);
    }).toList()
      ..sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
  }
}