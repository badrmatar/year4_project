import 'package:flutter/material.dart';
import 'package:flutter_uxcam/flutter_uxcam.dart';

/// A custom [RouteObserver] that tracks route changes and sends
/// screen names to UXCam for better session recording.
class AnalyticsRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  /// Called when a new route has been pushed.
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _sendScreenView(route);
  }

  /// Called when a route is replaced.
  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _sendScreenView(newRoute);
    }
  }

  /// Called when a route is popped off the navigator.
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    // When a route is popped, the previous route is visible again.
    if (previousRoute != null) {
      _sendScreenView(previousRoute);
    }
  }

  /// Sends the screen name to UXCam.
  void _sendScreenView(Route<dynamic> route) {
    if (route is PageRoute) {
      // Determine a screen name based on the route's settings.
      final screenName = route.settings.name ?? route.runtimeType.toString();
      // Tag the screen in UXCam.
      FlutterUxcam.tagScreenName(screenName);
    }
  }
}
