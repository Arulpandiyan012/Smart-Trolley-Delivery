class DeliveryProfile {
  final int id;
  final String name;
  final String email;
  final String phone;
  final int totalDeliveries;
  final double avgRating;
  final double totalEarnings;

  DeliveryProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.totalDeliveries,
    required this.avgRating,
    required this.totalEarnings,
  });

  factory DeliveryProfile.fromJson(Map<String, dynamic> json) {
    return DeliveryProfile(
      id: int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? 'Partner',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      totalDeliveries: int.tryParse(json['total_deliveries'].toString()) ?? 0,
      avgRating: (json['avg_rating'] ?? 0.0).toDouble(),
      totalEarnings: (json['total_earnings'] ?? 0.0).toDouble(),
    );
  }
}
