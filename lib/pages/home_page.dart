// lib/pages/home_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/run_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    // Example: Check if user is already logged in
    // You might have a method to verify authentication status
    // For simplicity, assuming user data is already in Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<UserModel>(context, listen: false);
      if (user.id == 0) {
        // Navigate to Login Page if not logged in
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        // Stay on Home Page
        // Optionally, fetch additional user data if needed
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Existing Buttons
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/waiting_room');
              },
              child: const Text('Go to Waiting Room'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/challenges');
              },
              child: const Text('View Challenges'),
            ),

            const SizedBox(height: 32),
            // NEW: Start Run Button
            ElevatedButton(
              onPressed: () async {
                // 1) Insert a new row in user_contributions (start run).
                //    We'll do this via a function call in a new service or inline.
                final user = Provider.of<UserModel>(context, listen: false);
                final userId = user.id;

                // Optionally you might have a "teamChallengeId", or for now, let's pass 0 or something.
                final startContributionId = await startNewRunInDatabase(userId);

                if (startContributionId != null) {
                  // 2) Navigate to ActiveRunPage with that new userContributionId
                  Navigator.pushNamed(
                    context,
                    '/active_run',
                    arguments: startContributionId,
                  );
                } else {
                  // Handle error
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to start run.'))
                  );
                }
              },
              child: const Text('Start Run'),
            ),
          ],
        ),
      ),
    );
  }


}