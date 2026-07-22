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
      final body = <String, dynamic>{
        'email': email,
        'password': password,
        'name': name,
      };
      if (phone != null) body['phone'] = phone;
      if (gender != null) body['gender'] = gender;
      if (birthDate != null) body['birthDate'] = birthDate;

      final response = await _dio.post(
        ApiEndpoints.registerCustomer,
        data: body,
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
  String? province,
  String? city,
  String? district,
  String? village,
  String? profilePhotoPath,
  String? ktpPhotoPath,
  String? selfiePhotoPath,
  List<File>? portfolioFiles,
  String? ijazahPhotoPath,
  List<Map<String, dynamic>>? certificates,
  required List<Map<String, dynamic>> selectedServices,
  String? ocrNik,
  String? ocrFullName,
  String? ocrBirthPlace,
  String? ocrBirthDate,
  String? ocrAddress,
  String? ocrGender,
  String? ocrBloodType,
  String? ocrReligion,
  Map<String, dynamic>? livenessData,
}) async {
  try {
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
      'services': jsonEncode(selectedServices),
    };

    if (province != null && province.isNotEmpty) formDataMap['province'] = province;
    if (city != null && city.isNotEmpty) formDataMap['city'] = city;
    if (district != null && district.isNotEmpty) formDataMap['district'] = district;
    if (village != null && village.isNotEmpty) formDataMap['village'] = village;

    if (ocrNik != null) formDataMap['ocr_nik'] = ocrNik;
    if (ocrFullName != null) formDataMap['ocr_full_name'] = ocrFullName;
    if (ocrBirthPlace != null) formDataMap['ocr_birth_place'] = ocrBirthPlace;
    if (ocrBirthDate != null) formDataMap['ocr_birth_date'] = ocrBirthDate;
    if (ocrAddress != null) formDataMap['ocr_address'] = ocrAddress;
    if (ocrGender != null) formDataMap['ocr_gender'] = ocrGender;
    if (ocrBloodType != null) formDataMap['ocr_blood_type'] = ocrBloodType;
    if (ocrReligion != null) formDataMap['ocr_religion'] = ocrReligion;
    if (livenessData != null) formDataMap['liveness_data'] = jsonEncode(livenessData);

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

    if (portfolioFiles != null && portfolioFiles.isNotEmpty) {
      final List<MultipartFile> portfolioMultipartList = [];
      for (var file in portfolioFiles) {
        portfolioMultipartList.add(
          await MultipartFile.fromFile(
            file.path,
            filename: file.path.split(RegExp(r'[/\\]')).last,
          ),
        );
      }
      formDataMap['portfolios'] = portfolioMultipartList;
    }

    // Ijazah
    if (ijazahPhotoPath != null) {
      formDataMap['ijazah_photo'] = await MultipartFile.fromFile(
        ijazahPhotoPath,
        filename: ijazahPhotoPath.split('/').last,
      );
    }

    // Sertifikat — kirim file sebagai list
    if (certificates != null && certificates.isNotEmpty) {
      final List<MultipartFile> certificateFiles = [];
      for (var cert in certificates) {
        final path = cert['filePath'] as String?;
        if (path != null) {
          certificateFiles.add(
            await MultipartFile.fromFile(
              path,
              filename: path.split(RegExp(r'[/\\]')).last,
            ),
          );
        }
      }
      if (certificateFiles.isNotEmpty) {
        formDataMap['certificate_files'] = certificateFiles;
      }
    }

    final FormData formData = FormData.fromMap(formDataMap);

    final response = await _dio.post(
      ApiEndpoints.registerProvider,
      data: formData,
      options: Options(
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      ),
    );

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
      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw 'Respons server tidak valid. Silakan coba lagi.';
      }
      final data = body['data'] as Map<String, dynamic>?;
      final token = data?['token'] as String?;
      if (token != null) {
        await StorageService.saveToken(token);
      }
      return body;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> logout() async {
    await StorageService.deleteToken();
  }

  Future<void> resubmitVerification() async {
    try {
      await _dio.post(ApiEndpoints.resubmitVerification);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response != null) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return data['message'] as String? ?? 'Terjadi kesalahan';
      }
      return 'Terjadi kesalahan dari server';
    }
    return 'Tidak dapat terhubung ke server';
  }
}
