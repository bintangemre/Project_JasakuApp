import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';

class ProviderServicesRepository {
  final Dio _dio = ApiClient().dio;

  // 🌍 Tetap dipertahankan untuk memuat daftar keahlian master di Step 2
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

  // 🌍 Tetap dipertahankan untuk memuat jenis-jenis tipe harga master di Step 2
  Future<List<Map<String, dynamic>>> getAvailablePricingTypes() async {
    final response = await _dio.get(ApiEndpoints.providerAvailablePricingTypes);
    final data = response.data['data'] as List<dynamic>?;
    return data
            ?.map(
              (item) => Map<String, dynamic>.from(item as Map<String, dynamic>),
            )
            .toList() ??
        [];
  }

  // ❌ Fungsi addProviderService lama telah dihapus dari sini 
  // karena pengirimannya sudah bersatu ke dalam Auth_Repository via Multipart Form Data.
}