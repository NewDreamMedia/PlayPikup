import 'package:cloud_firestore/cloud_firestore.dart';

class CourtModel {
  final String id;
  final String name;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final GeoPoint location;
  final List<String> surfaces; // hard, clay, grass
  final int numberOfCourts;
  final bool isIndoor;
  final bool hasLighting;
  final List<String> amenities; // pro_shop, restrooms, parking, water_fountain
  final String type; // public, private_club, school, park
  final double? hourlyRate;
  final String? phoneNumber;
  final String? website;
  final Map<String, String> hours; // {'monday': '6:00 AM - 10:00 PM', ...}
  final double rating;
  final int totalRatings;
  final List<String> photos;
  final String? bookingUrl;
  final bool requiresMembership;
  final DateTime? lastUpdated;
  final Map<String, dynamic>? courtConditions; // user-reported conditions

  CourtModel({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.location,
    required this.surfaces,
    required this.numberOfCourts,
    required this.isIndoor,
    required this.hasLighting,
    required this.amenities,
    required this.type,
    this.hourlyRate,
    this.phoneNumber,
    this.website,
    required this.hours,
    this.rating = 0.0,
    this.totalRatings = 0,
    this.photos = const [],
    this.bookingUrl,
    this.requiresMembership = false,
    this.lastUpdated,
    this.courtConditions,
  });

  factory CourtModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CourtModel(
      id: doc.id,
      name: data['name'] ?? '',
      address: data['address'] ?? '',
      city: data['city'] ?? '',
      state: data['state'] ?? '',
      zipCode: data['zipCode'] ?? '',
      location: data['location'] ?? const GeoPoint(0, 0),
      surfaces: List<String>.from(data['surfaces'] ?? []),
      numberOfCourts: data['numberOfCourts'] ?? 1,
      isIndoor: data['isIndoor'] ?? false,
      hasLighting: data['hasLighting'] ?? false,
      amenities: List<String>.from(data['amenities'] ?? []),
      type: data['type'] ?? 'public',
      hourlyRate: data['hourlyRate']?.toDouble(),
      phoneNumber: data['phoneNumber'],
      website: data['website'],
      hours: Map<String, String>.from(data['hours'] ?? {}),
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalRatings: data['totalRatings'] ?? 0,
      photos: List<String>.from(data['photos'] ?? []),
      bookingUrl: data['bookingUrl'],
      requiresMembership: data['requiresMembership'] ?? false,
      lastUpdated: data['lastUpdated'] != null 
          ? (data['lastUpdated'] as Timestamp).toDate() 
          : null,
      courtConditions: data['courtConditions'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'location': location,
      'surfaces': surfaces,
      'numberOfCourts': numberOfCourts,
      'isIndoor': isIndoor,
      'hasLighting': hasLighting,
      'amenities': amenities,
      'type': type,
      'hourlyRate': hourlyRate,
      'phoneNumber': phoneNumber,
      'website': website,
      'hours': hours,
      'rating': rating,
      'totalRatings': totalRatings,
      'photos': photos,
      'bookingUrl': bookingUrl,
      'requiresMembership': requiresMembership,
      'lastUpdated': lastUpdated != null 
          ? Timestamp.fromDate(lastUpdated!) 
          : FieldValue.serverTimestamp(),
      'courtConditions': courtConditions,
    };
  }

  double get distanceInMiles => 0.0; // Calculate based on user location
}