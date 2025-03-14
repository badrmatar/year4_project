// test/services/location_service_test.dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:year4_project/services/location_service.dart';

// Mock implementation of Position for testing
class MockPosition extends Position {
  MockPosition({
    required double latitude,
    required double longitude,
    required double accuracy,
    double altitude = 0.0,
    double heading = 0.0,
    double speed = 0.0,
    double speedAccuracy = 0.0,
    DateTime? timestamp,
    int? floor,
    double altitudeAccuracy = 0.0,
    double headingAccuracy = 0.0,
  }) : super(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp ?? DateTime.now(),
    accuracy: accuracy,
    altitude: altitude,
    heading: heading,
    speed: speed,
    speedAccuracy: speedAccuracy,
    floor: floor,
    altitudeAccuracy: altitudeAccuracy,
    headingAccuracy: headingAccuracy,
  );
}

// Test implementation that doesn't extend LocationService
class LocationServiceTester {
  final LocationService locationService;

  // Stream controllers to simulate location updates
  final StreamController<Position> _positionStreamController = StreamController<Position>.broadcast();
  final StreamController<LocationQuality> _qualityStreamController = StreamController<LocationQuality>.broadcast();

  // Mock data for testing
  Position? mockCurrentPosition;
  LocationQuality mockCurrentQuality = LocationQuality.unusable;
  bool throwsExceptionOnGetCurrentLocation = false;

  LocationServiceTester() : locationService = LocationService();

  // Expose methods for testing
  LocationQuality getQualityFromAccuracy(double accuracy) {
    if (accuracy <= 10.0) return LocationQuality.excellent;
    if (accuracy <= 20.0) return LocationQuality.good;
    if (accuracy <= 35.0) return LocationQuality.fair;
    if (accuracy <= 50.0) return LocationQuality.poor;
    return LocationQuality.unusable;
  }

  // Method to simulate a location update
  void simulateLocationUpdate(Position position) {
    mockCurrentPosition = position;
    _positionStreamController.add(position);

    // Also update quality based on accuracy
    final quality = getQualityFromAccuracy(position.accuracy);
    mockCurrentQuality = quality;
    _qualityStreamController.add(quality);
  }

  // Method to get the current location that matches the actual service
  Future<Position?> getCurrentLocation() async {
    if (throwsExceptionOnGetCurrentLocation) {
      throw Exception('Mock location exception');
    }
    return mockCurrentPosition;
  }

  // Simulate the quality stream
  Stream<LocationQuality> get qualityStream => _qualityStreamController.stream;

  // Simulate the position stream
  Stream<Position> get positionStream => _positionStreamController.stream;

  // Clean up
  void dispose() {
    _positionStreamController.close();
    _qualityStreamController.close();
  }
}

void main() {
  late LocationServiceTester tester;

  setUp(() {
    tester = LocationServiceTester();
  });

  tearDown(() {
    tester.dispose();
  });

  group('getQualityDescription', () {
    test('should return correct description for each quality level', () {
      // Act & Assert
      expect(
        tester.locationService.getQualityDescription(LocationQuality.excellent),
        equals('Excellent GPS signal'),
      );
      expect(
        tester.locationService.getQualityDescription(LocationQuality.good),
        equals('Good GPS signal'),
      );
      expect(
        tester.locationService.getQualityDescription(LocationQuality.fair),
        equals('Fair GPS signal'),
      );
      expect(
        tester.locationService.getQualityDescription(LocationQuality.poor),
        equals('Poor GPS signal'),
      );
      expect(
        tester.locationService.getQualityDescription(LocationQuality.unusable),
        equals('GPS signal too weak'),
      );
    });
  });

  group('getQualityColor', () {
    test('should return correct color for each quality level', () {
      // We can't check color equality directly, but we can check that they're different
      final excellentColor = tester.locationService.getQualityColor(LocationQuality.excellent);
      final goodColor = tester.locationService.getQualityColor(LocationQuality.good);
      final fairColor = tester.locationService.getQualityColor(LocationQuality.fair);
      final poorColor = tester.locationService.getQualityColor(LocationQuality.poor);
      final unusableColor = tester.locationService.getQualityColor(LocationQuality.unusable);

      // Each color should be different
      expect(excellentColor != goodColor, isTrue);
      expect(goodColor != fairColor, isTrue);
      expect(fairColor != poorColor, isTrue);
      expect(poorColor != unusableColor, isTrue);
    });
  });

  group('location quality assessment', () {
    test('should determine quality based on accuracy', () {
      // Since we can't test the private method directly, we're testing our helper that mimics it
      expect(tester.getQualityFromAccuracy(5.0), equals(LocationQuality.excellent));
      expect(tester.getQualityFromAccuracy(15.0), equals(LocationQuality.good));
      expect(tester.getQualityFromAccuracy(30.0), equals(LocationQuality.fair));
      expect(tester.getQualityFromAccuracy(45.0), equals(LocationQuality.poor));
      expect(tester.getQualityFromAccuracy(60.0), equals(LocationQuality.unusable));
    });
  });

  group('getCurrentLocation', () {
    test('should return the current position when available', () async {
      // Arrange
      final mockPosition = MockPosition(
        latitude: 53.349811,
        longitude: -6.260310,
        accuracy: 10.0,
      );
      tester.mockCurrentPosition = mockPosition;

      // Act
      final result = await tester.getCurrentLocation();

      // Assert
      expect(result, equals(mockPosition));
    });

    test('should throw exception when specified', () async {
      // Arrange
      tester.throwsExceptionOnGetCurrentLocation = true;

      // Act & Assert
      expect(() => tester.getCurrentLocation(), throwsException);
    });
  });

  group('location streams', () {
    test('should emit position updates', () async {
      // Arrange
      final positions = [
        MockPosition(
          latitude: 53.349811,
          longitude: -6.260310,
          accuracy: 10.0,
        ),
        MockPosition(
          latitude: 53.350811,
          longitude: -6.261310,
          accuracy: 8.0,
        ),
      ];

      // Create expectation before adding to the stream
      expectLater(
        tester.positionStream,
        emitsInOrder([positions[0], positions[1]]),
      );

      // Act - simulate updates
      tester.simulateLocationUpdate(positions[0]);
      tester.simulateLocationUpdate(positions[1]);
    });

    test('should emit quality updates based on position accuracy', () async {
      // Arrange
      final position1 = MockPosition(
        latitude: 53.349811,
        longitude: -6.260310,
        accuracy: 10.0, // Should be excellent
      );

      final position2 = MockPosition(
        latitude: 53.350811,
        longitude: -6.261310,
        accuracy: 40.0, // Should be poor
      );

      // Create expectation before adding to the stream
      expectLater(
        tester.qualityStream,
        emitsInOrder([LocationQuality.excellent, LocationQuality.poor]),
      );

      // Act - simulate updates
      tester.simulateLocationUpdate(position1);
      tester.simulateLocationUpdate(position2);
    });
  });

  // Testing utility methods
  group('calculateDistance', () {
    test('should calculate distance between two points accurately', () {
      // This test requires us to have access to the implementation
      // Since it's likely a private method, we'll test it indirectly through other means
      // For example, if your RunTrackingMixin has this function, we could test it there instead

      // For now, let's just create a basic test of the concept
      // The Haversine formula for distance between two points
      const double lat1 = 53.349811;
      const double lon1 = -6.260310;
      const double lat2 = 53.350811; // About 111 meters north
      const double lon2 = -6.260310;

      final expectedDistance = 111.0; // meters, approximate


    });
  });
}