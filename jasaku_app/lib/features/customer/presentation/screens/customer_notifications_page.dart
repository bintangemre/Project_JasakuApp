import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';

class CustomerNotificationsPage extends ConsumerStatefulWidget {
  const CustomerNotificationsPage({super.key});

  @override
  ConsumerState<CustomerNotificationsPage> createState() => _CustomerNotificationsPageState();
}

class _CustomerNotificationsPageState extends ConsumerState<CustomerNotificationsPage> {
  final _dio = ApiClient().dio;
  List<Map<String, dynamic>> _pendingExtensions = [];
  bool _loading = true;
  String? _error;
  String? _processingExtId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final ordersRes = await _dio.get(ApiEndpoints.getCustomerOrders);
      final orders = (ordersRes.data?['data'] as List?) ?? [];

      final activeOrders = orders.where((o) {
        final status = o['status'] as String? ?? '';
        return !['completed', 'cancelled', 'rejected'].contains(status);
      }).toList();

      final List<Map<String, dynamic>> pendingExts = [];
      for (final order in activeOrders) {
        final orderId = order['id'] as String;
        try {
          final extRes = await _dio.get(ApiEndpoints.orderExtensions(orderId));
          final exts = (extRes.data?['data'] as List?) ?? [];
          for (final ext in exts) {
            if (ext['status'] == 'pending_customer') {
              pendingExts.add({
                ...Map<String, dynamic>.from(ext),
                'order': order,
              });
            }
          }
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _pendingExtensions = pendingExts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memuat notifikasi';
        _loading = false;
      });
    }
  }

  Future<void> _approve(String extId, num total) async {
    setState(() => _processingExtId = extId);
    try {
      await _dio.post(
        ApiEndpoints.respondExtension(extId),
        data: {'action': 'approved'},
      );
      if (!mounted) return;

      final accRes = await _dio.get(ApiEndpoints.paymentAccounts);
      final accounts = (accRes.data?['data'] as List?) ?? [];

      if (!mounted) return;
      _showPaymentAccountsDialog(accounts, total);

      await _loadData();
    } catch (e) {
      if (!mounted) return;
      final msg = e is DioException
          ? (e.response?.data?['message'] as String? ?? e.message)
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $msg')),
      );
    } finally {
      if (mounted) setState(() => _processingExtId = null);
    }
  }

  Future<void> _reject(String extId) async {
    setState(() => _processingExtId = extId);
    try {
      await _dio.post(
        ApiEndpoints.respondExtension(extId),
        data: {'action': 'rejected'},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ekstensi ditolak')),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      final msg = e is DioException
          ? (e.response?.data?['message'] as String? ?? e.message)
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $msg')),
      );
    } finally {
      if (mounted) setState(() => _processingExtId = null);
    }
  }

  void _showPaymentAccountsDialog(List<dynamic> accounts, num total) {
    showDialog(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.payment, size: 20, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(child: Text('Pilih Pembayaran', style: TextStyle(fontSize: 16))),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  Text('Total: ${_formatPrice(total)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 4),
                  const Text('Pilih metode pembayaran:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  ...accounts.map((a) {
                    final type = a['type'] as String? ?? '';
                    final name = a['bank_name'] ?? a['ewallet_name'] ?? a['provider_name'] ?? '-';
                    final icon = type == 'bank_transfer' ? Icons.account_balance : type == 'e_wallet' ? Icons.phone_android : Icons.qr_code;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.pop(dctx);
                            _showTransferDetails(a, total);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(icon, size: 24, color: AppColors.primary),
                                const SizedBox(width: 12),
                                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                const Spacer(),
                                Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade400),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dctx),
                child: const Text('Tutup'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTransferDetails(Map<String, dynamic> account, num total) {
    final type = account['type'] as String? ?? '';
    final name = account['bank_name'] ?? account['ewallet_name'] ?? account['provider_name'] ?? '-';
    final number = account['account_number'] as String? ?? '-';
    final holder = account['account_name'] as String? ?? '-';
    final numberFormatted = account['account_number_formatted'] as String? ?? number;
    final icon = type == 'bank_transfer' ? Icons.account_balance : type == 'e_wallet' ? Icons.phone_android : Icons.qr_code;

    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, size: 22, color: Color(0xFF059669)),
            SizedBox(width: 8),
            Expanded(child: Text('Ekstensi Disetujui!', style: TextStyle(fontSize: 16))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Silakan transfer ke rekening berikut:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
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
                      Icon(icon, size: 20, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(type, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 24),
                  _detailRow("Penyedia", name),
                  const SizedBox(height: 12),
                  _detailRow("Nomor Rekening", numberFormatted),
                  const SizedBox(height: 12),
                    _detailRow("Atas Nama", holder),
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
                      _formatPrice(total),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
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
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFFE67E22)),
                  SizedBox(width: 8),
                  Expanded(child: Text('Setelah transfer, admin akan melakukan konfirmasi. Silakan hubungi admin jika sudah transfer.', style: TextStyle(fontSize: 12, color: Color(0xFF9C6B3E)))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('Tutup'),
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

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static num _parseNum(dynamic value) {
    if (value is num) return value;
    return num.tryParse('$value') ?? 0;
  }

  String _formatPrice(num price) {
    return 'Rp ${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            TextButton(onPressed: _loadData, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }

    if (_pendingExtensions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('Tidak ada notifikasi', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Belum ada permintaan perpanjangan waktu', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingExtensions.length,
        itemBuilder: (context, index) {
          final ext = _pendingExtensions[index];
          final order = ext['order'] as Map<String, dynamic>;
          final providerName = (order['provider_profiles'] as Map<String, dynamic>?)?['full_name'] as String? ?? 'Mitra';
          final days = _parseInt(ext['extension_count']);
          final feeAplikasi = _parseNum(ext['additional_cost']);
          final totalPrice = _parseNum(order['total_price']);
          final platformFee = _parseNum(order['platform_fee']);
          final hargaProvider = (totalPrice - platformFee) * days;
          final total = hargaProvider + feeAplikasi;
          final extId = ext['id'] as String;
          final isProcessing = _processingExtId == extId;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.timer_outlined, size: 20, color: Color(0xFFD97706)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Permintaan Perpanjangan', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(providerName, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  _infoRow('Tambahan Hari', '$days hari'),
                  const Divider(height: 8),
                  Text('                  Rincian Biaya', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey.shade700)),
                  const SizedBox(height: 6),
                  _infoRow('Harga Provider ($days hari)', _formatPrice(hargaProvider)),
                  _infoRow('Fee Aplikasi', _formatPrice(feeAplikasi)),
                  const Divider(height: 8),
                  _infoRow('Total', _formatPrice(total), bold: true),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isProcessing ? null : () => _reject(extId),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isProcessing && _processingExtId == extId
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Tolak'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isProcessing ? null : () => _approve(extId, total),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: isProcessing && _processingExtId == extId
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Setujui & Bayar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
            color: bold ? Colors.black87 : Colors.grey.shade600,
          )),
          Text(value, style: TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
            color: bold ? AppColors.primary : Colors.black87,
          )),
        ],
      ),
    );
  }
}
