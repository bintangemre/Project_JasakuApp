import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../domain/models/payment_method_model.dart';

class PaymentRepository {
  final Dio _dio;
  PaymentRepository() : _dio = ApiClient().dio;

  Future<List<PaymentMethod>> getPaymentMethods() async {
    final response = await _dio.get(ApiEndpoints.paymentMethods);
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data.map((json) => PaymentMethod.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<List<PayoutMethod>> getMyPayoutMethods() async {
    final response = await _dio.get('${ApiEndpoints.baseUrl}/api/provider/payout-methods');
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data.map((json) => PayoutMethod.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<void> createPayoutMethod(PayoutMethod method) async {
    await _dio.post('${ApiEndpoints.baseUrl}/api/provider/payout-methods', data: method.toJson());
  }

  Future<void> updatePayoutMethod(String id, PayoutMethod method) async {
    await _dio.put('${ApiEndpoints.baseUrl}/api/provider/payout-methods/$id', data: method.toJson());
  }

  Future<void> deletePayoutMethod(String id) async {
    await _dio.delete('${ApiEndpoints.baseUrl}/api/provider/payout-methods/$id');
  }
}
