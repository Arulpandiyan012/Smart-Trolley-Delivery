import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';

class LocationTrackingService {
  static final LocationTrackingService _instance = LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  
  LocationTrackingService._internal() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
    ));
  }

  /// Checks and requests location permissions.
  /// Returns the final permission state.
  Future<LocationPermission> handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the 
      // App to enable the location services.
      debugPrint('Location services are disabled.');
      return LocationPermission.unableToDetermine;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale 
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        debugPrint('Location permissions are denied');
        return permission;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately. 
      debugPrint('Location permissions are permanently denied, we cannot request permissions.');
      return permission;
    }

    // If we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    debugPrint('Location permissions granted: $permission');
    return permission;
  }

  Timer? _trackingTimer;
  late Dio _dio;
  
  // Cached location to avoid excessive polling
  Position? _lastPosition;
  DateTime? _lastLocationUpdate;

  Future<void> startTrip(String orderId) async {
    try {
      // Fetch position with lower accuracy to save power & reduce frame drops
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 3),
      ).timeout(
        const Duration(seconds: 4),
        onTimeout: () => Position(
          latitude: 0,
          longitude: 0,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        ),
      );
      
      // Send request in background to avoid blocking main thread
      _sendTripStartRequest(orderId, position);
      
      debugPrint("🏁 Trip Started for Order $orderId");
      
      // Also start the polling immediately
      startTracking(orderId);
    } catch (e) {
      debugPrint("⚠️ Trip Start Error: $e");
      // Fallback to regular tracking if start_trip fails
      startTracking(orderId);
    }
  }

  Future<void> startTracking(String orderId) async {
    
    // Check Permissions
    try {
      LocationPermission permission = await handleLocationPermission();
      
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return;
      }

      // Start pushing location every 15 seconds (increased from 10 to reduce battery drain)
      _trackingTimer?.cancel();
      _trackingTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
        _pushLocationInBackground(orderId);
      });

      // Do an immediate first push
      _pushLocationInBackground(orderId);
    } catch (e) {
      debugPrint('Error starting tracking: $e');
    }
  }

  void stopTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
    _lastPosition = null;
    _lastLocationUpdate = null;
    debugPrint("🛑 Location Tracking Stopped.");
  }

  // Send location update without blocking main thread
  Future<void> _pushLocationInBackground(String orderId) async {
    // Run in compute isolate to prevent frame drops
    try {
      // Quick check with cached location to avoid excessive querying
      final now = DateTime.now();
      if (_lastLocationUpdate != null && 
          now.difference(_lastLocationUpdate!).inSeconds < 10) {
        // Use cached position if recent
        if (_lastPosition != null) {
          _sendLocationUpdateRequest(orderId, _lastPosition!);
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 3),
      ).timeout(
        const Duration(seconds: 4),
        onTimeout: () => _lastPosition ?? Position(
          latitude: 0,
          longitude: 0,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        ),
      );
      
      _lastPosition = position;
      _lastLocationUpdate = DateTime.now();
      
      _sendLocationUpdateRequest(orderId, position);
    } catch (e) {
      debugPrint("⚠️ Location Error: $e");
    }
  }

  // Send trip start request without blocking UI
  void _sendTripStartRequest(String orderId, Position position) {
    Future.microtask(() async {
      try {
        await _dio.post(
          'https://ecom.thesmartedgetech.com/tracking-api.php',
          data: {
            'action': 'start_trip',
            'order_id': orderId.replaceAll('#', ''),
            'driver_id': '0',
            'latitude': position.latitude,
            'longitude': position.longitude,
          },
        );
      } catch (e) {
        debugPrint("⚠️ Start trip request failed: $e");
      }
    });
  }

  // Send location update without blocking UI
  void _sendLocationUpdateRequest(String orderId, Position position) {
    Future.microtask(() async {
      try {
        await _dio.post(
          'https://ecom.thesmartedgetech.com/tracking-api.php',
          data: {
            'action': 'update_location',
            'order_id': orderId.replaceAll('#', ''),
            'driver_id': '0',
            'latitude': position.latitude,
            'longitude': position.longitude,
          },
        );
        debugPrint("📍 Location Pushed: ${position.latitude}, ${position.longitude}");
      } catch (e) {
        debugPrint("⚠️ Location Push Error: $e");
      }
    });
  }
}
