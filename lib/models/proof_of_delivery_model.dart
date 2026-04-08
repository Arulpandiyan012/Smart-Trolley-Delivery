class ProofOfDeliveryPhoto {
  final int? id;
  final int orderId;
  final String photoPath;
  final String timestamp;
  final double latitude;
  final double longitude;
  final String uploadStatus; // 'pending', 'uploading', 'completed', 'failed'
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? uploadedAt;

  ProofOfDeliveryPhoto({
    this.id,
    required this.orderId,
    required this.photoPath,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.uploadStatus = 'pending',
    this.errorMessage,
    required this.createdAt,
    this.uploadedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order_id': orderId,
      'photo_path': photoPath,
      'timestamp': timestamp,
      'latitude': latitude,
      'longitude': longitude,
      'upload_status': uploadStatus,
      'error_message': errorMessage,
      'created_at': createdAt.toIso8601String(),
      'uploaded_at': uploadedAt?.toIso8601String(),
    };
  }

  factory ProofOfDeliveryPhoto.fromMap(Map<String, dynamic> map) {
    return ProofOfDeliveryPhoto(
      id: map['id'],
      orderId: map['order_id'],
      photoPath: map['photo_path'],
      timestamp: map['timestamp'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      uploadStatus: map['upload_status'],
      errorMessage: map['error_message'],
      createdAt: DateTime.parse(map['created_at']),
      uploadedAt: map['uploaded_at'] != null ? DateTime.parse(map['uploaded_at']) : null,
    );
  }

  ProofOfDeliveryPhoto copyWith({
    int? id,
    int? orderId,
    String? photoPath,
    String? timestamp,
    double? latitude,
    double? longitude,
    String? uploadStatus,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? uploadedAt,
  }) {
    return ProofOfDeliveryPhoto(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      photoPath: photoPath ?? this.photoPath,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      uploadStatus: uploadStatus ?? this.uploadStatus,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
      uploadedAt: uploadedAt ?? this.uploadedAt,
    );
  }
}
