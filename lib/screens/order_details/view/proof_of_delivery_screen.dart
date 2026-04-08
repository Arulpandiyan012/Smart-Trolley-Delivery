import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smart_trolley_delivery/models/order_model.dart';
import 'package:smart_trolley_delivery/models/proof_of_delivery_model.dart';
import 'package:smart_trolley_delivery/services/watermark_service.dart';
import 'package:smart_trolley_delivery/services/proof_of_delivery_offline_service.dart';
import 'package:smart_trolley_delivery/screens/dashboard/bloc/dashboard_bloc.dart';
import 'package:smart_trolley_delivery/config/server_config.dart';

class ProofOfDeliveryScreen extends StatefulWidget {
  final OrderModel order;

  const ProofOfDeliveryScreen({Key? key, required this.order}) : super(key: key);

  @override
  State<ProofOfDeliveryScreen> createState() => _ProofOfDeliveryScreenState();
}

class _ProofOfDeliveryScreenState extends State<ProofOfDeliveryScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final WatermarkService _watermarkService = WatermarkService();
  final ProofOfDeliveryOfflineService _offlineService =
      ProofOfDeliveryOfflineService();

  String? _selectedPhotoPath;
  String? _watermarkedPhotoPath;
  Position? _currentPosition;
  bool _isCapturingPhoto = false;
  bool _isAddingWatermark = false;
  bool _isUploading = false;
  int _uploadProgress = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  /// Get current GPS location
  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () => Future.error('Location request timeout'),
      );

      setState(() {
        _currentPosition = position;
      });
      debugPrint('📍 Location obtained: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get location: $e';
      });
      debugPrint('❌ Location error: $e');
    }
  }

  /// Capture photo using camera
  Future<void> _capturePhoto() async {
    if (_currentPosition == null) {
      _showDialog('Location Required', 'Please wait for location to be captured');
      return;
    }

    try {
      setState(() {
        _isCapturingPhoto = true;
        _errorMessage = null;
      });

      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo != null) {
        setState(() {
          _selectedPhotoPath = photo.path;
        });
        debugPrint('📷 Photo captured: ${photo.path}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to capture photo: $e';
      });
      debugPrint('❌ Photo capture error: $e');
    } finally {
      setState(() {
        _isCapturingPhoto = false;
      });
    }
  }

  /// Pick photo from gallery
  Future<void> _pickPhotoFromGallery() async {
    if (_currentPosition == null) {
      _showDialog('Location Required', 'Please wait for location to be captured');
      return;
    }

    try {
      setState(() {
        _isCapturingPhoto = true;
        _errorMessage = null;
      });

      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );

      if (photo != null) {
        setState(() {
          _selectedPhotoPath = photo.path;
        });
        debugPrint('🖼️ Photo selected: ${photo.path}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick photo: $e';
      });
      debugPrint('❌ Photo pick error: $e');
    } finally {
      setState(() {
        _isCapturingPhoto = false;
      });
    }
  }

  /// Add watermark to the selected photo
  Future<void> _addWatermarkToPhoto() async {
    if (_selectedPhotoPath == null) {
      _showDialog('No Photo', 'Please capture or select a photo first');
      return;
    }

    if (_currentPosition == null) {
      _showDialog('Location Required', 'Location data is required for watermarking');
      return;
    }

    try {
      setState(() {
        _isAddingWatermark = true;
        _errorMessage = null;
      });

      final watermarkedPath = await _watermarkService.addWatermark(
        photoPath: _selectedPhotoPath!,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        timestamp: DateTime.now(),
      );

      setState(() {
        _watermarkedPhotoPath = watermarkedPath;
      });

      _showDialog('Success', 'Watermark added successfully');
      debugPrint('✨ Watermark added: $watermarkedPath');
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to add watermark: $e';
      });
      debugPrint('❌ Watermark error: $e');
    } finally {
      setState(() {
        _isAddingWatermark = false;
      });
    }
  }

  /// Upload proof to server (or save locally if offline)
  Future<void> _uploadProof() async {
    if (_watermarkedPhotoPath == null) {
      _showDialog('Photo Required', 'Please add watermark to the photo first');
      return;
    }

    if (_currentPosition == null) {
      _showDialog('Location Error', 'Location data is missing');
      return;
    }

    try {
      setState(() {
        _isUploading = true;
        _uploadProgress = 0;
        _errorMessage = null;
      });

      final proof = ProofOfDeliveryPhoto(
        orderId: widget.order.id,
        photoPath: _watermarkedPhotoPath!,
        timestamp:
            'Order: ${widget.order.orderNumber} - Delivered via App',
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        createdAt: DateTime.now(),
      );

      // Save to local database first
      final proofId = await _offlineService.saveProofLocally(proof);
      debugPrint('💾 Proof saved locally with ID: $proofId');

      // Try to upload to server
      final uploadedProof = proof.copyWith(id: proofId);
      final success = await _offlineService.uploadProofToServer(
        uploadedProof,
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
        serverEndpoint: ServerConfig.proofOfDeliveryUrl,
      );

      if (success) {
        // Update order status to delivered
        if (mounted) {
          context.read<DashboardBloc>().add(
            UpdateOrderStatusEvent(widget.order.id, 'delivered'),
          );
        }

        _showDialog(
          'Upload Successful',
          'Proof of delivery uploaded successfully and order marked as delivered',
        );
        debugPrint('✅ Proof uploaded successfully and order status updated');

        // Close screen after short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      } else {
        setState(() {
          _errorMessage =
              'Photo saved locally. Will sync when internet is available.';
        });
        
        // Show dialog with retry option
        _showDialogWithRetry(
          'Offline Mode',
          'Photo saved offline and will sync automatically when you are back online.\n\nTap "Retry" to try uploading again now.',
          onRetry: _uploadProof,
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
      });
      debugPrint('❌ Upload error: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  /// Show dialog
  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Clear selected photos
  void _clearPhotos() {
    setState(() {
      _selectedPhotoPath = null;
      _watermarkedPhotoPath = null;
      _uploadProgress = 0;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Proof of Delivery - Order ${widget.order.orderNumber}'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Location Status Card
            Card(
              color: _currentPosition != null ? Colors.green.shade50 : Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: _currentPosition != null ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GPS Location',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (_currentPosition != null)
                            Text(
                              '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(fontSize: 12),
                            )
                          else
                            const Text('Acquiring location...', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Photo Capture Section
            const Text(
              'Step 1: Capture Photo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_selectedPhotoPath != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_selectedPhotoPath!),
                      height: 250,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isCapturingPhoto ? null : _clearPhotos,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retake Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                  ),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isCapturingPhoto ? null : _capturePhoto,
                    icon: _isCapturingPhoto
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.camera_alt),
                    label: const Text('Take Photo'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _isCapturingPhoto ? null : _pickPhotoFromGallery,
                    icon: const Icon(Icons.image),
                    label: const Text('Choose from Gallery'),
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // Watermark Section
            if (_selectedPhotoPath != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Step 2: Add Watermark',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Watermark will include timestamp and GPS coordinates',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  if (_watermarkedPhotoPath != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(_watermarkedPhotoPath!),
                            height: 250,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            '✓ Watermark applied successfully',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _isAddingWatermark ? null : _addWatermarkToPhoto,
                      icon: _isAddingWatermark
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.edit),
                      label: const Text('Add Watermark'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),

            // Upload Section
            if (_watermarkedPhotoPath != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Step 3: Upload Proof',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  if (_isUploading)
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _uploadProgress / 100,
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Uploading... $_uploadProgress%',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _uploadProof,
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Upload & Complete Delivery'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                ],
              ),

            // Error Message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Info Card
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📋 Delivery Process',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow('1', 'GPS location will be recorded'),
                    _buildInfoRow('2', 'Photo will be watermarked with timestamp'),
                    _buildInfoRow('3', 'GPS coordinates will be embedded'),
                    _buildInfoRow('4', 'Photo will be uploaded to server'),
                    _buildInfoRow('5', 'If offline, syncs automatically when online'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showDialogWithRetry(
    String title,
    String message, {
    required VoidCallback onRetry,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onRetry();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
