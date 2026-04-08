import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:smart_trolley_delivery/models/proof_of_delivery_model.dart';

class ProofOfDeliveryOfflineService {
  static final ProofOfDeliveryOfflineService _instance =
      ProofOfDeliveryOfflineService._internal();
  static Database? _database;
  late Dio _dio;

  factory ProofOfDeliveryOfflineService() => _instance;

  ProofOfDeliveryOfflineService._internal() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
    ));
  }

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'proof_of_delivery.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS proof_of_delivery (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id INTEGER NOT NULL,
            photo_path TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            upload_status TEXT NOT NULL,
            error_message TEXT,
            created_at TEXT NOT NULL,
            uploaded_at TEXT
          )
        ''');
      },
    );
  }

  /// Save proof of delivery photo locally
  Future<int> saveProofLocally(ProofOfDeliveryPhoto proof) async {
    try {
      final db = await database;
      final id = await db.insert(
        'proof_of_delivery',
        proof.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('✅ Proof saved locally with ID: $id');
      return id;
    } catch (e) {
      debugPrint('❌ Error saving proof locally: $e');
      rethrow;
    }
  }

  /// Get pending proofs that need to be synced
  Future<List<ProofOfDeliveryPhoto>> getPendingProofs() async {
    try {
      final db = await database;
      final maps = await db.query(
        'proof_of_delivery',
        where: "upload_status = ? OR upload_status = ?",
        whereArgs: ['pending', 'failed'],
        orderBy: 'created_at ASC',
      );
      return List.generate(maps.length, (i) => ProofOfDeliveryPhoto.fromMap(maps[i]));
    } catch (e) {
      debugPrint('❌ Error getting pending proofs: $e');
      return [];
    }
  }

  /// Get proof by order ID
  Future<ProofOfDeliveryPhoto?> getProofByOrderId(int orderId) async {
    try {
      final db = await database;
      final maps = await db.query(
        'proof_of_delivery',
        where: 'order_id = ?',
        whereArgs: [orderId],
        limit: 1,
      );
      if (maps.isEmpty) return null;
      return ProofOfDeliveryPhoto.fromMap(maps.first);
    } catch (e) {
      debugPrint('❌ Error getting proof by order ID: $e');
      return null;
    }
  }

  /// Update proof status
  Future<void> updateProofStatus(
    int id,
    String status, {
    String? errorMessage,
    DateTime? uploadedAt,
  }) async {
    try {
      final db = await database;
      await db.update(
        'proof_of_delivery',
        {
          'upload_status': status,
          'error_message': errorMessage,
          if (uploadedAt != null) 'uploaded_at': uploadedAt.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint('✅ Proof status updated to: $status');
    } catch (e) {
      debugPrint('❌ Error updating proof status: $e');
      rethrow;
    }
  }

  /// Upload proof of delivery to server
  Future<bool> uploadProofToServer(
    ProofOfDeliveryPhoto proof, {
    required Function(int) onProgress,
    required String serverEndpoint,
  }) async {
    try {
      // Update status to uploading
      await updateProofStatus(proof.id!, 'uploading');

      // Create form data with photo file
      final formData = FormData.fromMap({
        'order_id': proof.orderId,
        'timestamp': proof.timestamp,
        'latitude': proof.latitude,
        'longitude': proof.longitude,
        'photo': await MultipartFile.fromFile(
          proof.photoPath,
          filename: 'proof_delivery_${proof.orderId}.png',
        ),
      });

      // Upload to server
      final response = await _dio.post(
        serverEndpoint,
        data: formData,
        onSendProgress: (int sent, int total) {
          final progress = (sent / total * 100).toInt();
          onProgress(progress);
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Update status to completed
        await updateProofStatus(
          proof.id!,
          'completed',
          uploadedAt: DateTime.now(),
        );
        debugPrint('✅ Proof uploaded successfully for order ${proof.orderId}');
        return true;
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMsg = 'Upload failed: ${e.message}';
      await updateProofStatus(proof.id!, 'failed', errorMessage: errorMsg);
      debugPrint('❌ $errorMsg');
      return false;
    } catch (e) {
      final errorMsg = 'Error uploading proof: $e';
      await updateProofStatus(proof.id!, 'failed', errorMessage: errorMsg);
      debugPrint('❌ $errorMsg');
      return false;
    }
  }

  /// Sync all pending proofs to server
  Future<void> syncPendingProofs({
    required String serverEndpoint,
    required Function(int, int) onProgress, // current, total
  }) async {
    try {
      final pendingProofs = await getPendingProofs();
      if (pendingProofs.isEmpty) {
        debugPrint('ℹ️ No pending proofs to sync');
        return;
      }

      debugPrint('🔄 Starting sync for ${pendingProofs.length} proofs...');

      for (int i = 0; i < pendingProofs.length; i++) {
        final proof = pendingProofs[i];
        onProgress(i + 1, pendingProofs.length);

        final success = await uploadProofToServer(
          proof,
          onProgress: (_) {},
          serverEndpoint: serverEndpoint,
        );

        if (!success) {
          debugPrint('⚠️ Failed to upload proof for order ${proof.orderId}');
        }
      }

      debugPrint('✅ Sync completed');
    } catch (e) {
      debugPrint('❌ Error syncing proofs: $e');
      rethrow;
    }
  }

  /// Delete proof record and file
  Future<void> deleteProof(int id) async {
    try {
      final db = await database;
      await db.delete(
        'proof_of_delivery',
        where: 'id = ?',
        whereArgs: [id],
      );
      debugPrint('✅ Proof deleted');
    } catch (e) {
      debugPrint('❌ Error deleting proof: $e');
      rethrow;
    }
  }

  /// Clear all completed proofs
  Future<void> clearCompletedProofs() async {
    try {
      final db = await database;
      final result = await db.delete(
        'proof_of_delivery',
        where: 'upload_status = ?',
        whereArgs: ['completed'],
      );
      debugPrint('✅ Cleared $result completed proofs');
    } catch (e) {
      debugPrint('❌ Error clearing proofs: $e');
      rethrow;
    }
  }

  /// Close database
  Future<void> closeDatabase() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}
