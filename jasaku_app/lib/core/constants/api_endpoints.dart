// Defines backend API endpoint URLs for shared Jasaku App network calls.
class ApiEndpoints {
  static const String baseUrl = 'http://10.130.41.20:3000';
  static const String login = '$baseUrl/api/auth/login';
  static const String registerCustomer = '$baseUrl/api/auth/register/customer';
  static const String registerProvider = '$baseUrl/api/auth/register/provider';
  static const String logout = '$baseUrl/api/auth/logout';
  static const String services = '$baseUrl/api/services';
}
