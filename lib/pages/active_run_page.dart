import 'package:flutter/material.dart';
import 'dart:async';
import '../services/health_connect_service.dart';

class ActiveRunPage extends StatefulWidget {
  const ActiveRunPage({Key? key}) : super(key: key);

  @override
  State<ActiveRunPage> createState() => _ActiveRunPageState();
}

class _ActiveRunPageState extends State<ActiveRunPage> {
  final HealthConnectService _healthConnectService = HealthConnectService();

  /// Make the timer nullable to avoid LateInitializationError
  Timer? _timer;

  /// Keep track of run time, step counts, etc.
  DateTime _runStartTime = DateTime.now();
  int _elapsedSeconds = 0;
  int _initialStepCount = 0;
  int _currentStepCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeHealthConnect();
  }

  /// Check if Health Connect is available, then get initial steps, then start tracking.
  Future<void> _initializeHealthConnect() async {
    final isAvailable = await _healthConnectService.isHealthConnectAvailable();
    if (!isAvailable) {
      // Show user a message and exit this page
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Health Connect is unavailable.')),
      );
      Navigator.pop(context);
      return;
    }

    // Attempt to read the initial step count
    try {
      // Using a 1-hour buffer in case user has steps from the last hour
      _initialStepCount = await _healthConnectService.getStepCount(
        _runStartTime.subtract(const Duration(hours: 1)),
        _runStartTime,
      );
    } catch (e) {
      // If reading steps fails, show an error and return
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reading initial steps: $e')),
      );
      Navigator.pop(context);
      return;
    }

    // If all good, start our timer-based run tracking
    _startTracking();
  }

  /// Start a periodic timer that updates time + step count every second.
  void _startTracking() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      setState(() {
        _elapsedSeconds++;
      });

      // Fetch the current step count and subtract the initial
      try {
        final steps = await _healthConnectService.getStepCount(
          _runStartTime,
          DateTime.now(),
        );
        setState(() {
          _currentStepCount = steps - _initialStepCount;
        });
      } catch (e) {
        // Handle any errors quietly or show a message
        print('Error reading steps: $e');
      }
    });
  }

  /// Stop the timer if it exists.
  void _stopTracking() {
    _timer?.cancel();
  }

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Convert steps to distance (example: 1 step = 0.75 m)
    final distanceKm = _currentStepCount * 0.00075;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Run'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Time: $_elapsedSeconds s'),
            Text('Steps: $_currentStepCount'),
            Text('Distance: ${distanceKm.toStringAsFixed(2)} km'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _stopTracking();
                Navigator.pop(context);
              },
              child: const Text('End Run'),
            ),
          ],
        ),
      ),
    );
  }
}
