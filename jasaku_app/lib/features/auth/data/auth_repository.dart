// Repository otentikasi untuk register dan login dengan backend Jasaku App.
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/utils/storage.dart';

class AuthRepository {
  final Dio _dio = ApiClient().dio;

  Future<Map<String, dynamic>> registerCustomer({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? gender,
    String? birthDate,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.registerCustomer,
        data: {
          'email': email,
          'password': password,
          'name': name,
          'phone': phone,
          'gender': gender,
          'birthDate': birthDate,
        },
      );
      final data = response.data['data'] as Map<String, dynamic>?;
      final token = data?['token'] as String?;
      if (token != null) {
        await StorageService.saveToken(token);
      }
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> registerProvider({
    required String fullName,
    required String nickname,
    required String email,
    required String password,
    required String phone,
    required String birthDate,
    required String gender,
    required String address,
    required String domicile,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.registerProvider,
        data: {
          'full_name': fullName,
          'nickname': nickname,
          'email': email,
          'password': password,
          'phone': phone,
          'birthDate': birthDate,
          'gender': gender,
          'address': address,
          'domicile': domicile,
        },
      );
      final data = response.data['data'] as Map<String, dynamic>?;
      final token = data?['token'] as String?;
      if (token != null) {
        await StorageService.saveToken(token);
      }
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.login,
        data: {'email': email, 'password': password},
      );
      final data = response.data['data'] as Map<String, dynamic>?;
      final token = data?['token'] as String?;
      if (token != null) {
        await StorageService.saveToken(token);
      }
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    await StorageService.deleteToken();
  }

  String _handleError(DioException e) {
    if (e.response != null) {
      return e.response?.data['message'] as String? ?? 'Terjadi kesalahan';
    }
    return 'Tidak dapat terhubung ke server';
  }
}
