import 'package:geolocator/geolocator.dart';

class LocationPermissionService {
  /// Request lokasi permission dan return status
  static Future<bool> requestLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        final result = await Geolocator.requestPermission();
        return result == LocationPermission.whileInUse ||
            result == LocationPermission.always;
      } else if (permission == LocationPermission.deniedForever) {
        // Buka app settings jika permission ditolak permanent
        await Geolocator.openLocationSettings();
        return false;
      } else if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get current location
  static Future<Position?> getCurrentLocation() async {
    try {
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return position;
    } catch (e) {
      return null;
    }
  }

  /// Get location stream for real-time updates
  static Stream<Position> getLocationStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10, // Meter
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );
  }

  /// Check if location service is enabled
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
}
