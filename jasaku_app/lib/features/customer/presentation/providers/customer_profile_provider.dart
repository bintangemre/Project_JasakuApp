import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../domain/models/customer_profile_model.dart';

class CustomerProfileState {
  final bool isLoading;
  final bool isSaving;
  final CustomerProfileModel? data;
  final String? error;

  CustomerProfileState({this.isLoading = false, this.isSaving = false, this.data, this.error});
}

class CustomerProfileNotifier extends StateNotifier<CustomerProfileState> {
  final Dio _dio;
  CustomerProfileNotifier(this._dio) : super(CustomerProfileState());

  Future<void> fetchProfile() async {
    state = CustomerProfileState(isLoading: true);
    try {
      final res = await _dio.get(ApiEndpoints.customerProfile);
      final data = CustomerProfileModel.fromJson(res.data['data'] as Map<String, dynamic>);
      state = CustomerProfileState(data: data);
    } on DioException catch (e) {
      state = CustomerProfileState(error: e.response?.data?['message'] as String? ?? 'Gagal memuat profil');
    }
  }

  Future<String?> updateProfile({
    String? fullName,
    String? nickname,
    String? birthDate,
    String? gender,
    String? phone,
    String? address,
  }) async {
    state = CustomerProfileState(isSaving: true, data: state.data);
    try {
      final body = <String, dynamic>{};
      if (fullName != null) body['full_name'] = fullName;
      if (nickname != null) body['nickname'] = nickname;
      if (birthDate != null) body['birth_date'] = birthDate;
      if (gender != null) body['gender'] = gender;
      if (phone != null) body['phone'] = phone;
      if (address != null) body['address'] = address;

      await _dio.patch(ApiEndpoints.customerProfile, data: body);
      await fetchProfile();
      return null;
    } on DioException catch (e) {
      return e.response?.data?['message'] as String? ?? 'Gagal memperbarui profil';
    }
  }

  Future<String?> uploadAvatar(String filePath) async {
    state = CustomerProfileState(isSaving: true, data: state.data);
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(filePath),
      });
      final res = await _dio.patch(ApiEndpoints.customerProfile, data: formData);
      final updated = CustomerProfileModel.fromJson(res.data['data'] as Map<String, dynamic>);
      state = CustomerProfileState(data: updated);
      return null;
    } on DioException catch (e) {
      return e.response?.data?['message'] as String? ?? 'Gagal mengunggah foto';
    }
  }
}

final customerProfileProvider = StateNotifierProvider<CustomerProfileNotifier, CustomerProfileState>((ref) {
  return CustomerProfileNotifier(ApiClient().dio);
});
