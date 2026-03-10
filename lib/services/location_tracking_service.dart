import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import '../screens/login/auth_repository.dart';

class LocationTrackingService {
  static final LocationTrackingService _instance = LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  Timer? _trackingTimer;
  String? _currentOrderId;

  Future<void> startTracking(String orderId) async {
    _currentOrderId = orderId;
    
    // Check Permissions
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions are permanently denied, we cannot request permissions.');
      return;
    }

    // Start pushing location every 10 seconds
    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      _pushLocation(orderId);
    });

    // Do an immediate first push
    _pushLocation(orderId);
  }

  void stopTracking() {
    _trackingTimer?.cancel();
    _trackingTimer = null;
    _currentOrderId = null;
    debugPrint("🛑 Location Tracking Stopped.");
  }

  Future<void> _pushLocation(String orderId) async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      
      final dio = Dio();
      
      await dio.post(
        'https://ecom.thesmartedgetech.com/tracking-api.php',
        data: {
          'action': 'update_location',
          'order_id': orderId.replaceAll('#', ''), // ensure strict numeric if needed
          'driver_id': '0',
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        )
      );

      debugPrint("📍 Location Pushed for Order $orderId: ${position.latitude}, ${position.longitude}");
    } catch (e) {
      debugPrint("⚠️ Location Push Error: $e");
    }
  }
}
