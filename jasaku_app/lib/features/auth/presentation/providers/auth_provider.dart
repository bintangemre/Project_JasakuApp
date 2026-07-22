// StateNotifier Riverpod untuk mengelola login, register, dan role guard Jasaku App.
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/user_model.dart';
import '../../../services/auth_services.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/storage.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final bool? onboardingCompleted;
  final String? verificationStatus;
  final String? verificationNotes;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.onboardingCompleted,
    this.verificationStatus,
    this.verificationNotes,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool? onboardingCompleted,
    String? verificationStatus,
    String? verificationNotes,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationNotes: verificationNotes ?? this.verificationNotes,
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());
  final _repo = AuthRepository();

  Future<bool> registerCustomer({
    required String email,
    required String password,
    required String name,
    String? phone,
    String? gender,
    String? birthDate,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.registerCustomer(
        email: email,
        password: password,
        name: name,
        phone: phone,
        gender: gender,
        birthDate: birthDate,
      );
      state = const AuthState();
      return true;
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }

  Future<bool> registerProvider({
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
    required List<Map<String, dynamic>> services,
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
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repo.registerProvider(
        fullName: fullName,
        nickname: nickname,
        email: email,
        password: password,
        phone: phone,
        birthDate: birthDate,
        gender: gender,
        address: address,
        domicile: domicile,
        province: province,
        city: city,
        district: district,
        village: village,
        profilePhotoPath: profilePhotoPath,
        ktpPhotoPath: ktpPhotoPath,
        selfiePhotoPath: selfiePhotoPath,
        portfolioFiles: portfolioFiles,
        ijazahPhotoPath: ijazahPhotoPath,
        certificates: certificates,
        selectedServices: services,
        ocrNik: ocrNik,
        ocrFullName: ocrFullName,
        ocrBirthPlace: ocrBirthPlace,
        ocrBirthDate: ocrBirthDate,
        ocrAddress: ocrAddress,
        ocrGender: ocrGender,
        ocrBloodType: ocrBloodType,
        ocrReligion: ocrReligion,
        livenessData: livenessData,
      );
      final data = result['data'] as Map<String, dynamic>?;
      final token = data?['token'] as String?;
      if (token != null) {
        await StorageService.saveToken(token);
        _reRegisterFcmToken();
      }
      state = const AuthState();
      return true;
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
    required String expectedRole,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repo.login(email: email, password: password);
      final userJson = Map<String, dynamic>.from(
        result['data']['user'] as Map<String, dynamic>,
      );

      // Ambil nama dari profile (full_name untuk customer dan provider)
      final profile = result['data']['profile'] as Map<String, dynamic>?;
      if (profile != null) {
        final fullName = (profile['full_name'] as String? ?? '').trim();
        if (fullName.isNotEmpty) {
          userJson['name'] = fullName;
        }
      }

      final user = UserModel.fromJson(userJson);
      if (expectedRole == 'customer' && !user.isCustomer) {
        await _repo.logout();
        state = AuthState(
          error: 'Akun ini bukan customer untuk aplikasi Jasaku.',
        );
        return false;
      }
      if (expectedRole == 'provider' && !user.isProvider && !user.isAdmin) {
        await _repo.logout();
        state = AuthState(
          error: 'Akun ini bukan provider untuk aplikasi Jasaku Mitra.',
        );
        return false;
      }
      final onboardingCompleted =
          result['data']?['profile']?['onboarding_completed'] as bool?;
      final verificationStatus =
          result['data']?['profile']?['verification_status'] as String?;
      final verificationNotes =
          result['data']?['profile']?['verification_notes'] as String?;
      state = AuthState(
        user: user,
        onboardingCompleted: onboardingCompleted,
        verificationStatus: verificationStatus,
        verificationNotes: verificationNotes,
      );
      _reRegisterFcmToken();
      return true;
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }

  void _reRegisterFcmToken() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      debugPrint('[FCM] Token obtained');
      if (fcmToken != null) {
        final dio = ApiClient().dio;
        final savedJwt = await StorageService.getToken();
        debugPrint('[FCM] JWT saved: ${savedJwt != null}');
        final resp = await dio.post(ApiEndpoints.registerDevice, data: {
          'fcmToken': fcmToken,
          'deviceType': Platform.isIOS ? 'ios' : 'android',
        });
        debugPrint('[FCM] Register device response: ${resp.statusCode}');
      } else {
        debugPrint('[FCM] FCM token is NULL');
      }
    } catch (e) {
      debugPrint('[FCM] Register device FAILED: $e');
    }
  }

  Future<bool> loginWithGoogle({required String expectedRole}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final authService = AuthService();
      final result = await authService.signInWithGoogle(
        expectedRole: expectedRole,
      );

      if (result == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Login Google dibatalkan atau gagal.',
        );
        return false;
      }

      if (result['success'] == true) {
        final data =
            result['data']; // Mengikuti standard wrapper response backend kamu
        if (data == null || data['user'] == null) {
          state = state.copyWith(
            isLoading: false,
            error: 'Respons login Google tidak valid.',
          );
          return false;
        }

        final userJson = Map<String, dynamic>.from(
          data['user'] as Map<String, dynamic>,
        );

        // Ambil nama dari profile jika ada agar konsisten dengan method login manual
        final profile = data['profile'] as Map<String, dynamic>?;
        if (profile != null) {
          final fullName = (profile['full_name'] as String? ?? '').trim();
          if (fullName.isNotEmpty) {
            userJson['name'] = fullName;
          }
        }

        // Jika role kosong atau tidak ada, set sesuai expectedRole
        if ((userJson['role'] as String? ?? '').isEmpty) {
          userJson['role'] = expectedRole;
        }

        final user = UserModel.fromJson(userJson);

        // Validasi Guard Role sesuai aplikasi yang dibuka
        if (expectedRole == 'customer' && !user.isCustomer) {
          state = AuthState(
            error: 'Akun ini bukan customer untuk aplikasi Jasaku.',
          );
          return false;
        }
        if (expectedRole == 'provider' && !user.isProvider && !user.isAdmin) {
          state = AuthState(
            error: 'Akun ini bukan provider untuk aplikasi Jasaku Mitra.',
          );
          return false;
        }

        // Simpan token JWT internal dari backend ke local repository (jika ada handler-nya di repo)
      if (data['token'] != null) {
        await StorageService.saveToken(data['token']);
      }

      final onboardingCompleted =
          data['profile']?['onboarding_completed'] as bool?;
      state = AuthState(user: user, onboardingCompleted: onboardingCompleted);
      _reRegisterFcmToken();
      return true;
      } else {
        state = AuthState(error: result['message'] ?? 'Login Google Gagal');
        return false;
      }
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState();
  }

  void restoreSession(Map<String, dynamic> meData) {
    final userJson = <String, dynamic>{
      'id': meData['id']?.toString() ?? '',
      'email': meData['email']?.toString() ?? '',
      'role': meData['role']?.toString() ?? '',
      'name': meData['name']?.toString() ?? '',
    };

    String? verificationStatus;
    String? verificationNotes;
    bool? onboardingCompleted;

    final providerProfile = meData['provider_profiles'] as Map<String, dynamic>?;
    final customerProfile = meData['profiles_customer'] as Map<String, dynamic>?;

    if (providerProfile != null) {
      final fullName = (providerProfile['full_name'] as String? ?? '').trim();
      if (fullName.isNotEmpty) userJson['name'] = fullName;
      verificationStatus = providerProfile['verification_status'] as String?;
      verificationNotes = providerProfile['verification_notes'] as String?;
      onboardingCompleted = providerProfile['onboarding_completed'] as bool?;
    }
    if (customerProfile != null) {
      final fullName = (customerProfile['full_name'] as String? ?? '').trim();
      if (fullName.isNotEmpty) userJson['name'] = fullName;
    }

    final user = UserModel.fromJson(userJson);
    state = AuthState(
      user: user,
      verificationStatus: verificationStatus,
      verificationNotes: verificationNotes,
      onboardingCompleted: onboardingCompleted,
    );
  }

  Future<bool> resubmitVerification() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.resubmitVerification();
      state = state.copyWith(
        isLoading: false,
        verificationStatus: 'pending',
        verificationNotes: null,
      );
      return true;
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }
}
