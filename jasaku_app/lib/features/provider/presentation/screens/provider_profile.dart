// Placeholder screen profil provider dengan informasi akun sederhana.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProviderProfile extends ConsumerWidget {
  const ProviderProfile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Profil Provider',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text('Email: ${user?.email ?? '-'}'),
          const SizedBox(height: 8),
          Text('Role: ${user?.role ?? '-'}'),
          const SizedBox(height: 24),
          const Text('Konten profil provider akan ditambahkan nanti.'),
        ],
      ),
    );
  }
}
