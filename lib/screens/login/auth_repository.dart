import 'package:dio/dio.dart';
import 'package:smart_trolley_delivery/network/api_client.dart';
import 'package:smart_trolley_delivery/services/fcm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository {
  final ApiClient _apiClient = ApiClient();

  Future<bool> login(String email, String password) async {
    try {
        String? fcmToken = await FCMService.getToken();
        
        final response = await _apiClient.dio.post(
          '?action=login',
          data: {
            'email': email, 
            'password': password,
            'fcm_token': fcmToken ?? '',
          },
        );

      if (response.data != null && response.data['success'] == true) {
        // Save the token
        final String token = response.data['data']['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('delivery_token', token);
        return true;
      } else {
        throw Exception(response.data['message'] ?? 'Login Failed');
      }
    } catch (e) {
      if (e is DioException) {
        throw Exception('Network error: \${e.message}');
      }
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('delivery_token');
  }
}
