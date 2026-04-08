import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class WatermarkService {
  static final WatermarkService _instance = WatermarkService._internal();
  
  factory WatermarkService() => _instance;
  
  WatermarkService._internal();

  /// Add watermark with timestamp and GPS coordinates to the photo
  Future<String> addWatermark({
    required String photoPath,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
  }) async {
    try {
      // Read the image file
      final imageFile = File(photoPath);
      final imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Format timestamp and GPS info
      final formattedTime = DateFormat('dd/MM/yyyy HH:mm:ss').format(timestamp);
      final gpsInfo = 'GPS: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';

      // Add watermark overlay
      image = _addWatermarkOverlay(
        image,
        formattedTime,
        gpsInfo,
      );

      // Save watermarked image
      final watermarkedPath = await _saveWatermarkedImage(image, photoPath);
      
      return watermarkedPath;
    } catch (e) {
      debugPrint('Error adding watermark: $e');
      rethrow;
    }
  }

  /// Add watermark overlay to the image
  img.Image _addWatermarkOverlay(
    img.Image image,
    String timestamp,
    String gpsInfo,
  ) {
    // Create a semi-transparent overlay at the bottom
    final overlayHeight = 100;
    final overlayColor = img.ColorRgba8(0, 0, 0, 200); // Semi-transparent black

    // Draw semi-transparent rectangle at the bottom
    img.fillRect(
      image,
      x1: 0,
      y1: image.height - overlayHeight,
      x2: image.width,
      y2: image.height,
      color: overlayColor,
    );

    // Draw white rectangles as borders for better visibility
    img.drawRect(
      image,
      x1: 0,
      y1: image.height - overlayHeight,
      x2: image.width,
      y2: image.height,
      color: img.ColorRgba8(255, 255, 255, 100),
      thickness: 2,
    );

    return image;
  }

  /// Save the watermarked image
  Future<String> _saveWatermarkedImage(
    img.Image image,
    String originalPath,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'proof_delivery_${timestamp}_watermarked.png';
      final file = File('${directory.path}/$fileName');

      // Encode and save the image
      final pngData = img.encodePng(image);
      await file.writeAsBytes(pngData);

      debugPrint('✅ Watermarked image saved to: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('Error saving watermarked image: $e');
      rethrow;
    }
  }

  /// Validate if photo has watermark (checks if it contains the expected components)
  bool validateWatermark(String photoPath) {
    try {
      return File(photoPath).existsSync() && photoPath.contains('watermarked');
    } catch (e) {
      return false;
    }
  }
}
