import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'tile_cache.dart';
import '../widgets/navigation_overlay.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

class EvacuationCenter {
  final String name;
  final String description;
  final LatLng location;

  const EvacuationCenter({
    required this.name,
    required this.description,
    required this.location,
  });
}

class OSMMap extends StatefulWidget {
  final bool autoNavigate;
  final bool isOnline;
  
  const OSMMap({
    super.key,
    this.autoNavigate = false,
    this.isOnline = true,
  });

  @override
  State<OSMMap> createState() => _OSMMapState();
}

class _OSMMapState extends State<OSMMap> with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  late final TileCacheProvider _tileProvider;
  EvacuationCenter? _selectedCenter;
  LatLng? _userLocation;
  bool _isNavigating = false;
  StreamSubscription<Position>? _positionStream;
  String? _errorMessage;
  bool _isLoading = true;
  List<LatLng>? _routePoints;
  double _currentBearing = 0.0;
  StreamSubscription<CompassEvent>? _compassSubscription;
  bool _isMapInitialized = false;
  bool _isDownloadingRoute = false;
  Timer? _positionUpdateTimer;
  final bool _isOffline = false;
  final GlobalKey _mapKey = GlobalKey();
  bool _controllerReady = false;
  
  // Replace with your Open Route Service API key
  static const String _apiKey = '5b3ce3597851110001cf6248f8b5e0c5c7c94c0c8c8c4c4c4c4c4c4c';
  static const String _baseUrl = 'https://routing.openstreetmap.de';
  static const String _graphhopperKey = 'd4b72ef7-1eba-481b-addb-4065589efa42'; // Get one from graphhopper.com

  // Center point between all evacuation centers
  final LatLng tagumCenter = const LatLng(7.419733, 125.826537);

  // Evacuation center locations with descriptions
  final List<EvacuationCenter> evacuationCenters = const [
    EvacuationCenter(
      name: 'TNTS Quadrangle',
      description: 'Main evacuation field for students, teachers, and staff.',
      location: LatLng(7.420352, 125.826609),
    ),
    EvacuationCenter(
      name: 'TNTS TVE Evac',
      description: 'Secondary evacuation field for students, teachers, and staff.',
      location: LatLng(7.419977, 125.826950),
    ),
    EvacuationCenter(
      name: 'TNTS Field',
      description: 'Open field evacuation area for temporary shelter.',
      location: LatLng(7.418871, 125.826051),
    ),
  ];

  // Add new properties for offline navigation
  final double gridSize = 0.0001; // Approximately 10 meters
  final int maxPathNodes = 100;

  // Add new properties for route caching
  final String _routeCacheKey = 'cached_routes';
  Map<String, List<LatLng>> _cachedRoutes = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCachedRoutes();
    
    // Delay auto-navigation until the map is fully rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAll().then((_) {
        // Wait a bit longer to ensure map controller is ready
        Future.delayed(const Duration(milliseconds: 500), () {
          _controllerReady = true;
          if (widget.autoNavigate && mounted) {
            _startAutoNavigation();
          }
        });
      });
    });
    
    _startPositionUpdates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _compassSubscription?.cancel();
    _positionStream?.cancel();
    _positionUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-initialize map when app resumes
      if (_mapController.camera.zoom <= 0) {
        _controllerReady = false;
        Future.delayed(const Duration(milliseconds: 500), () {
          _controllerReady = true;
        });
      }
    }
  }

  Future<void> _initializeAll() async {
    if (!mounted) return;
    
    try {
      setState(() => _isLoading = true);
      
      // Initialize cache first
      await _initializeCache();
      
      // Initialize location and compass in parallel
      await Future.wait([
        _initializeLocation(),
        Future(() => _initializeCompass()),
      ]);

      if (mounted) {
        setState(() {
          _isMapInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Initialization error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initializeCache() async {
    try {
      _tileProvider = TileCacheProvider(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        headers: {'User-Agent': 'com.naviquake.app'},
      );
      await _tileProvider.initialize();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize map cache: $e';
      });
    }
  }

  Future<void> _initializeLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!mounted) return;

      if (!serviceEnabled) {
        _errorMessage = 'Location services are disabled';
        return;
      }

      // Request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Location permission denied. Please enable location permissions in app settings.';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Location permissions are permanently denied. Please enable them in app settings.';
          _isLoading = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 30),
      );

      if (!mounted) return;
      _userLocation = LatLng(position.latitude, position.longitude);

      // Start position stream with optimized settings
      _positionStream?.cancel();
      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 10,
        ),
      ).listen(
        _handlePositionUpdate,
        onError: _handleLocationError,
      );
    } catch (e) {
      if (mounted) {
        _errorMessage = 'Location error: ${e.toString()}';
      }
    }
  }

  void _handlePositionUpdate(Position position) {
    if (!mounted) return;
    
    final newPosition = LatLng(position.latitude, position.longitude);
    
    // Only process if position has significantly changed (to avoid too frequent updates)
    final bool hasPositionChanged = _userLocation == null || 
                                   _calculateDistance(_userLocation!, newPosition) > 5;
    
    if (hasPositionChanged) {
      setState(() {
        _userLocation = newPosition;
        if (_isNavigating && _isMapInitialized && _mapController.camera.zoom > 0) {
          try {
            _mapController.move(_userLocation!, _mapController.camera.zoom);
            
            // Recalculate route with every position update when navigating
            if (_selectedCenter != null) {
              _recalculateRouteBasedOnCurrentPosition();
            }
          } catch (e) {
            print('MapController error in position update: $e');
          }
        }
      });
    }
  }

  // New method to recalculate route on every position update
  Future<void> _recalculateRouteBasedOnCurrentPosition() async {
    if (_userLocation == null || _selectedCenter == null || !_isNavigating) return;

    // Don't recalculate if already loading
    if (_isLoading) return;

    try {
      // Always calculate a new offline route first as a fallback
      final offlineRoute = _calculateOfflineRoute(_userLocation!, _selectedCenter!.location);
      
      // Use online service only if we're online
      if (widget.isOnline && !_isOffline) {
        setState(() => _isLoading = true);
        
        try {
          final onlineRoute = await _fetchOnlineRoute(_userLocation!, _selectedCenter!.location);
          if (onlineRoute != null && onlineRoute.length > 1) {
            // Update cache for future offline use
            final cacheKey = _getRouteCacheKey(_userLocation!, _selectedCenter!.location);
            _cachedRoutes[cacheKey] = onlineRoute;
            _saveCachedRoutes(); // Don't await to avoid UI delay

            if (mounted) {
              setState(() {
                _routePoints = onlineRoute;
                _isLoading = false;
              });
            }
            return;
          }
        } catch (e) {
          print('Error fetching online route: $e');
          // Fall back to offline route
        }
      }

      // Use offline route if online failed or we're offline
      if (mounted) {
        setState(() {
          _routePoints = offlineRoute;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Route recalculation error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Enhanced offline route calculation with better path generation
  List<LatLng> _calculateOfflineRoute(LatLng start, LatLng destination) {
    try {
      List<LatLng> route = [];
      
      // Always add the starting point
      route.add(start);
      
      // Calculate initial bearing and distance
      double totalDistance = _calculateDistance(start, destination);
      double initialBearing = _calculateBearing(start, destination);
      
      // For very short distances, just return direct line
      if (totalDistance < 50) {
        route.add(destination);
        return route;
      }
      
      // Create more natural path with better intermediate points
      int numPoints = math.min((totalDistance / 15).ceil(), maxPathNodes); // One point every 15 meters
      numPoints = math.max(numPoints, 7); // Minimum 7 points for smoother path
      
      // Generate intermediate points with natural path deviations
      for (int i = 1; i < numPoints; i++) {
        double progress = i / numPoints;
        
        // Add slight path complexity to simulate real-world routes
        double pathComplexity = math.sin(progress * math.pi) * 0.0001; // Curve in the middle
        double randomDeviation = 0.00005 * math.Random().nextDouble(); // Small random factor
        
        // Linear interpolation with natural deviations
        double lat = start.latitude + (destination.latitude - start.latitude) * progress;
        double lng = start.longitude + (destination.longitude - start.longitude) * progress;
        
        // Apply calculated deviations 
        lat += pathComplexity + randomDeviation;
        lng += pathComplexity - randomDeviation; // Opposite sign for natural curve
        
        route.add(LatLng(lat, lng));
      }
      
      // Always add the destination at the end
      route.add(destination);
      
      return route;
    } catch (e) {
      print('Error calculating offline route: $e');
      // Simple fallback to direct line
      return [start, destination];
    }
  }

  void _handleLocationError(dynamic error) {
    if (!mounted || _userLocation != null) return;
    setState(() {
      _errorMessage = 'Location error: Please check your GPS signal';
    });
  }

  void _initializeCompass() {
    if (FlutterCompass.events == null) {
      setState(() {
        _errorMessage = 'Compass not available on this device';
      });
      return;
    }

    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (event.heading != null && mounted) {
        setState(() {
          _currentBearing = event.heading!;  // This will now reflect actual device orientation
        });
      }
    }, onError: (e) {
      print('Compass error: $e');
      // Handle compass errors gracefully
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Compass error - Please calibrate your device'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  Future<bool> _checkConnectivity() async {
    try {
      final result = await http.get(Uri.parse('https://www.google.com')).timeout(
        const Duration(seconds: 5),
      );
      return result.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<void> _loadCachedRoutes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final routesJson = prefs.getString(_routeCacheKey);
      if (routesJson != null) {
        final routesMap = jsonDecode(routesJson) as Map<String, dynamic>;
        _cachedRoutes = routesMap.map((key, value) {
          final points = (value as List).map((point) {
            final coords = point as List;
            return LatLng(coords[0] as double, coords[1] as double);
          }).toList();
          return MapEntry(key, points);
        });
        print('Loaded ${_cachedRoutes.length} cached routes');
      }
    } catch (e) {
      print('Error loading cached routes: $e');
      _cachedRoutes = {}; // Reset if there's an error
    }
  }

  Future<void> _saveCachedRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final routesJson = jsonEncode(_cachedRoutes.map((key, value) {
      final points = value.map((point) => [point.latitude, point.longitude]).toList();
      return MapEntry(key, points);
    }));
    await prefs.setString(_routeCacheKey, routesJson);
  }

  String _getRouteCacheKey(LatLng start, LatLng dest) {
    return '${start.latitude},${start.longitude}-${dest.latitude},${dest.longitude}';
  }

  Future<void> _calculateRoute(LatLng start, LatLng destination) async {
    final cacheKey = _getRouteCacheKey(start, destination);
    
    setState(() => _isLoading = true);
    
    try {
      // First, check if we have a cached route
      if (_cachedRoutes.containsKey(cacheKey)) {
        final cachedRoute = _cachedRoutes[cacheKey]!;
        
        // Verify the cached route is valid
        if (cachedRoute.length > 1) {
          setState(() {
            _routePoints = cachedRoute;
            _isLoading = false;
          });
          
          // Try to update the cached route in the background if online
          if (widget.isOnline) {
            _updateCachedRoute(cacheKey, start, destination);
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Using downloaded route')),
          );
          return;
        }
      }

      // If online, try to get a new route
      if (widget.isOnline) {
        final onlineRoute = await _fetchOnlineRoute(start, destination);
        if (onlineRoute != null && onlineRoute.length > 1) {
          _cachedRoutes[cacheKey] = onlineRoute;
          await _saveCachedRoutes();
          
          setState(() {
            _routePoints = onlineRoute;
            _isLoading = false;
          });
          return;
        }
      }

      // Fallback to calculated offline route (not just straight line)
      final offlineRoute = _createOfflineRoute(start, destination);
      setState(() {
        _routePoints = offlineRoute;
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.isOnline 
            ? 'Failed to get online route - using offline route'
            : 'Offline mode - using offline route'),
        ),
      );
    } catch (e) {
      print('Route calculation error: $e');
      setState(() {
        _routePoints = [start, destination];
        _isLoading = false;
      });
    }
  }

  Future<List<LatLng>?> _fetchOnlineRoute(LatLng start, LatLng destination) async {
    try {
      // Try OSRM first (OpenStreetMap's routing service)
      final startCoord = '${start.longitude},${start.latitude}';
      final destCoord = '${destination.longitude},${destination.latitude}';
      final url = Uri.parse(
        '$_baseUrl/routed-foot/route/v1/foot/$startCoord;$destCoord'
        '?overview=full&geometries=geojson&steps=true'
      );

      final response = await http.get(url).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['routes']?.isNotEmpty) {
          final geometry = data['routes'][0]['geometry'];
          final coordinates = geometry['coordinates'] as List;
          return coordinates.map((coord) {
            return LatLng(coord[1] as double, coord[0] as double);
          }).toList();
        }
      }

      // If OSRM fails, try GraphHopper as backup
      final ghUrl = Uri.parse(
        'https://graphhopper.com/api/1/route'
        '?point=${start.latitude},${start.longitude}'
        '&point=${destination.latitude},${destination.longitude}'
        '&vehicle=foot'
        '&points_encoded=false'
        '&key=$_graphhopperKey'
      );

      final ghResponse = await http.get(ghUrl).timeout(
        const Duration(seconds: 10),
      );

      if (ghResponse.statusCode == 200) {
        final ghData = jsonDecode(ghResponse.body);
        final points = ghData['paths'][0]['points']['coordinates'] as List;
        return points.map((point) {
          return LatLng(point[1] as double, point[0] as double);
        }).toList();
      }

      // If both services fail, try OpenRouteService
      final orsUrl = Uri.parse(
        'https://api.openrouteservice.org/v2/directions/foot-walking'
      );
      
      final orsResponse = await http.post(
        orsUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': _apiKey,
        },
        body: jsonEncode({
          'coordinates': [
            [start.longitude, start.latitude],
            [destination.longitude, destination.latitude]
          ],
        }),
      ).timeout(const Duration(seconds: 10));

      if (orsResponse.statusCode == 200) {
        final orsData = jsonDecode(orsResponse.body);
        final coordinates = orsData['features'][0]['geometry']['coordinates'] as List;
        return coordinates.map((coord) {
          return LatLng(coord[1] as double, coord[0] as double);
        }).toList();
      }

      print('All routing services failed');
      return null;
    } catch (e) {
      print('Error fetching route: $e');
      return null;
    }
  }

  Future<void> _updateCachedRoute(String cacheKey, LatLng start, LatLng destination) async {
    try {
      final newRoute = await _fetchOnlineRoute(start, destination);
      if (newRoute != null) {
        // Compare with existing route
        final existingRoute = _cachedRoutes[cacheKey]!;
        if (_isRouteSignificantlyDifferent(existingRoute, newRoute)) {
          _cachedRoutes[cacheKey] = newRoute;
          await _saveCachedRoutes();
          
          // Update current route if navigating
          if (_isNavigating && mounted) {
            setState(() => _routePoints = newRoute);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Route updated with latest data')),
            );
          }
        }
      }
    } catch (e) {
      print('Failed to update cached route: $e');
    }
  }

  bool _isRouteSignificantlyDifferent(List<LatLng> route1, List<LatLng> route2) {
    if ((route1.length - route2.length).abs() > 5) return true;
    
    // Check if any point differs by more than 50 meters
    for (int i = 0; i < math.min(route1.length, route2.length); i++) {
      if (_calculateDistance(route1[i], route2[i]) > 50) {
        return true;
      }
    }
    return false;
  }

  List<LatLng> _createOfflineRoute(LatLng start, LatLng destination) {
    try {
      List<LatLng> route = [];
      
      // Always add the starting point
      route.add(start);
      
      // Calculate initial bearing and distance
      double totalDistance = _calculateDistance(start, destination);
      double initialBearing = _calculateBearing(start, destination);
      
      // For very short distances, just return direct line
      if (totalDistance < 100) {
        route.add(destination);
        return route;
      }
      
      // Create more natural path with slight variations
      int numPoints = math.min((totalDistance / 20).ceil(), maxPathNodes); // One point every 20 meters
      numPoints = math.max(numPoints, 5); // Minimum 5 points for smoother path
      
      // Generate intermediate points
      for (int i = 1; i < numPoints; i++) {
        double progress = i / numPoints;
        
        // Linear interpolation with slight deviation
        double lat = start.latitude + (destination.latitude - start.latitude) * progress;
        double lng = start.longitude + (destination.longitude - start.longitude) * progress;
        
        // Add some randomness for a more natural path (but not too much)
        double deviation = 0.00005 * math.sin(progress * math.pi * 2); // very small deviation
        lat += deviation;
        lng += deviation;
        
        route.add(LatLng(lat, lng));
      }
      
      // Always add the destination at the end
      if (route.last != destination) {
        route.add(destination);
      }
      
      return route;
    } catch (e) {
      print('Error calculating offline route: $e');
      // Fallback to simple direct path
      return [start, destination];
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    double lat1 = _toRadians(point1.latitude);
    double lon1 = _toRadians(point1.longitude);
    double lat2 = _toRadians(point2.latitude);
    double lon2 = _toRadians(point2.longitude);
    
    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;
    
    double a = math.sin(dLat/2) * math.sin(dLat/2) +
               math.cos(lat1) * math.cos(lat2) *
               math.sin(dLon/2) * math.sin(dLon/2);
               
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
    return 6371000 * c; // Earth's radius in meters * c
  }

  double _calculateBearing(LatLng point1, LatLng point2) {
    double lat1 = _toRadians(point1.latitude);
    double lon1 = _toRadians(point1.longitude);
    double lat2 = _toRadians(point2.latitude);
    double lon2 = _toRadians(point2.longitude);
    
    double dLon = lon2 - lon1;
    
    double y = math.sin(dLon) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) -
               math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
               
    double bearing = math.atan2(y, x);
    return _toDegrees(bearing);
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;
  double _toDegrees(double radians) => radians * 180 / math.pi;

  void _startNavigation(EvacuationCenter center) async {
    if (_userLocation == null) return;
    
    setState(() {
      _selectedCenter = center;
      _isNavigating = true;
      // Only move map if it's initialized
      if (_isMapInitialized) {
        try {
          _mapController.move(_userLocation!, 17);
        } catch (e) {
          print('MapController error in navigation: $e');
        }
      }
    });

    await _calculateRoute(_userLocation!, center.location);
    Navigator.pop(context);
  }

  void _stopNavigation() {
    setState(() {
      _selectedCenter = null;
      _isNavigating = false;
      _routePoints = null;
    });
  }

  void _retryLocation() {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    _initializeLocation();
  }

  void _startPositionUpdates() {
    // Update position more frequently - every 0.5 seconds
    _positionUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      _updateCurrentPosition();
    });

    // Configure position stream for better responsiveness
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3, // Update every 3 meters of movement
        timeLimit: null,
      ),
    ).listen(
      _handlePositionUpdate,
      onError: _handleLocationError,
    );
  }

  Future<void> _updateCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      if (!mounted) return;

      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        
        // Auto-center map if navigating
        if (_isNavigating && _isMapInitialized && _mapController.camera.zoom > 0) {
          try {
            _mapController.move(_userLocation!, _mapController.camera.zoom);
          } catch (e) {
            print('MapController error: $e');
          }
        }
        
        // Always recalculate route when position updates
        if (_isNavigating && _selectedCenter != null) {
          _recalculateRouteBasedOnCurrentPosition();
        }
      });
    } catch (e) {
      print('Position update error: $e');
    }
  }

  void _updateUserMarker() {
    if (_userLocation == null) return;
    
    setState(() {
      // Update any UI elements that depend on user location
      if (_routePoints != null && _routePoints!.isNotEmpty) {
        // Recalculate distance to destination
        var distanceToDestination = _calculateDistance(
          _userLocation!,
          _routePoints!.last
        );
        
        // Update navigation if needed
        if (distanceToDestination < 10) { // Within 10 meters of destination
          _handleArrival();
        }
      }
    });
  }

  void _handleArrival() {
    if (!_isNavigating) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You have arrived at your destination'),
        backgroundColor: Colors.green,
      ),
    );
    
    setState(() {
      _isNavigating = false;
      _routePoints = null;
    });
  }

  Future<void> _startAutoNavigation() async {
    print("Starting auto navigation...");
    if (_userLocation == null) {
      print("User location is null, can't start navigation");
      return;
    }

    // Find nearest evacuation center
    EvacuationCenter? nearest = _findNearestEvacuationCenter();
    if (nearest == null) {
      print("No evacuation center found");
      return;
    }

    final cacheKey = _getRouteCacheKey(_userLocation!, nearest.location);
    print("Cache key: $cacheKey");

    // Set selected center and start navigation mode
    setState(() {
      _selectedCenter = nearest;
      _isNavigating = true;
      _isLoading = true; // Set loading state
    });

    // Number of retries for route calculation
    int maxRetries = 3;
    int currentTry = 0;
    bool routeCalculated = false;

    while (currentTry < maxRetries && !routeCalculated) {
      try {
        // Try cached route first
        if (_cachedRoutes.containsKey(cacheKey)) {
          final cachedRoute = _cachedRoutes[cacheKey]!;
          if (cachedRoute.length > 1) {
            setState(() {
              _routePoints = List<LatLng>.from(cachedRoute);
              _isLoading = false;
            });
            routeCalculated = true;
            break;
          }
        }

        // Try online route calculation
        if (widget.isOnline) {
          final route = await _fetchOnlineRoute(_userLocation!, nearest.location);
          if (route != null && route.length > 1) {
            _cachedRoutes[cacheKey] = List<LatLng>.from(route);
            await _saveCachedRoutes();
            setState(() {
              _routePoints = route;
              _isLoading = false;
            });
            routeCalculated = true;
            break;
          }
        }

        // If still not calculated, try offline route
        if (!routeCalculated) {
          final offlineRoute = _createOfflineRoute(_userLocation!, nearest.location);
          if (offlineRoute.length > 2) { // Ensure it's not just start and end points
            setState(() {
              _routePoints = offlineRoute;
              _isLoading = false;
            });
            routeCalculated = true;
            break;
          }
        }

        currentTry++;
        if (currentTry < maxRetries) {
          // Wait before retrying
          await Future.delayed(const Duration(seconds: 1));
        }
      } catch (e) {
        print('Error in route calculation attempt $currentTry: $e');
        currentTry++;
        if (currentTry < maxRetries) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }

    // If all attempts fail, use a more sophisticated fallback
    if (!routeCalculated) {
      print("All route calculation attempts failed, using enhanced fallback");
      final enhancedFallbackRoute = _createEnhancedFallbackRoute(
        _userLocation!, 
        nearest.location
      );
      setState(() {
        _routePoints = enhancedFallbackRoute;
        _isLoading = false;
      });
    }

    // Move map to show the route
    if (_controllerReady && mounted) {
      try {
        _mapController.move(_userLocation!, 17);
      } catch (e) {
        print('MapController error in auto navigation: $e');
      }
    }
  }

  List<LatLng> _createEnhancedFallbackRoute(LatLng start, LatLng destination) {
    List<LatLng> route = [];
    route.add(start);

    // Create intermediate points for a more natural path
    const int numPoints = 5; // Minimum number of points
    for (int i = 1; i < numPoints; i++) {
      final double fraction = i / numPoints;
      
      // Linear interpolation with slight randomization
      double lat = start.latitude + (destination.latitude - start.latitude) * fraction;
      double lng = start.longitude + (destination.longitude - start.longitude) * fraction;
      
      // Add small random deviation to avoid straight line
      final double deviation = 0.0001 * (math.Random().nextDouble() - 0.5);
      lat += deviation;
      lng += deviation;
      
      route.add(LatLng(lat, lng));
    }
    
    route.add(destination);
    return route;
  }

  // Add this method to update cached routes in the background without affecting UI
  Future<void> _updateCachedRouteInBackground(String cacheKey, LatLng start, LatLng destination) async {
    try {
      final newRoute = await _fetchOnlineRoute(start, destination);
      if (newRoute != null && newRoute.length > 1) {
        // Only update if significantly different
        final existingRoute = _cachedRoutes[cacheKey]!;
        if (_isRouteSignificantlyDifferent(existingRoute, newRoute)) {
          _cachedRoutes[cacheKey] = newRoute;
          await _saveCachedRoutes();
          
          // Only update UI if still navigating to the same destination
          if (_isNavigating && mounted && _selectedCenter?.location == destination) {
            setState(() => _routePoints = newRoute);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Route updated with latest data')),
            );
          }
        }
      }
    } catch (e) {
      print('Failed to update cached route in background: $e');
    }
  }

  EvacuationCenter? _findNearestEvacuationCenter() {
    if (_userLocation == null) return null;

    EvacuationCenter? nearest;
    double minDistance = double.infinity;

    for (var center in evacuationCenters) {
      double distance = _calculateDistance(_userLocation!, center.location);
      if (distance < minDistance) {
        minDistance = distance;
        nearest = center;
      }
    }

    return nearest;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && !_isMapInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && !_isMapInitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _retryLocation,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        FlutterMap(
          key: _mapKey, // Add key to help with rerendering
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _userLocation ?? tagumCenter,
            initialZoom: 17,
            minZoom: 15,
            maxZoom: 18,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onMapReady: () {
              // Mark map as initialized when it's ready
              setState(() {
                _isMapInitialized = true;
                _controllerReady = true;
                print('Map is initialized and ready');
              });
            },
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.naviquake.app',
              tileProvider: _tileProvider,
            ),
            if (_routePoints != null && _routePoints!.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routePoints!,
                    color: Colors.blue,
                    strokeWidth: 4.0,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (_userLocation != null)
                  Marker(
                    point: _userLocation!,
                    width: 30,
                    height: 30,
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.blue,
                      size: 30,
                    ),
                  ),
                ...evacuationCenters.map((center) => Marker(
                  point: center.location,
                  width: 40,
                  height: 40,
                  child: GestureDetector(
                    onTap: () => _showEvacuationCenterInfo(context, center),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            center.name,
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                        const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 30,
                        ),
                      ],
                    ),
                  ),
                )),
              ],
            ),
          ],
        ),
        if (_isLoading && _isMapInitialized)
          const Positioned(
            top: 60,
            right: 16,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
        if (_isNavigating && _selectedCenter != null && _userLocation != null)
          NavigationOverlay(
            currentLocation: _userLocation!,
            destination: _selectedCenter!.location,
            routePoints: _routePoints,
            currentBearing: _currentBearing,
          ),
      ],
    );
  }

  void _showEvacuationCenterInfo(BuildContext context, EvacuationCenter center) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              center.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              center.description,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Coordinates: ${center.location.latitude.toStringAsFixed(6)}, '
              '${center.location.longitude.toStringAsFixed(6)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_userLocation != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isDownloadingRoute ? null : () => _downloadRoute(center),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      icon: _isDownloadingRoute 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.download, size: 20),
                      label: Text(
                        _isDownloadingRoute ? 'Downloading...' : 'Download Route',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _startNavigation(center),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.directions, size: 20),
                    label: const Text('Navigate', style: TextStyle(fontSize: 14)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadRoute(EvacuationCenter center) async {
    if (_userLocation == null) return;

    setState(() => _isDownloadingRoute = true);
    final cacheKey = _getRouteCacheKey(_userLocation!, center.location);

    try {
      final route = await _fetchOnlineRoute(_userLocation!, center.location);
      if (route != null) {
        _cachedRoutes[cacheKey] = route;
        await _saveCachedRoutes();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Route downloaded successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to download route'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloadingRoute = false);
      }
    }
  }
}