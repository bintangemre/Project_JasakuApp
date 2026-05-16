// StateNotifier Riverpod untuk mengelola login, register, dan role guard Jasaku App.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/user_model.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  AuthState copyWith({UserModel? user, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
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
      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState();
  }
}
