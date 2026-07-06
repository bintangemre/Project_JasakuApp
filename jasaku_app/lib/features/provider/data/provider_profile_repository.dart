import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/network/api_client.dart';

class ProviderProfileRepository {
  final Dio _dio = ApiClient().dio;

  Future<Map<String, dynamic>> getFullProfile() async {
    final response = await _dio.get(ApiEndpoints.providerProfile);
    return Map<String, dynamic>.from(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> updateProfile({
    String? fullName,
    String? nickname,
    String? gender,
    String? birthDate,
    String? phone,
    String? address,
    String? domicile,
    String? profilePhotoPath,
    List<String>? portfolios,
    List<File>? newPortfolioFiles,
  }) async {
    final formDataMap = <String, dynamic>{};
    if (fullName != null) formDataMap['full_name'] = fullName;
    if (nickname != null) formDataMap['nickname'] = nickname;
    if (gender != null) formDataMap['gender'] = gender;
    if (birthDate != null) formDataMap['birth_date'] = birthDate;
    if (phone != null) formDataMap['phone'] = phone;
    if (address != null) formDataMap['address'] = address;
    if (domicile != null) formDataMap['domicile'] = domicile;
    if (portfolios != null) formDataMap['existing_portfolios'] = jsonEncode(portfolios);
    if (profilePhotoPath != null) {
      formDataMap['profile_photo'] = await MultipartFile.fromFile(
        profilePhotoPath,
        filename: profilePhotoPath.split('/').last,
      );
    }
    if (newPortfolioFiles != null && newPortfolioFiles.isNotEmpty) {
      formDataMap['portfolios'] = await Future.wait(
        newPortfolioFiles.map((f) => MultipartFile.fromFile(
          f.path,
          filename: f.path.split('/').last,
        )),
      );
    }

    if (formDataMap.isEmpty) return;

    final formData = FormData.fromMap(formDataMap);
    await _dio.patch(
      ApiEndpoints.providerUpdateProfile,
      data: formData,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
    );
  }
}
