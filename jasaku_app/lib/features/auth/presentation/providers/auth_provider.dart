// StateNotifier Riverpod untuk mengelola login, register, dan role guard Jasaku App.
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/user_model.dart';
import '../../../services/auth_services.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final bool? onboardingCompleted;

  const AuthState(
      {this.user, this.isLoading = false, this.error, this.onboardingCompleted});

  AuthState copyWith(
      {UserModel? user, bool? isLoading, String? error, bool? onboardingCompleted}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
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
    String? profilePhotoPath, // 🟢 Tambahkan penampung path foto profil
    String? ktpPhotoPath, // 🟢 Tambahkan penampung path foto KTP
    String? selfiePhotoPath, // 🟢 Tambahkan penampung path foto selfie
    List<File>?
    portfolioFiles, // 🟢 Tambahkan penampung file portofolio opsional
    required List<Map<String, dynamic>>
    services, // 🟢 Wajib diisi (keahlian & tarif)
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.registerProvider(
        fullName: fullName,
        nickname: nickname,
        email: email,
        password: password,
        phone: phone,
        birthDate: birthDate,
        gender: gender,
        address: address,
        domicile: domicile,
        profilePhotoPath: profilePhotoPath, // 🟢 Oper ke repositori
        ktpPhotoPath: ktpPhotoPath, // 🟢 Oper ke repositori
        selfiePhotoPath: selfiePhotoPath, // 🟢 Oper ke repositori
        portfolioFiles: portfolioFiles, // 🟢 Oper ke repositori
        selectedServices: services,
      );
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
      if (expectedRole == 'provider' && !user.isProvider) {
        await _repo.logout();
        state = AuthState(
          error: 'Akun ini bukan provider untuk aplikasi Jasaku Mitra.',
        );
        return false;
      }
      final onboardingCompleted =
          result['data']?['profile']?['onboarding_completed'] as bool?;
      state = AuthState(user: user, onboardingCompleted: onboardingCompleted);
      return true;
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
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
        if (expectedRole == 'provider' && !user.isProvider) {
          state = AuthState(
            error: 'Akun ini bukan provider untuk aplikasi Jasaku Mitra.',
          );
          return false;
        }

        // Simpan token JWT internal dari backend ke local repository (jika ada handler-nya di repo)
      if (data['token'] != null) {
        // await _repo.saveToken(data['token']); // Aktifkan jika repo kamu memiliki fungsi ini
      }

      final onboardingCompleted =
          data['profile']?['onboarding_completed'] as bool?;
      state = AuthState(user: user, onboardingCompleted: onboardingCompleted);
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

  Future<bool> verifyOtp(String otp, String email, String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.verifyOtp(otp: otp, email: email, phone: phone);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }

  Future<bool> sendOtp(String email, String phone) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.sendOtp(email: email, phone: phone);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }
}
