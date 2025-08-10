import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tennis_connect/models/tennis_court.dart';
import 'package:tennis_connect/services/court_discovery_service.dart';
import 'package:tennis_connect/constants/app_constants.dart';

class CourtDetailsScreen extends StatefulWidget {
  final TennisCourt court;

  const CourtDetailsScreen({
    super.key,
    required this.court,
  });

  @override
  State<CourtDetailsScreen> createState() => _CourtDetailsScreenState();
}

class _CourtDetailsScreenState extends State<CourtDetailsScreen> {
  final CourtDiscoveryService _courtService = CourtDiscoveryService();
  GoogleMapController? _mapController;
  TennisCourt? _detailedCourt;
  bool _isLoadingDetails = false;
  MapType _currentMapType = MapType.satellite;

  @override
  void initState() {
    super.initState();
    _loadCourtDetails();
  }

  Future<void> _loadCourtDetails() async {
    setState(() => _isLoadingDetails = true);
    
    try {
      final details = await _courtService.getCourtDetails(widget.court.placeId);
      if (details != null && mounted) {
        setState(() {
          _detailedCourt = details;
          _isLoadingDetails = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDetails = false);
      }
    }
  }

  Future<void> _launchMaps() async {
    final court = _detailedCourt ?? widget.court;
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${court.latitude},${court.longitude}'
    );
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callCourt() async {
    final phoneNumber = _detailedCourt?.phoneNumber;
    if (phoneNumber == null) return;
    
    final url = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Future<void> _visitWebsite() async {
    final website = _detailedCourt?.website;
    if (website == null) return;
    
    final url = Uri.parse(website);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final court = _detailedCourt ?? widget.court;
    
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar with Map
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.primaryGreen,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                court.name,
                style: const TextStyle(
                  shadows: [
                    Shadow(
                      blurRadius: 3,
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(court.latitude, court.longitude),
                      zoom: 17,
                    ),
                    mapType: _currentMapType,
                    markers: {
                      Marker(
                        markerId: const MarkerId('court'),
                        position: LatLng(court.latitude, court.longitude),
                        infoWindow: InfoWindow(title: court.name),
                      ),
                    },
                    onMapCreated: (controller) => _mapController = controller,
                  ),
                  // Map Type Toggle
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 50,
                    right: 16,
                    child: FloatingActionButton.small(
                      onPressed: () {
                        setState(() {
                          _currentMapType = _currentMapType == MapType.satellite
                              ? MapType.normal
                              : MapType.satellite;
                        });
                      },
                      backgroundColor: Colors.white,
                      child: Icon(
                        _currentMapType == MapType.satellite
                            ? Icons.map
                            : Icons.satellite,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _launchMaps,
                          icon: const Icon(Icons.directions),
                          label: const Text('Directions'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                      if (_detailedCourt?.phoneNumber != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _callCourt,
                            icon: const Icon(Icons.phone),
                            label: const Text('Call'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryGreen,
                            ),
                          ),
                        ),
                      ],
                      if (_detailedCourt?.website != null) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _visitWebsite,
                            icon: const Icon(Icons.language),
                            label: const Text('Website'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primaryGreen,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Address
                  _buildInfoSection(
                    icon: Icons.location_on,
                    title: 'Address',
                    content: court.address,
                  ),
                  
                  // Distance
                  if (court.distance != null)
                    _buildInfoSection(
                      icon: Icons.straighten,
                      title: 'Distance',
                      content: court.getDistanceDisplay(useMiles: false), // TODO: Get user preference
                    ),
                  
                  // Rating
                  if (court.rating != null)
                    _buildInfoSection(
                      icon: Icons.star,
                      title: 'Rating',
                      content: '${court.rating!.toStringAsFixed(1)} (${court.userRatingsTotal ?? 0} reviews)',
                    ),
                  
                  // Phone
                  if (_detailedCourt?.phoneNumber != null)
                    _buildInfoSection(
                      icon: Icons.phone,
                      title: 'Phone',
                      content: _detailedCourt!.phoneNumber!,
                    ),
                  
                  // Opening Hours
                  if (_detailedCourt?.weekdayText != null &&
                      _detailedCourt!.weekdayText!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Opening Hours',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      color: Colors.grey[50],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _detailedCourt!.weekdayText!
                              .map((day) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Text(day),
                                  ))
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                  
                  // Reviews
                  if (_isLoadingDetails)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_detailedCourt?.reviews.isNotEmpty ?? false) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Reviews',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._detailedCourt!.reviews.map((review) => _buildReviewCard(review)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Review review) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.lightGreen,
                  child: Text(
                    review.authorName.isNotEmpty
                        ? review.authorName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.authorName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        review.relativeTimeDescription,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      index < review.rating ? Icons.star : Icons.star_border,
                      size: 16,
                      color: Colors.amber[700],
                    ),
                  ),
                ),
              ],
            ),
            if (review.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(review.text),
            ],
          ],
        ),
      ),
    );
  }
}