import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../payments/presentation/screens/provider_payout_screen.dart';

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
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Email: ${user?.email ?? '-'}', style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 8),
                  Text('Role: ${user?.role ?? '-'}', style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE0E7FF),
                child: Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF2563EB)),
              ),
              title: const Text('Metode Penerimaan', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Atur rekening bank / e-wallet untuk payout'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProviderPayoutScreen()),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
