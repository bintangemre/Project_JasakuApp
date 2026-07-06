import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';

class ProviderDashboardRepository {
  final Dio _dio = ApiClient().dio;

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _dio.get(ApiEndpoints.providerProfile);
    return Map<String, dynamic>.from(response.data['data'] as Map<String, dynamic>);
  }

  Future<bool> toggleAvailability() async {
    final response = await _dio.post(ApiEndpoints.providerAvailability);
    final data = response.data['data'] as Map<String, dynamic>;
    return data['is_active'] as bool;
  }

  Future<bool> toggleTaskAvailability() async {
    final response = await _dio.post('${ApiEndpoints.providerProfile}/task-availability');
    final data = response.data['data'] as Map<String, dynamic>;
    return data['task_available'] as bool;
  }

  Future<List<Map<String, dynamic>>> getOrders() async {
    final response = await _dio.get(ApiEndpoints.getProviderOrders);
    final data = response.data['data'] as List<dynamic>?;
    return data
            ?.map((item) => Map<String, dynamic>.from(item as Map<String, dynamic>))
            .toList() ??
        [];
  }
}
