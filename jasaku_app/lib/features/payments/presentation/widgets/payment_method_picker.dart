import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/payment_repository.dart';
import '../../domain/models/payment_method_model.dart';

final paymentMethodsProvider = FutureProvider.autoDispose<List<PaymentMethod>>((ref) {
  return PaymentRepository().getPaymentMethods();
});

class PaymentMethodPicker extends ConsumerWidget {
  final String selectedId;
  final ValueChanged<String> onChanged;

  const PaymentMethodPicker({
    super.key,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methodsAsync = ref.watch(paymentMethodsProvider);

    return methodsAsync.when(
      data: (methods) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: methods.map((m) {
            final selected = selectedId == m.id;
            return InkWell(
              onTap: () => onChanged(m.id),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(_iconData(m.icon), size: 22, color: selected ? const Color(0xFF2563EB) : Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.type, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: selected ? const Color(0xFF2563EB) : Colors.black87)),
                          Text(m.description, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? const Color(0xFF2563EB) : Colors.grey, size: 20),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(strokeWidth: 2),
      )),
      error: (err, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Gagal memuat metode pembayaran', style: TextStyle(color: Colors.red.shade400, fontSize: 13)),
      ),
    );
  }

  IconData _iconData(String icon) {
    switch (icon) {
      case 'account_balance': return Icons.account_balance;
      case 'qr_code': return Icons.qr_code;
      case 'wallet': return Icons.wallet;
      default: return Icons.account_balance;
    }
  }
}
