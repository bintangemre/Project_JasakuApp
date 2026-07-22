import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';

class ProviderServicesRepository {
  final Dio _dio = ApiClient().dio;

  Future<List<Map<String, dynamic>>> getAvailableServices() async {
    final response = await _dio.get(ApiEndpoints.providerAvailableServices);
    final data = response.data['data'] as List<dynamic>?;
    return data
            ?.map(
              (item) => Map<String, dynamic>.from(item as Map<String, dynamic>),
            )
            .toList() ??
        [];
  }

  Future<List<Map<String, dynamic>>> getAvailablePricingUnits() async {
    final response = await _dio.get(ApiEndpoints.providerAvailablePricingUnits);
    final data = response.data['data'] as List<dynamic>?;
    return data
            ?.map(
              (item) => Map<String, dynamic>.from(item as Map<String, dynamic>),
            )
            .toList() ??
        [];
  }

  Future<List<Map<String, dynamic>>> getAvailableContractTypes() async {
    final response = await _dio.get(ApiEndpoints.providerAvailableContractTypes);
    final data = response.data['data'] as List<dynamic>?;
    return data
            ?.map(
              (item) => Map<String, dynamic>.from(item as Map<String, dynamic>),
            )
            .toList() ??
        [];
  }

  Future<void> updateProviderService({
    required String serviceId,
    required String description,
    required List<Map<String, dynamic>> prices,
  }) async {
    await _dio.put(
      ApiEndpoints.updateProviderService,
      data: {
        'serviceId': serviceId,
        'description': description,
        'prices': prices,
      },
    );
  }
}