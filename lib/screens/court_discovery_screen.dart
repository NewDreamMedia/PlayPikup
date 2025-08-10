import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tennis_connect/models/tennis_court.dart';
import 'package:tennis_connect/services/court_discovery_service.dart';
import 'package:tennis_connect/services/location_service.dart';
import 'package:tennis_connect/services/preferences_service.dart';
import 'package:tennis_connect/constants/app_constants.dart';
import 'package:tennis_connect/screens/court_details_screen.dart';

class CourtDiscoveryScreen extends StatefulWidget {
  final bool isSelectionMode;
  
  const CourtDiscoveryScreen({
    super.key,
    this.isSelectionMode = false,
  });

  @override
  State<CourtDiscoveryScreen> createState() => _CourtDiscoveryScreenState();
}

class _CourtDiscoveryScreenState extends State<CourtDiscoveryScreen> {
  final CourtDiscoveryService _courtService = CourtDiscoveryService();
  final LocationService _locationService = LocationService();
  final PreferencesService _preferencesService = PreferencesService();
  final TextEditingController _searchController = TextEditingController();
  
  List<TennisCourt> _courts = [];
  bool _isLoading = false;
  String? _errorMessage;
  Position? _currentPosition;
  String _searchRadius = '5'; // Default radius value
  bool _useMiles = false; // Distance unit preference
  
  // Radius options for each unit
  final List<String> _kmRadiusOptions = ['1', '2', '5', '10', '25', '50'];
  final List<String> _milesRadiusOptions = ['0.5', '1', '2', '5', '10', '25'];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }
  
  Future<void> _loadPreferences() async {
    final useMiles = await _preferencesService.getUseMiles();
    final savedRadius = await _preferencesService.getSearchRadius();
    
    setState(() {
      _useMiles = useMiles;
      _searchRadius = savedRadius;
    });
    
    _loadNearbyCourtsByLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNearbyCourtsByLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Convert radius to meters based on unit preference
      final radiusInMeters = _useMiles
          ? _locationService.milesToMeters(double.parse(_searchRadius))
          : _locationService.kilometersToMeters(double.parse(_searchRadius));
      
      final courts = await _courtService.searchNearbyCourtsByCurrentLocation(
        radius: radiusInMeters.round(),
      );
      
      _currentPosition = await _locationService.getCurrentLocation();
      
      if (mounted) {
        setState(() {
          _courts = courts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to get location. Please enable location services.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _searchCourtsByQuery() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Convert radius to meters based on unit preference
      final radiusInMeters = _useMiles
          ? _locationService.milesToMeters(double.parse(_searchRadius))
          : _locationService.kilometersToMeters(double.parse(_searchRadius));
      
      final courts = await _courtService.searchCourtsByQuery(
        query: _searchController.text,
        latitude: _currentPosition?.latitude,
        longitude: _currentPosition?.longitude,
        radius: radiusInMeters.round(),
      );

      setState(() {
        _courts = courts;
        _isLoading = false;
        if (courts.isEmpty) {
          _errorMessage = 'No tennis courts found near "${_searchController.text}". Try a different location or increase the search radius.';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error searching courts. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _navigateToCourtDetails(TennisCourt court) {
    if (widget.isSelectionMode) {
      // In selection mode, return the selected court
      Navigator.pop(context, court);
    } else {
      // Normal mode, navigate to details
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CourtDetailsScreen(court: court),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isSelectionMode ? 'Select Court' : 'Discover Tennis Courts'),
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by address, city, or ZIP code...',
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _loadNearbyCourtsByLocation();
                      },
                    ),
                  ),
                  onSubmitted: (_) => _searchCourtsByQuery(),
                ),
                const SizedBox(height: 12),
                // Filter Row
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _searchRadius,
                            isExpanded: true,
                            items: (_useMiles ? _milesRadiusOptions : _kmRadiusOptions).map((radius) {
                              return DropdownMenuItem(
                                value: radius,
                                child: Text('Within $radius ${_useMiles ? 'mi' : 'km'}'),
                              );
                            }).toList(),
                            onChanged: (value) async {
                              setState(() => _searchRadius = value!);
                              await _preferencesService.setSearchRadius(value!);
                              _loadNearbyCourtsByLocation();
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: ToggleButtons(
                        borderRadius: BorderRadius.circular(20),
                        selectedColor: Colors.white,
                        fillColor: AppColors.primaryGreen,
                        color: AppColors.primaryGreen,
                        constraints: const BoxConstraints(
                          minHeight: 36,
                          minWidth: 40,
                        ),
                        isSelected: [!_useMiles, _useMiles],
                        onPressed: (index) async {
                          setState(() {
                            _useMiles = index == 1;
                            // Update radius to equivalent value
                            if (_useMiles) {
                              // Converting from km to miles
                              if (_searchRadius == '1') _searchRadius = '0.5';
                              else if (_searchRadius == '2') _searchRadius = '1';
                              else if (_searchRadius == '5') _searchRadius = '2';
                              else if (_searchRadius == '10') _searchRadius = '5';
                              else if (_searchRadius == '25') _searchRadius = '10';
                              else if (_searchRadius == '50') _searchRadius = '25';
                            } else {
                              // Converting from miles to km
                              if (_searchRadius == '0.5') _searchRadius = '1';
                              else if (_searchRadius == '1') _searchRadius = '2';
                              else if (_searchRadius == '2') _searchRadius = '5';
                              else if (_searchRadius == '5') _searchRadius = '10';
                              else if (_searchRadius == '10') _searchRadius = '25';
                              else if (_searchRadius == '25') _searchRadius = '50';
                            }
                          });
                          await _preferencesService.setUseMiles(_useMiles);
                          await _preferencesService.setSearchRadius(_searchRadius);
                          _loadNearbyCourtsByLocation();
                        },
                        children: const [
                          Text('km'),
                          Text('mi'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _loadNearbyCourtsByLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Near Me'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Results
          Expanded(
            child: _buildResultsContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryGreen,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadNearbyCourtsByLocation,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_courts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.sports_tennis,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No tennis courts found',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching a different location',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _courts.length,
      itemBuilder: (context, index) {
        final court = _courts[index];
        return _buildCourtCard(court);
      },
    );
  }

  Widget _buildCourtCard(TennisCourt court) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _navigateToCourtDetails(court),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Court Image or Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: AppColors.lightGreen.withOpacity(0.2),
                ),
                child: court.photoReference != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _courtService.getPhotoUrl(court.photoReference),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.sports_tennis,
                            size: 40,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.sports_tennis,
                        size: 40,
                        color: AppColors.primaryGreen,
                      ),
              ),
              const SizedBox(width: 16),
              // Court Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      court.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      court.address,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (court.rating != null) ...[
                          Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            court.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(${court.userRatingsTotal ?? 0})',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        if (court.distance != null) ...[
                          Icon(
                            Icons.location_on,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            court.getDistanceDisplay(useMiles: _useMiles),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Arrow
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }
}