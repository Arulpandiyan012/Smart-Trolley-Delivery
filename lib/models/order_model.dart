class OrderModel {
  final int id;
  final String orderNumber;
  final String status;
  final String total;
  final String date;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String items;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.total,
    required this.date,
    required this.customerName,
    required this.customerPhone,
    required this.customerAddress,
    required this.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      orderNumber: json['order_number'] ?? '',
      status: json['status'] ?? '',
      total: json['total'] ?? '',
      date: json['date'] ?? '',
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? 'N/A',
      customerAddress: json['customer_address'] ?? 'Address not found',
      items: json['items'] ?? '',
    );
  }
}

class DashboardResponse {
  final List<OrderModel> activeOrders;
  final List<OrderModel> historyOrders;

  DashboardResponse({required this.activeOrders, required this.historyOrders});

  factory DashboardResponse.fromJson(Map<String, dynamic> json) {
    var activeList = json['active'] as List? ?? [];
    var historyList = json['history'] as List? ?? [];

    return DashboardResponse(
      activeOrders: activeList.map((e) => OrderModel.fromJson(e)).toList(),
      historyOrders: historyList.map((e) => OrderModel.fromJson(e)).toList(),
    );
  }
}
