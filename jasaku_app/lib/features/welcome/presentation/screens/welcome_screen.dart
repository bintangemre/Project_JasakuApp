import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/storage.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    if (!mounted) return;

    final hasToken = await StorageService.hasToken();
    if (!mounted) return;

    if (!hasToken) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final response = await ApiClient().dio.get('${ApiEndpoints.baseUrl}/api/auth/me');
      final meData = response.data['data'] as Map<String, dynamic>?;
      if (meData != null) {
        ref.read(authProvider.notifier).restoreSession(meData);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await StorageService.deleteToken();
        if (mounted) Navigator.pushReplacementNamed(context, '/login');
        return;
      }
    } catch (_) {}

    if (mounted) Navigator.pushReplacementNamed(context, '/customer/shell');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/Logo Aplikasi Jasa.png',
              width: 180,
              height: 180,
            ),
            const SizedBox(height: 24),
            const Text(
              'Jasaku',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Temukan Jasa Terpercaya',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
