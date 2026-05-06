import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';
import '../../domain/models/user_model.dart';

// State class
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({UserModel? user, bool? isLoading, String? error}) {
    return AuthState(
      user:      user      ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error:     error,
    );
  }
}

// Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState());

  final _repo = AuthRepository();

  // ── REGISTER ──────────────────────────────────────────
  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _repo.register(
        email: email, password: password, name: name, role: role,
      );
      final user = UserModel.fromJson(result['data']['user']);
      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }

  // ── LOGIN ─────────────────────────────────────────────
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _repo.login(email: email, password: password);
      final user = UserModel.fromJson(result['data']['user']);
      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = AuthState(error: e.toString());
      return false;
    }
  }

  // ── LOGOUT ────────────────────────────────────────────
  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState();
  }
}