import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

class NavigationOverlay extends StatefulWidget {
  final LatLng currentLocation;
  final LatLng destination;
  final List<LatLng>? routePoints;
  final double currentBearing;

  const NavigationOverlay({
    super.key,
    required this.currentLocation,
    required this.destination,
    this.routePoints,
    required this.currentBearing,
  });

  @override
  State<NavigationOverlay> createState() => _NavigationOverlayState();
}

class _NavigationOverlayState extends State<NavigationOverlay> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _lastDirection;
  double _lastDirectionAngle = 0;
  double _totalDistance = 0;
  int _currentSegment = 0;
  String? _currentDirection;
  Timer? _directionCheckTimer;

  @override
  void initState() {
    super.initState();
    // Start periodic direction check
    _directionCheckTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkDirectionChange();
    });
  }

  @override
  void dispose() {
    _directionCheckTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playDirectionAudio(String direction) async {
    if (_lastDirection != direction) {
      try {
        await _audioPlayer.play(AssetSource('audio/directions/$direction.mp3'));
        _lastDirection = direction;
      } catch (e) {
        print('Error playing direction audio: $e');
      }
    }
  }

  void _checkDirectionChange() {
    if (widget.routePoints == null || widget.routePoints!.isEmpty) return;
    
    var nextPoint = _getNextPoint();
    if (nextPoint == null) return;

    var bearing = _calculateBearing(widget.currentLocation, nextPoint);
    var newDirection = _getDirectionFromBearing(bearing);
    
    if (_currentDirection != newDirection) {
      _currentDirection = newDirection;
      _playDirectionAudio(newDirection);
      setState(() {
        _lastDirectionAngle = _getDirectionAngle(newDirection);
      });
    }
  }

  LatLng? _getNextPoint() {
    if (_currentSegment >= widget.routePoints!.length - 1) return null;

    var distanceToNext = _calculateDistance(
      widget.currentLocation,
      widget.routePoints![_currentSegment + 1]
    );

    // Update segment if close to next point
    if (distanceToNext < 10) {
      setState(() {
        _currentSegment = min(_currentSegment + 1, widget.routePoints!.length - 2);
      });
    }

    return widget.routePoints![_currentSegment + 1];
  }

  double _getDirectionAngle(String direction) {
    final Map<String, double> directionAngles = {
      'north': 0,
      'northeast': 45,
      'east': 90,
      'southeast': 135,
      'south': 180,
      'southwest': 225,
      'west': 270,
      'northwest': 315,
    };
    return directionAngles[direction] ?? 0;
  }

  String _getDirectionalGuidance() {
    if (widget.routePoints == null || widget.routePoints!.isEmpty) {
      return 'Calculating route...';
    }

    if (_currentSegment >= widget.routePoints!.length - 1) {
      _playDirectionAudio('arrived');
      return 'You have arrived';
    }

    var nextPoint = _getNextPoint();
    if (nextPoint == null) return 'Calculating...';

    var distanceToNext = _calculateDistance(widget.currentLocation, nextPoint);
    _updateTotalDistance();

    String instruction = '';
    if (distanceToNext < 50) {
      instruction = 'Almost there! Head ${_currentDirection ?? "straight"}';
    } else {
      instruction = 'Head ${_currentDirection ?? "straight"} for ${distanceToNext.toStringAsFixed(0)}m';
    }

    return instruction;
  }

  void _updateTotalDistance() {
    if (widget.routePoints == null || _currentSegment >= widget.routePoints!.length - 1) return;
    
    _totalDistance = widget.routePoints!
        .sublist(_currentSegment)
        .fold(0.0, (sum, point) => sum + _calculateDistance(
            point,
            widget.routePoints![min(
                widget.routePoints!.indexOf(point) + 1,
                widget.routePoints!.length - 1)]));
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    var lat1 = point1.latitude * pi / 180;
    var lat2 = point2.latitude * pi / 180;
    var dLat = (point2.latitude - point1.latitude) * pi / 180;
    var dLon = (point2.longitude - point1.longitude) * pi / 180;

    var a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    var c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _calculateBearing(LatLng point1, LatLng point2) {
    var lat1 = point1.latitude * pi / 180;
    var lat2 = point2.latitude * pi / 180;
    var dLon = (point2.longitude - point1.longitude) * pi / 180;

    var y = sin(dLon) * cos(lat2);
    var x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);
    var bearing = atan2(y, x);
    return (bearing * 180 / pi + 360) % 360;
  }

  String _getDirectionFromBearing(double bearing) {
    const directions = ['north', 'northeast', 'east', 'southeast', 
                       'south', 'southwest', 'west', 'northwest'];
    var index = ((bearing + 22.5) % 360) ~/ 45;
    return directions[index];
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 40,
      left: 0,
      right: 0,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Distance remaining: ${_totalDistance.toStringAsFixed(0)}m',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Transform.rotate(
                    angle: (-_lastDirectionAngle * pi / 180),
                    child: const Icon(Icons.arrow_upward, size: 24, color: Colors.red),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _getDirectionalGuidance(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}