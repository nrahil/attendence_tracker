import 'dart:math';

class GeoCoordinates {
  final double latitude;
  final double longitude;

  const GeoCoordinates({required this.latitude, required this.longitude});

  Map<String, dynamic> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
  };

  factory GeoCoordinates.fromMap(Map<String, dynamic> map) => GeoCoordinates(
    latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
  );
}

class GeofenceValidationResult {
  final bool isInside;
  final double distanceMeters;
  final double allowedRadiusMeters;
  final String message;

  const GeofenceValidationResult({
    required this.isInside,
    required this.distanceMeters,
    required this.allowedRadiusMeters,
    required this.message,
  });
}

class GeofenceService {
  static const double earthRadiusMeters = 6371000.0;

  /// Default campus coordinates (Mock institutional location)
  static const GeoCoordinates defaultCampusLocation = GeoCoordinates(
    latitude: 28.6139,
    longitude: 77.2090,
  );

  /// Computes distance in meters using the Haversine formula
  static double calculateDistanceMeters(GeoCoordinates start, GeoCoordinates end) {
    final dLat = _degToRad(end.latitude - start.latitude);
    final dLon = _degToRad(end.longitude - start.longitude);

    final lat1 = _degToRad(start.latitude);
    final lat2 = _degToRad(end.latitude);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        sin(dLon / 2) * sin(dLon / 2) * cos(lat1) * cos(lat2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadiusMeters * c;
  }

  static double _degToRad(double deg) => deg * (pi / 180.0);

  /// Validates whether the student's check-in location is inside the classroom or campus boundary
  static GeofenceValidationResult validateLocation({
    required GeoCoordinates studentLocation,
    required GeoCoordinates centerLocation,
    double radiusMeters = 100.0,
  }) {
    final distance = calculateDistanceMeters(studentLocation, centerLocation);
    final isInside = distance <= radiusMeters;

    final distanceStr = distance.toStringAsFixed(1);
    final radiusStr = radiusMeters.toStringAsFixed(0);

    return GeofenceValidationResult(
      isInside: isInside,
      distanceMeters: distance,
      allowedRadiusMeters: radiusMeters,
      message: isInside
          ? 'Location verified within classroom geofence ($distanceStr m <= $radiusStr m).'
          : 'Out of boundary! You are $distanceStr m away (Allowed: $radiusStr m). Check-in rejected.',
    );
  }
}

