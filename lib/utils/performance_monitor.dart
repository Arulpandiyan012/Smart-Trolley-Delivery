import 'package:flutter/foundation.dart';

/// Performance monitoring utility to track frame rates and memory usage
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  int _frameCount = 0;
  DateTime _lastFrameTime = DateTime.now();
  double _fps = 60.0;

  /// Call this every frame to track FPS
  void recordFrame() {
    _frameCount++;
    final now = DateTime.now();
    final elapsed = now.difference(_lastFrameTime).inMilliseconds;

    if (elapsed >= 1000) {
      _fps = (_frameCount / elapsed) * 1000;
      if (kDebugMode && _fps < 50) {
        debugPrint('⚠️ LOW FPS DETECTED: ${_fps.toStringAsFixed(1)}');
      }
      _frameCount = 0;
      _lastFrameTime = now;
    }
  }

  double get currentFps => _fps;

  /// Reset counters
  void reset() {
    _frameCount = 0;
    _lastFrameTime = DateTime.now();
    _fps = 60.0;
  }

  /// Print performance summary
  void printSummary() {
    debugPrint('=== PERFORMANCE SUMMARY ===');
    debugPrint('Current FPS: ${_fps.toStringAsFixed(1)}');
    debugPrint('==========================');
  }
}
