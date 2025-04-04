import 'package:latlong2/latlong.dart';
import 'dart:math' show asin, atan2, cos, pi, pow, sin, sqrt;

class NavigationInstruction {
  final String instruction;
  final double distance;
  final double bearing;
  final LatLng point;

  NavigationInstruction({
    required this.instruction,
    required this.distance,
    required this.bearing,
    required this.point,
  });
}

class NavigationService {
  static const double EARTH_RADIUS = 6371000; // meters

  static double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  static double _toDegrees(double radians) {
    return radians * 180 / pi;
  }

  static double calculateDistance(LatLng start, LatLng end) {
    double lat1 = _toRadians(start.latitude);
    double lon1 = _toRadians(start.longitude);
    double lat2 = _toRadians(end.latitude);
    double lon2 = _toRadians(end.longitude);

    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;

    double a = pow(sin(dLat / 2), 2) +
        cos(lat1) * cos(lat2) * pow(sin(dLon / 2), 2);
    double c = 2 * asin(sqrt(a));
    return EARTH_RADIUS * c;
  }

  static double calculateBearing(LatLng start, LatLng end) {
    double lat1 = _toRadians(start.latitude);
    double lon1 = _toRadians(start.longitude);
    double lat2 = _toRadians(end.latitude);
    double lon2 = _toRadians(end.longitude);

    double dLon = lon2 - lon1;

    double y = sin(dLon) * cos(lat2);
    double x = cos(lat1) * sin(lat2) -
        sin(lat1) * cos(lat2) * cos(dLon);

    double bearing = _toDegrees(atan2(y, x));
    return (bearing + 360) % 360;
  }

  static String getBearingDescription(double bearing) {
    const directions = [
      'north', 'northeast', 'east', 'southeast',
      'south', 'southwest', 'west', 'northwest'
    ];
    int index = ((bearing + 22.5) % 360 / 45).floor();
    return directions[index];
  }

  static List<NavigationInstruction> generateInstructions(
    LatLng start,
    LatLng destination
  ) {
    double distance = calculateDistance(start, destination);
    double bearing = calculateBearing(start, destination);
    String direction = getBearingDescription(bearing);

    return [
      NavigationInstruction(
        instruction: 'Head $direction for ${distance.toStringAsFixed(0)} meters',
        distance: distance,
        bearing: bearing,
        point: start,
      ),
      NavigationInstruction(
        instruction: 'Arrive at destination',
        distance: 0,
        bearing: bearing,
        point: destination,
      ),
    ];
  }
} 