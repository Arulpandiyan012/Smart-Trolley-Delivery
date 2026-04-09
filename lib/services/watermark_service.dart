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

      // Optimization: Resize image if it's too large (e.g., from high-res camera)
      // This significantly speeds up processing and reduces memory consumption
      if (image.width > 1280 || image.height > 1280) {
        image = img.copyResize(
          image,
          width: image.width > image.height ? 1280 : null,
          height: image.height >= image.width ? 1280 : null,
          interpolation: img.Interpolation.linear,
        );
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

      // Save watermarked image (Switching to JPEG for faster encoding)
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
    // Scale overlay height relative to image height
    final overlayHeight = (image.height * 0.12).clamp(80.0, 150.0).toInt();
    final overlayColor = img.ColorRgba8(0, 0, 0, 160); // Semi-transparent black

    // Draw semi-transparent rectangle at the bottom
    img.fillRect(
      image,
      x1: 0,
      y1: image.height - overlayHeight,
      x2: image.width,
      y2: image.height,
      color: overlayColor,
    );

    // Add Text (Timestamp)
    img.drawString(
      image,
      timestamp,
      font: img.arial24,
      x: 20,
      y: image.height - overlayHeight + 15,
      color: img.ColorRgba8(255, 255, 255, 255),
    );

    // Add Text (GPS Info)
    img.drawString(
      image,
      gpsInfo,
      font: img.arial24,
      x: 20,
      y: image.height - overlayHeight + 45,
      color: img.ColorRgba8(255, 255, 255, 255),
    );

    // Draw border for the overlay
    img.drawRect(
      image,
      x1: 0,
      y1: image.height - overlayHeight,
      x2: image.width,
      y2: image.height,
      color: img.ColorRgba8(255, 255, 255, 80),
      thickness: 1,
    );

    return image;
  }

  /// Save the watermarked image
  Future<String> _saveWatermarkedImage(
    img.Image image,
    String originalPath,
  ) async {
    try {
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'pod_${timestamp}.jpg';
      final file = File('${directory.path}/$fileName');

      // Encode and save the image as JPEG (much faster than PNG)
      final jpegData = img.encodeJpg(image, quality: 85);
      await file.writeAsBytes(jpegData);

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
