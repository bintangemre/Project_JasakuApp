// Repository otentikasi untuk register dan login dengan backend Jasaku App.
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/utils/storage.dart';
import 'dart:convert'; // 🟢 WAJIB untuk fungsi jsonEncode
import 'dart:io'; // 🟢 WAJIB untuk tipe File pada portofolio provider

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
    String? profilePhotoPath,
    String? ktpPhotoPath,
    String? selfiePhotoPath,
    List<File>? portfolioFiles, // 🟢 Menyertakan file portofolio opsional
    required List<Map<String, dynamic>>
    selectedServices, // 🟢 Menyertakan array keahlian & tarif
  }) async {
    // 1. Inisialisasi Objek FormData untuk Multipart Request
    final Map<String, dynamic> formDataMap = {
      'full_name': fullName,
      'nickname': nickname,
      'email': email,
      'password': password,
      'phone': phone,
      'birthDate': birthDate,
      'gender': gender,
      'address': address,
      'domicile': domicile,

      // Mengirimkan array objek services dengan mengubahnya menjadi string JSON
      // agar bisa diterima sebagai teks oleh Express.js di dalam Multipart form
      'services': jsonEncode(selectedServices),
    };

    // 2. Bungkus file foto wajib jika jalurnya tersedia
    if (profilePhotoPath != null) {
      formDataMap['profile_photo'] = await MultipartFile.fromFile(
        profilePhotoPath,
        filename: profilePhotoPath.split('/').last,
      );
    }

    if (ktpPhotoPath != null) {
      formDataMap['ktp_photo'] = await MultipartFile.fromFile(
        ktpPhotoPath,
        filename: ktpPhotoPath.split('/').last,
      );
    }

    if (selfiePhotoPath != null) {
      formDataMap['selfie_photo'] = await MultipartFile.fromFile(
        selfiePhotoPath,
        filename: selfiePhotoPath.split('/').last,
      );
    }

    // 3. Bungkus array file portofolio opsional (jika ada)
    if (portfolioFiles != null && portfolioFiles.isNotEmpty) {
      final List<MultipartFile> portfolioMultipartList = [];
      for (var file in portfolioFiles) {
        portfolioMultipartList.add(
          await MultipartFile.fromFile(
            file.path,
            filename: file.path.split('/').last,
          ),
        );
      }
      formDataMap['portfolios'] =
          portfolioMultipartList; // Dikirim sebagai array berkas
    }

    // 4. Konversi Map menjadi FormData resmi Dio
    final FormData formData = FormData.fromMap(formDataMap);

    // 5. Tembak ke API Endpoint Pendaftaran Bersatu
    final response = await _dio.post(
      ApiEndpoints.registerProvider,
      data: formData,
      options: Options(
        headers: {
          // Beri tahu backend bahwa request ini membawa file fisik
          'Content-Type': 'multipart/form-data',
        },
      ),
    );

    return response.data as Map<String, dynamic>;
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

  Future<Map<String, dynamic>> verifyOtp({
    required String otp,
    required String email,
    required String phone,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiEndpoints.baseUrl}/auth/verify-otp',
        data: {'otp': otp, 'email': email, 'phone': phone},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<Map<String, dynamic>> sendOtp({
    required String email,
    required String phone,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiEndpoints.baseUrl}/auth/send-otp',
        data: {'email': email, 'phone': phone},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response != null) {
      return e.response?.data['message'] as String? ?? 'Terjadi kesalahan';
    }
    return 'Tidak dapat terhubung ke server';
  }
}
