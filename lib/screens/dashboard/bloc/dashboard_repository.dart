import 'package:dio/dio.dart';
import 'package:smart_trolley_delivery/models/order_model.dart';
import 'package:smart_trolley_delivery/network/api_client.dart';

class DashboardRepository {
  final ApiClient _apiClient = ApiClient();

  Future<DashboardResponse> getOrders() async {
    try {
      final response = await _apiClient.dio.get('?action=get_orders');

      if (response.data != null && response.data['success'] == true) {
        return DashboardResponse.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? 'Failed to load orders');
      }
    } catch (e) {
      if (e is DioException) {
        throw Exception('Network error: \${e.message}');
      }
      throw Exception('An error occurred: $e');
    }
  }

  Future<List<OrderModel>> getAvailableOrders() async {
    try {
      final response = await _apiClient.dio.get('?action=get_available_orders');

      if (response.data != null && response.data['success'] == true) {
        var list = response.data['data'] as List? ?? [];
        return list.map((e) => OrderModel.fromJson(e)).toList();
      } else {
        throw Exception(response.data['message'] ?? 'Failed to load available orders');
      }
    } catch (e) {
      if (e is DioException) {
        throw Exception('Network error: ${e.message}');
      }
      throw Exception('An error occurred: $e');
    }
  }

  Future<bool> acceptOrder(int orderId) async {
    try {
      final response = await _apiClient.dio.post(
        '?action=accept_order',
        data: {'order_id': orderId},
      );

      if (response.data != null && response.data['success'] == true) {
        return true;
      } else {
        throw Exception(response.data['message'] ?? 'Failed to accept order');
      }
    } catch (e) {
      if (e is DioException) {
        throw Exception('Network error: ${e.message}');
      }
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<bool> updateOrderStatus(int orderId, String status) async {
    try {
      final response = await _apiClient.dio.post(
        '?action=update_status',
        data: {'order_id': orderId, 'status': status},
      );

      return response.data != null && response.data['success'] == true;
    } catch (e) {
      throw Exception('Failed to update status');
    }
  }
}
