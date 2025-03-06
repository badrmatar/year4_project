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
  StreamSubscription<Position>? trackingSubscription;

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
  final double pauseThreshold = 0.5;
  final double resumeThreshold = 1.0;
  LatLng? lastRecordedLocation;

  // Minimum distance to record (to filter out jitter)
  final double minDistanceThreshold = 5.0; // meters

  /// Start run: initialize all variables and start tracking.
  void startRun(Position initialPosition) {
    print('RunTrackingMixin: Starting run with initial position');

    // Clean up any existing timers/subscriptions
    runTimer?.cancel();
    locationSubscription?.cancel();
    trackingSubscription?.cancel();

    setState(() {
      startLocation = initialPosition;
      currentLocation = initialPosition;
      isTracking = true;
      distanceCovered = 0.0;
      secondsElapsed = 0;
      autoPaused = false;
      routePoints.clear();

      final startPoint = LatLng(initialPosition.latitude, initialPosition.longitude);
      routePoints.add(startPoint);
      routePolyline = Polyline(
        polylineId: const PolylineId('route'),
        color: Colors.orange,
        width: 5,
        points: [startPoint],
      );
      lastRecordedLocation = startPoint;
    });

    // Start timer for elapsed time.
    runTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!autoPaused && mounted) {
        setState(() => secondsElapsed++);
      }
    });

    // This is critical: we need a dedicated tracking subscription that works
    // separately from the location updates subscription
    trackingSubscription = locationService.trackLocation().listen((position) {
      if (!isTracking) return;

      // Get speed and handle auto-pause logic
      final speed = position.speed.clamp(0.0, double.infinity);
      _handleAutoPauseLogic(speed);

      // Update path and distance if not paused
      if (!autoPaused && lastRecordedLocation != null) {
        final distanceFromLast = _calculateDistance(
          lastRecordedLocation!.latitude,
          lastRecordedLocation!.longitude,
          position.latitude,
          position.longitude,
        );

        // Only add significant movements (avoid GPS jitter)
        if (distanceFromLast > minDistanceThreshold) {
          setState(() {
            // Update total distance
            distanceCovered += distanceFromLast;
            print('New distance: $distanceCovered meters (added $distanceFromLast)');

            // Update last recorded location
            lastRecordedLocation = LatLng(position.latitude, position.longitude);
          });
        }
      }

      // Always update current location and route
      setState(() {
        currentLocation = position;

        // Add point to route
        final newPoint = LatLng(position.latitude, position.longitude);
        routePoints.add(newPoint);

        // Update polyline with all points
        routePolyline = Polyline(
          polylineId: const PolylineId('route'),
          color: Colors.orange,
          width: 5,
          points: List.from(routePoints),
        );
      });

      // Animate map to follow user
      mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
      );
    });
  }

  /// Stop the run.
  void endRun() {
    runTimer?.cancel();
    locationSubscription?.cancel();
    trackingSubscription?.cancel();
    isTracking = false;
    endLocation = currentLocation;
  }

  /// Calculate distance using the haversine formula.
  double _calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    // Use Geolocator's built-in distance calculation
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Auto-pause logic based on speed.
  void _handleAutoPauseLogic(double speed) {
    if (autoPaused) {
      if (speed > resumeThreshold) {
        setState(() {
          autoPaused = false;
          stillCounter = 0;
        });
        print('Run resumed at speed: $speed m/s');
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
    trackingSubscription?.cancel();
    super.dispose();
  }
}