import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_colors.dart';
import '../../domain/models/order_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/order_list_provider.dart';
import 'order_tracking_page.dart';
import 'review_bottom_sheet.dart';

class CustomerOrderListPage extends ConsumerStatefulWidget {
  const CustomerOrderListPage({super.key});

  @override
  ConsumerState<CustomerOrderListPage> createState() =>
      _CustomerOrderListPageState();
}

class _CustomerOrderListPageState extends ConsumerState<CustomerOrderListPage> {
  String _selectedFilter = 'semua';

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  void _fetchOrders() {
    Future.microtask(
        () => ref.read(customerOrderListProvider.notifier).fetchOrders());
  }

  Color _statusColor(String status) => AppColors.statusColor(status);

  bool _canCancel(String status) {
    return status == 'pending_payment' || status == 'pending' || status == 'accepted';
  }

  bool _canTrack(String status) {
    return ['on_the_way', 'arrived', 'in_progress'].contains(status);
  }

  Future<void> _cancelOrder(OrderModel order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Batalkan Pesanan'),
        content: Text(
            'Yakin ingin membatalkan pesanan dari ${order.providerName ?? "provider"}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Tidak')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ApiClient()
          .dio
          .post('${ApiEndpoints.cancelOrder}${order.id}/cancel');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesanan berhasil dibatalkan')),
      );
      ref.read(customerOrderListProvider.notifier).fetchOrders();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['message'] as String? ??
          'Gagal membatalkan pesanan';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _showDetail(OrderModel order) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: StatefulBuilder(
          builder: (ctx, setSheetState) {
            List<dynamic>? extensions;
            bool extLoading = false;
            bool _extFetched = false;
            String? extError;

            Future<void> _fetchExtensions() async {
              if (extensions != null) return;
              extLoading = true;
              setSheetState(() {});
              try {
                final res = await ApiClient().dio.get(
                  ApiEndpoints.orderExtensions(order.id),
                );
                extensions = (res.data?['data'] as List?) ?? [];
              } catch (e) {
                extError = 'Gagal memuat ekstensi';
              } finally {
                extLoading = false;
                if (ctx.mounted) setSheetState(() {});
              }
            }

            Future<List<dynamic>> _fetchPaymentAccounts() async {
              final res = await ApiClient().dio.get(
                ApiEndpoints.paymentAccounts,
              );
              return (res.data?['data'] as List?) ?? [];
            }

            Future<void> _showPaymentDialog() async {
              try {
                final accounts = await _fetchPaymentAccounts();
                if (!ctx.mounted) return;
                showDialog(
                  context: context,
                  builder: (dctx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Row(
                      children: [
                        Icon(Icons.payment, size: 20, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Pembayaran Ekstensi', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Transfer ke salah satu rekening berikut:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          const SizedBox(height: 12),
                          ...accounts.map((a) {
                            final type = a['type'] as String? ?? '';
                            final name = a['bank_name'] ?? a['ewallet_name'] ?? a['provider_name'] ?? '-';
                            final number = a['account_number'] as String? ?? '-';
                            final holder = a['account_name'] as String? ?? '-';
                            final icon = type == 'bank_transfer' ? Icons.account_balance : type == 'e_wallet' ? Icons.phone_android : Icons.qr_code;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(icon, size: 24, color: AppColors.primary),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        Text('$number\nA/N $holder', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Color(0xFFFDE68A)),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline, size: 16, color: Colors.amber),
                                SizedBox(width: 8),
                                Expanded(child: Text('Setelah transfer, admin akan melakukan konfirmasi. Silakan hubungi admin jika sudah transfer.', style: TextStyle(fontSize: 12, color: Color(0xFF92400E)))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dctx),
                        child: const Text('Tutup'),
                      ),
                    ],
                  ),
                );
              } catch (_) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gagal memuat informasi pembayaran')),
                );
              }
            }

            Future<void> _respondExtension(String extId, String action) async {
              extLoading = true;
              setSheetState(() {});
              try {
                await ApiClient().dio.post(
                  ApiEndpoints.respondExtension(extId),
                  data: {'action': action},
                );
                if (!ctx.mounted) return;
                extensions = null;
                await _fetchExtensions();
                if (action == 'approved') {
                  if (!ctx.mounted) return;
                  await _showPaymentDialog();
                } else {
                  if (!ctx.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ekstensi ditolak')),
                  );
                }
              } on DioException catch (e) {
                if (!ctx.mounted) return;
                final msg = e.response?.data?['message'] as String? ??
                    'Gagal merespon ekstensi';
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(msg)));
              } finally {
                extLoading = false;
                if (ctx.mounted) setSheetState(() {});
              }
            }

