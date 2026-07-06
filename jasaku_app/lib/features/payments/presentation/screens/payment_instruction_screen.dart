import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../widgets/payment_method_picker.dart';
import '../../domain/models/payment_method_model.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_endpoints.dart';

class PaymentInstructionScreen extends ConsumerStatefulWidget {
  final String orderId;
  final String paymentMethodId;
  final double totalAmount;

  const PaymentInstructionScreen({
    super.key,
    required this.orderId,
    required this.paymentMethodId,
    required this.totalAmount,
  });

  @override
  ConsumerState<PaymentInstructionScreen> createState() => _PaymentInstructionScreenState();
}

class _PaymentInstructionScreenState extends ConsumerState<PaymentInstructionScreen> {
  bool _isConfirmed = false;
  bool _isLoadingStatus = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    if (_isConfirmed || _isLoadingStatus) return;
    setState(() => _isLoadingStatus = true);
    try {
      final response = await ApiClient().dio.get(
        '${ApiEndpoints.getOrderDetails}${widget.orderId}',
      );
      final status = response.data['data']?['status'] as String?;
      if (status == 'pending' || status == 'accepted' || status == 'on_the_way') {
        _pollTimer?.cancel();
        if (mounted) setState(() => _isConfirmed = true);
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingStatus = false);
  }

  @override
  Widget build(BuildContext context) {
    final methodsAsync = ref.watch(paymentMethodsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Text(
          _isConfirmed ? "Pembayaran Dikonfirmasi" : "Instruksi Pembayaran",
          style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: methodsAsync.when(
        data: (methods) {
          final method = methods.where((m) => m.id == widget.paymentMethodId).firstOrNull;
          if (_isConfirmed) return _buildConfirmedContent();
          return _buildContent(method);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _isConfirmed ? _buildConfirmedContent() : _buildContent(null),
      ),
    );
  }

  Widget _buildConfirmedContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              color: Color(0xFFD1FAE5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle, color: Color(0xFF059669), size: 52),
          ),
          const SizedBox(height: 20),
          const Text(
            "Pembayaran Dikonfirmasi!",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
          ),
          const SizedBox(height: 10),
          Text(
            "Pesananmu sekarang aktif dan sudah dikirim ke Mitra. Silakan tunggu Mitra menerima pesananmu.",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              icon: const Icon(Icons.list_alt_rounded, color: Colors.white),
              label: const Text(
                "Lihat Pesanan Saya",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(PaymentMethod? method) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF059669), size: 72),
          const SizedBox(height: 16),
          const Text(
            "Pesanan Dibuat!",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Silakan transfer ke rekening berikut:",
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),

          if (method != null && method.accountNumber != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_iconData(method.icon), size: 20, color: const Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Text(
                        method.type,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _detailRow("Penyedia", method.providerName ?? '-'),
                  const SizedBox(height: 12),
                  _detailRow("Nomor Rekening", method.accountNumber ?? '-'),
                  const SizedBox(height: 12),
                  _detailRow("Atas Nama", method.accountName ?? '-'),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                "Metode pembayaran tidak tersedia.",
                style: TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          ],

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Total Transfer", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text(
                  "Rp ${NumberFormat('#,###', 'id_ID').format(widget.totalAmount)}",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFD6A8)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isLoadingStatus)
                  const SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE67E22)),
                  )
                else
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFFE67E22)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    "Pesanan akan diproses setelah admin mengkonfirmasi pembayaran. Halaman ini akan otomatis terupdate.",
                    style: TextStyle(fontSize: 12, color: Color(0xFF9C6B3E)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              child: const Text(
                "Kembali ke Beranda",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            textAlign: TextAlign.right,
          ),
        ),
      ],
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