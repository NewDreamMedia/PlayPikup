import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tennis_connect/config/api_keys.dart';

class TennisCourt {
  final String placeId;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double? rating;
  final int? userRatingsTotal;
  final String? phoneNumber;
  final String? website;
  final List<String> types;
  final String? photoReference;
  final bool? isOpenNow;
  final List<String>? weekdayText;
  final double? distance; // Distance from user in meters
  final List<Review> reviews;
  final CourtDetails? details;

  TennisCourt({
    required this.placeId,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.rating,
    this.userRatingsTotal,
    this.phoneNumber,
    this.website,
    required this.types,
    this.photoReference,
    this.isOpenNow,
    this.weekdayText,
    this.distance,
    this.reviews = const [],
    this.details,
  });

  factory TennisCourt.fromGooglePlaces(Map<String, dynamic> json, {double? distance}) {
    final location = json['geometry']['location'];
    final openingHours = json['opening_hours'];
    final photos = json['photos'] as List?;
    
    return TennisCourt(
      placeId: json['place_id'],
      name: json['name'],
      address: json['formatted_address'] ?? json['vicinity'] ?? '',
      latitude: location['lat'].toDouble(),
      longitude: location['lng'].toDouble(),
      rating: json['rating']?.toDouble(),
      userRatingsTotal: json['user_ratings_total'],
      types: List<String>.from(json['types'] ?? []),
      photoReference: photos != null && photos.isNotEmpty 
          ? photos[0]['photo_reference'] 
          : null,
      isOpenNow: openingHours?['open_now'],
      weekdayText: openingHours?['weekday_text'] != null 
          ? List<String>.from(openingHours['weekday_text'])
          : null,
      distance: distance,
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'placeId': placeId,
      'name': name,
      'address': address,
      'location': GeoPoint(latitude, longitude),
      'rating': rating,
      'userRatingsTotal': userRatingsTotal,
      'phoneNumber': phoneNumber,
      'website': website,
      'types': types,
      'photoReference': photoReference,
      'lastUpdated': FieldValue.serverTimestamp(),
    };
  }

  // Create from Firestore document
  factory TennisCourt.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final GeoPoint location = data['location'];
    
    return TennisCourt(
      placeId: data['placeId'],
      name: data['name'],
      address: data['address'],
      latitude: location.latitude,
      longitude: location.longitude,
      rating: data['rating']?.toDouble(),
      userRatingsTotal: data['userRatingsTotal'],
      phoneNumber: data['phoneNumber'],
      website: data['website'],
      types: List<String>.from(data['types'] ?? []),
      photoReference: data['photoReference'],
    );
  }

  String getPhotoUrl({int maxWidth = 400}) {
    if (photoReference == null) return '';
    return 'https://maps.googleapis.com/maps/api/place/photo'
        '?maxwidth=$maxWidth'
        '&photo_reference=$photoReference'
        '&key=${ApiKeys.googlePlacesApiKey}';
  }

  String getDistanceDisplay({bool useMiles = false}) {
    if (distance == null) return '';
    
    if (useMiles) {
      final miles = distance! * 0.000621371;
      if (miles < 0.1) {
        // Show in feet for very short distances
        final feet = distance! * 3.28084;
        return '${feet.toStringAsFixed(0)} ft';
      } else if (miles < 1) {
        return '${miles.toStringAsFixed(2)} mi';
      } else {
        return '${miles.toStringAsFixed(1)} mi';
      }
    } else {
      if (distance! < 1000) {
        return '${distance!.toStringAsFixed(0)} m';
      } else {
        return '${(distance! / 1000).toStringAsFixed(1)} km';
      }
    }
  }
  
  // Legacy getter for backward compatibility
  String get distanceDisplay => getDistanceDisplay();
}

class Review {
  final String authorName;
  final String authorUrl;
  final String? profilePhotoUrl;
  final double rating;
  final String relativeTimeDescription;
  final String text;
  final int time;

  Review({
    required this.authorName,
    required this.authorUrl,
    this.profilePhotoUrl,
    required this.rating,
    required this.relativeTimeDescription,
    required this.text,
    required this.time,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      authorName: json['author_name'] ?? '',
      authorUrl: json['author_url'] ?? '',
      profilePhotoUrl: json['profile_photo_url'],
      rating: json['rating'].toDouble(),
      relativeTimeDescription: json['relative_time_description'] ?? '',
      text: json['text'] ?? '',
      time: json['time'] ?? 0,
    );
  }
}

class CourtDetails {
  final int? numberOfCourts;
  final List<String> courtSurfaces;
  final bool hasLighting;
  final bool hasParking;
  final bool hasChangingRooms;
  final bool requiresBooking;
  final String? bookingUrl;
  final Map<String, dynamic>? priceInfo;

  CourtDetails({
    this.numberOfCourts,
    this.courtSurfaces = const ['Unknown'],
    this.hasLighting = false,
    this.hasParking = false,
    this.hasChangingRooms = false,
    this.requiresBooking = false,
    this.bookingUrl,
    this.priceInfo,
  });

  factory CourtDetails.fromJson(Map<String, dynamic> json) {
    return CourtDetails(
      numberOfCourts: json['numberOfCourts'],
      courtSurfaces: List<String>.from(json['courtSurfaces'] ?? ['Unknown']),
      hasLighting: json['hasLighting'] ?? false,
      hasParking: json['hasParking'] ?? false,
      hasChangingRooms: json['hasChangingRooms'] ?? false,
      requiresBooking: json['requiresBooking'] ?? false,
      bookingUrl: json['bookingUrl'],
      priceInfo: json['priceInfo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'numberOfCourts': numberOfCourts,
      'courtSurfaces': courtSurfaces,
      'hasLighting': hasLighting,
      'hasParking': hasParking,
      'hasChangingRooms': hasChangingRooms,
      'requiresBooking': requiresBooking,
      'bookingUrl': bookingUrl,
      'priceInfo': priceInfo,
    };
  }
}