            if (!_extFetched) {
              _extFetched = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _fetchExtensions();
              });
            }

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _statusColor(order.status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.receipt_long,
                            color: _statusColor(order.status), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.providerName ?? 'Provider',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: _statusColor(order.status)
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                order.statusLabel,
                                style: TextStyle(
                                  color: _statusColor(order.status),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  _detailRow(Icons.calendar_today_rounded,
                      'Tanggal Kerja', order.formattedDate),
                  const SizedBox(height: 10),
                  _detailRow(Icons.description_outlined, 'Deskripsi',
                      order.description ?? '-'),
                  const SizedBox(height: 10),
                  _detailRow(Icons.monetization_on_outlined, 'Total Harga',
                      'Rp ${order.formattedPrice}'),
                  const SizedBox(height: 8),

                  // Extension section
                  if (extLoading && extensions == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                    ),
                  if (extError != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(extError!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                    ),
                  if (extensions != null)
                    ...extensions!.map((ext) {
                      final extStatus = ext['status'] as String? ?? '';
                      final extDays = ext['extension_count'] as int? ?? 0;
                      final extCost = ext['additional_cost'] as num? ?? 0;
                      final extId = ext['id'] as String? ?? '';

                      if (extStatus == 'pending_customer') {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.timer_outlined, size: 16, color: Colors.orange.shade700),
                                    const SizedBox(width: 6),
                                    Text('Permintaan Perpanjangan Waktu',
                                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.orange.shade800)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('$extDays hari — Rp ${extCost.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton(
                                      onPressed: extLoading ? null : () => _respondExtension(extId, 'rejected'),
                                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                                      child: const Text('Tolak', style: TextStyle(fontSize: 12)),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: extLoading ? null : () => _respondExtension(extId, 'approved'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                      ),
                                      child: const Text('Setujui & Bayar', style: TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (extStatus == 'pending_payment') {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.payment, size: 16, color: Colors.blue.shade700),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text('Perpanjangan $extDays hari — menunggu pembayaran',
                                        style: TextStyle(fontSize: 13, color: Colors.blue.shade800)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: extLoading ? null : _showPaymentDialog,
                                    icon: const Icon(Icons.visibility, size: 14),
                                    label: const Text('Lihat Petunjuk Pembayaran', style: TextStyle(fontSize: 12)),
                                    style: OutlinedButton.styleFrom(foregroundColor: Colors.blue.shade700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      if (extStatus == 'active') {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text('Perpanjangan $extDays hari aktif',
                                    style: TextStyle(fontSize: 13, color: Colors.green.shade800)),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return const SizedBox.shrink();
                    }),

                  const SizedBox(height: 8),
                  if (_canTrack(order.status))
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  OrderTrackingPage(orderId: order.id),
                            ),
                          );
                        },
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Lacak Provider'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (_canCancel(order.status))
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _cancelOrder(order);
                        },
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Batalkan Pesanan'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppColors.error.withValues(alpha: 0.1),
                          foregroundColor: AppColors.error,
                        ),
                      ),
                    ),
                  if (order.status == 'completed')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.vertical(top: Radius.circular(24)),
                            ),
                            builder: (_) => ReviewBottomSheet(
                              orderId: order.id,
                              providerId: order.providerId ?? '',
                              providerName: order.providerName ?? 'Provider',
                            ),
                          );
                        },
                        icon: const Icon(Icons.star_outline_rounded),
                        label: const Text('Beri Rating & Review'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.1),
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textHint),
        const SizedBox(width: 10),
        Text('$label: ',
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: AppColors.textPrimary)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.user?.id != next.user?.id && next.user != null) {
        Future.microtask(
            () => ref.read(customerOrderListProvider.notifier).fetchOrders());
      }
    });
    final state = ref.watch(customerOrderListProvider);

    final filteredOrders = _selectedFilter == 'semua'
        ? state.orders
        : state.orders
            .where((o) =>
                _selectedFilter == 'aktif'
                    ? !['completed', 'cancelled', 'rejected'].contains(o.status)
                    : o.status == _selectedFilter)
            .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pesanan Saya'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(
            child: _buildBody(state, filteredOrders),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'label': 'Semua', 'value': 'semua'},
      {'label': 'Aktif', 'value': 'aktif'},
      {'label': 'Selesai', 'value': 'completed'},
    ];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: filters.map((f) {
          final isSelected = _selectedFilter == f['value'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = f['value']!),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  f['label']!,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w400,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody(OrderListState state, List<OrderModel> orders) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 64, color: AppColors.textHint),
              const SizedBox(height: 16),
              const Text('Gagal memuat pesanan',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(state.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.read(customerOrderListProvider.notifier).fetchOrders(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined,
                  size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                _selectedFilter == 'aktif'
                    ? 'Tidak ada pesanan aktif'
                    : 'Belum ada pesanan',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pesan layanan pertama Anda sekarang!',
                style: TextStyle(color: AppColors.textHint),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(customerOrderListProvider.notifier).fetchOrders(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) => _buildOrderCard(orders[index]),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final statusColor = _statusColor(order.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetail(order),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.receipt_long,
                        color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.providerName ?? 'Provider',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.formattedDate,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        order.statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rp ${order.formattedPrice}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: Colors.grey.shade400),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
