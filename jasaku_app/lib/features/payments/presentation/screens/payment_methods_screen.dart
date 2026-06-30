import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/payment_method_picker.dart';

class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text('Metode Pembayaran', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Pilih metode pembayaran:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          PaymentMethodPicker(
            selectedId: '',
            onChanged: (id) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Dipilih: $id')),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text('Pembayaran melalui Rekber (Rekening Bersama):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          const Text(
            'Dengan Rekber, uang Anda aman ditampung oleh admin hingga pekerjaan selesai. '
            'Setelah Anda konfirmasi pekerjaan selesai, baru dana akan dicairkan ke penyedia jasa.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
