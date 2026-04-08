/// Server Configuration
/// Update this with your actual backend URL
class ServerConfig {
  /// Base API URL for your backend server
  /// IMPORTANT: Update this with your actual server domain!
  /// Examples:
  ///   - Local: 'http://192.168.1.100:8000'
  ///   - Shared hosting: 'https://yourdomain.com'
  ///   - Production: 'https://api.yourdomain.com'
  static const String baseUrl = 'https://ecom.thesmartedgetech.com';

  /// Delivery API endpoint
  /// Full URL: baseUrl + '/delivery-api.php'
  static const String deliveryApiPath = '/delivery-api.php';

  /// Proof of delivery endpoint
  static String get proofOfDeliveryUrl =>
      '$baseUrl$deliveryApiPath?action=proof_of_delivery';

  /// Check server health endpoint (for testing)
  static String get healthCheckUrl =>
      '$baseUrl$deliveryApiPath?action=get_info';

  /// Other API endpoints
  static String get loginUrl => '$baseUrl$deliveryApiPath?action=login';
  static String get getOrdersUrl => '$baseUrl$deliveryApiPath?action=get_orders';
  static String get updateStatusUrl =>
      '$baseUrl$deliveryApiPath?action=update_status';
  static String get getProfileUrl =>
      '$baseUrl$deliveryApiPath?action=get_profile';
}
