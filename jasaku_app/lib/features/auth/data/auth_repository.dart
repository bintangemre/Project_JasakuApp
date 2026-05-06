import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/utils/storage.dart';
import '../domain/models/user_model.dart';

class AuthRepository {
  final Dio _dio = ApiClient().dio;

  // ── REGISTER ──────────────────────────────────────────
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
    required String role, // 'customer' atau 'jasa'
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.register,
        data: {
          'email':    email,
          'password': password,
          'name':     name,
          'role':     role,
        },
      );

      final token = response.data['data']['token'];
      await StorageService.saveToken(token);

      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── LOGIN ─────────────────────────────────────────────
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.login,
        data: {
          'email':    email,
          'password': password,
        },
      );

      final token = response.data['data']['token'];
      await StorageService.saveToken(token);

      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  // ── LOGOUT ────────────────────────────────────────────
  Future<void> logout() async {
    await StorageService.deleteToken();
  }

  // ── ERROR HANDLER ─────────────────────────────────────
  String _handleError(DioException e) {
    if (e.response != null) {
      // Error dari backend (misal: "email sudah terdaftar")
      return e.response?.data['message'] ?? 'Terjadi kesalahan';
    } else {
      // Error jaringan
      return 'Tidak dapat terhubung ke server';
    }
  }
}