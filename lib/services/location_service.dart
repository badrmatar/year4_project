// lib/services/location_service.dart
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  LocationService() {
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    // Check and request location permissions if necessary.
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      await Geolocator.requestPermission();
    }
  }

  Future<Position?> getCurrentLocation() async {
    try {
      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are not enabled, show dialog to user
        return null;
      }

      // Check for location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Use high accuracy for running apps
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        // iOS sometimes needs a bit more time to get accurate location
        timeLimit: defaultTargetPlatform == TargetPlatform.iOS
            ? const Duration(seconds: 15)
            : const Duration(seconds: 10),
      );
    } catch (e) {
      print('Error getting location: $e');
      return null;
    }
  }

  // Continuous location tracking stream.
  Stream<Position> trackLocation() {
    // iOS sometimes needs more specific settings
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 15,
      // Add a time limit for iOS that won't affect Android's existing behavior
      timeLimit: defaultTargetPlatform == TargetPlatform.iOS
          ? const Duration(seconds: 10)
          : null,
    );
    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }
}