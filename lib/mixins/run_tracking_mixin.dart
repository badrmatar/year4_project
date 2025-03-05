import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';
import '../services/location_service.dart';

mixin RunTrackingMixin<T extends StatefulWidget> on State<T> {
  // Common variables:
  final LocationService locationService = LocationService();
  Position? currentLocation;
  Position? startLocation;
  Position? endLocation;
  double distanceCovered = 0.0;
  int secondsElapsed = 0;
  Timer? runTimer;
  bool isTracking = false;
  bool autoPaused = false;
  StreamSubscription<Position>? locationSubscription;

  // Mapping route points:
  final List<LatLng> routePoints = [];
  Polyline routePolyline = const Polyline(
    polylineId: PolylineId('route'),
    color: Colors.orange,
    width: 5,
    points: [],
  );
  GoogleMapController? mapController;

  // Auto-pause variables:
  int stillCounter = 0;
  final double pauseThreshold = 0.5; // in m/s
  final double resumeThreshold = 1.0; // in m/s
  LatLng? lastRecordedLocation;

  // Minimum distance threshold for adding points to reduce jitter (in meters)
  final double minDistanceThreshold = 2.0;

  /// Start run: initialize all variables and start tracking.
  void startRun(Position initialPosition) {
    print('RunTrackingMixin: Starting run with initial position: ${initialPosition.latitude}, ${initialPosition.longitude}');

    // Stop any existing subscriptions first
    locationSubscription?.cancel();
    runTimer?.cancel();

    setState(() {
      startLocation = initialPosition;
      currentLocation = initialPosition;
      isTracking = true;
      distanceCovered = 0.0;
      secondsElapsed = 0;
      autoPaused = false;
      stillCounter = 0;

      // Clear and initialize route points
      routePoints.clear();
      final startPoint = LatLng(initialPosition.latitude, initialPosition.longitude);
      routePoints.add(startPoint);
      lastRecordedLocation = startPoint;

      // Create initial polyline
      routePolyline = Polyline(
        polylineId: const PolylineId('route'),
        color: Colors.orange,
        width: 5,
        points: [startPoint],
      );

      print('RunTrackingMixin: Route initialized with start point, polyline created');
    });

    // Start timer for elapsed time.
    runTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!autoPaused && mounted && isTracking) {
        setState(() {
          secondsElapsed++;
          if (secondsElapsed % 10 == 0) {
            print('RunTrackingMixin: Run in progress - ${secondsElapsed}s elapsed, ${(distanceCovered/1000).toStringAsFixed(2)}km covered');
          }
        });
      }
    });

    // Subscribe to location updates
    locationSubscription = locationService.trackLocation().listen((position) {
      if (mounted && isTracking) {
        _handleLocationUpdate(position);
      }
    });

    print('RunTrackingMixin: Location tracking started');

    // Move map to current location
    if (mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(initialPosition.latitude, initialPosition.longitude),
          16,
        ),
      );
      print('RunTrackingMixin: Map camera moved to initial position');
    }
  }

  void _handleLocationUpdate(Position position) {
    if (!isTracking) {
      print('RunTrackingMixin: Ignoring location update as tracking is off');
      return;
    }

    print('RunTrackingMixin: Received location: ${position.latitude}, ${position.longitude}, accuracy: ${position.accuracy}m, speed: ${position.speed}m/s');

    // Calculate speed and handle auto-pause logic
    final speed = position.speed >= 0 ? position.speed : 0.0;
    _handleAutoPauseLogic(speed);

    // Update current location
    setState(() {
      currentLocation = position;
    });

    // Create the new point
    final newPoint = LatLng(position.latitude, position.longitude);

    // Only add point and update distance if not auto-paused and has moved enough
    if (!autoPaused && lastRecordedLocation != null) {
      final distanceFromLast = _calculateDistanceBetweenPoints(
          lastRecordedLocation!,
          newPoint
      );

      print('RunTrackingMixin: Distance from last point: ${distanceFromLast.toStringAsFixed(2)}m, threshold: ${minDistanceThreshold}m');

      // If moved more than threshold, update path and distance
      if (distanceFromLast > minDistanceThreshold) {
        setState(() {
          // Update total distance
          distanceCovered += distanceFromLast;

          // Add new point to route
          routePoints.add(newPoint);

          print('RunTrackingMixin: Updated path - added point #${routePoints.length}, total distance: ${distanceCovered.toStringAsFixed(2)}m');

          // Update polyline with all points
          routePolyline = Polyline(
            polylineId: const PolylineId('route'),
            color: Colors.orange,
            width: 5,
            points: List.from(routePoints),
          );

          // Update last recorded location
          lastRecordedLocation = newPoint;
        });
      } else {
        print('RunTrackingMixin: Skipped point - too close to previous');
      }
    } else {
      if (autoPaused) {
        print('RunTrackingMixin: Not updating path - run is auto-paused');
      } else if (lastRecordedLocation == null) {
        print('RunTrackingMixin: No last location recorded yet');
      }
    }

    // Always animate camera to follow user
    _animateToCurrentLocation(position);
  }

  void _animateToCurrentLocation(Position position) {
    if (mapController != null) {
      mapController!.animateCamera(
          CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude))
      );
    }
  }

  /// Calculate distance between two LatLng points using Geolocator
  double _calculateDistanceBetweenPoints(LatLng start, LatLng end) {
    try {
      // Use Geolocator's more accurate distance calculation
      final distance = Geolocator.distanceBetween(
          start.latitude,
          start.longitude,
          end.latitude,
          end.longitude
      );

      // Log the calculated distance
      print('Distance calculation: from (${start.latitude}, ${start.longitude}) to (${end.latitude}, ${end.longitude}) = ${distance.toStringAsFixed(2)}m');

      return distance;
    } catch (e) {
      print('Error calculating distance: $e');

      // Fallback to haversine formula if Geolocator fails
      const double earthRadius = 6371000.0; // in meters
      final startLat = start.latitude;
      final startLng = start.longitude;
      final endLat = end.latitude;
      final endLng = end.longitude;

      final dLat = (endLat - startLat) * (pi / 180);
      final dLng = (endLng - startLng) * (pi / 180);
      final a = sin(dLat / 2) * sin(dLat / 2) +
          cos(startLat * (pi / 180)) * cos(endLat * (pi / 180)) *
              sin(dLng / 2) * sin(dLng / 2);
      final c = 2 * atan2(sqrt(a), sqrt(1 - a));
      return earthRadius * c;
    }
  }

  /// Stop the run.
  void endRun() {
    runTimer?.cancel();
    locationSubscription?.cancel();
    isTracking = false;
    endLocation = currentLocation;
  }

  /// Calculate distance using the haversine formula.
  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    const double earthRadius = 6371000.0;
    final dLat = (endLat - startLat) * (pi / 180);
    final dLng = (endLng - startLng) * (pi / 180);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(startLat * (pi / 180)) * cos(endLat * (pi / 180)) *
            sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  /// Auto-pause logic based on speed.
  void _handleAutoPauseLogic(double speed) {
    if (autoPaused) {
      if (speed > resumeThreshold) {
        setState(() {
          autoPaused = false;
          stillCounter = 0;
        });
        print('Run resumed: speed = $speed m/s');
      }
    } else {
      if (speed < pauseThreshold) {
        stillCounter++;
        if (stillCounter >= 5) {
          setState(() => autoPaused = true);
          print('Run auto-paused: low speed detected');
        }
      } else {
        stillCounter = 0;
      }
    }
  }

  @override
  void dispose() {
    runTimer?.cancel();
    locationSubscription?.cancel();
    super.dispose();
  }
}