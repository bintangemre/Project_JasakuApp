import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import 'provider_profile_completion_screen.dart';
import 'provider_verification_pending_screen.dart';

class ProviderLoginScreen extends ConsumerStatefulWidget {
  const ProviderLoginScreen({super.key});

  @override
  ConsumerState<ProviderLoginScreen> createState() =>
      _ProviderLoginScreenState();
}

class _ProviderLoginScreenState extends ConsumerState<ProviderLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _afterLogin() {
    final state = ref.read(authProvider);
    final status = state.verificationStatus;

    if (status == 'pending') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const ProviderVerificationPendingScreen(
              status: 'pending'),
        ),
      );
      return;
    }
    if (status == 'rejected') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const ProviderVerificationPendingScreen(
              status: 'rejected'),
        ),
      );
      return;
    }

    final onboarding = state.onboardingCompleted;
    if (onboarding == false) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => const ProviderProfileCompletionScreen()),
      );
    } else {
      Navigator.pushReplacementNamed(context, '/provider/shell');
    }
  }

  bool _handleVerificationError(String? error) {
    if (error == null) return false;
    if (error.contains('belum diverifikasi')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const ProviderVerificationPendingScreen(
              status: 'pending'),
        ),
      );
      return true;
    }
    return false;
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email dan password wajib diisi')),
      );
      return;
    }

    final success = await ref
        .read(authProvider.notifier)
        .login(email: email, password: password, expectedRole: 'provider');

    if (!mounted) return;

    if (success) {
      _afterLogin();
    } else if (!_handleVerificationError(
        ref.read(authProvider).error)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(authProvider).error ?? 'Login gagal'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.handyman_rounded,
                      size: 40, color: Color(0xFF0F766E)),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Jasaku Mitra',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F766E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Masuk untuk mengelola layananmu',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Email',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Masukkan email',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF0F766E), width: 1.5),
                          ),
                          prefixIcon: const Icon(Icons.email_outlined,
                              color: Color(0xFF9CA3AF)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text('Password',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF374151))),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          hintText: 'Masukkan password',
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF0F766E), width: 1.5),
                          ),
                          prefixIcon: const Icon(Icons.lock_outline,
                              color: Color(0xFF9CA3AF)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: const Color(0xFF9CA3AF),
                            ),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                      if (authState.error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 16, color: Color(0xFFDC2626)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  authState.error!,
                                  style: const TextStyle(
                                      color: Color(0xFFDC2626),
                                      fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: authState.isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                const Color(0xFF0F766E).withValues(alpha: 0.5),
                            disabledForegroundColor:
                                Colors.white.withValues(alpha: 0.7),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: authState.isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2.5),
                                )
                              : const Text(
                                  'Masuk',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Belum punya akun? ',
                        style: TextStyle(color: Colors.grey.shade600)),
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, '/register'),
                      child: const Text(
                        'Daftar',
                        style: TextStyle(
                          color: Color(0xFF0F766E),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
