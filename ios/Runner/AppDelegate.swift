// In ios/Runner/AppDelegate.swift
import Flutter
import UIKit
import GoogleMaps  // Add this import

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Add this line to initialize Google Maps with your API key
    GMSServices.provideAPIKey("AIzaSyBffijFTKZIwz_Psp8FpXeXhyWj23G7VWo")
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}