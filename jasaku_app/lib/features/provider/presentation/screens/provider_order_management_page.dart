import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/operating_hours.dart';
import 'provider_order_detail_page.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/date_utils.dart';

class ProviderOrderManagementPage extends ConsumerStatefulWidget {
  const ProviderOrderManagementPage({super.key});

  @override
  ConsumerState<ProviderOrderManagementPage> createState() => _ProviderOrderManagementPageState();
}

class _ProviderOrderManagementPageState extends ConsumerState<ProviderOrderManagementPage> {
  List<Map<String, dynamic>> _todayOrders = [];
  List<Map<String, dynamic>> _upcomingOrders = [];
  List<Map<String, dynamic>> _historyOrders = [];
  bool _loading = true;

  final Dio _dio = ApiClient().dio;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _dio.get('${ApiEndpoints.getProviderOrders}?scope=today'),
        _dio.get('${ApiEndpoints.getProviderOrders}?scope=upcoming'),
        _dio.get('${ApiEndpoints.getProviderOrders}?scope=history'),
      ]);
      setState(() {
        _todayOrders = _parseList(results[0].data?['data']);
        _upcomingOrders = _parseList(results[1].data?['data']);
        _historyOrders = _parseList(results[2].data?['data']);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memuat: ${ApiClient.errorMessage(e)}')));
      }
    }
  }

  List<Map<String, dynamic>> _parseList(dynamic data) {
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'accepted': return Colors.blue;
      case 'on_the_way': return const Color(0xFF0288D1);
      case 'arrived': return Colors.indigo;
      case 'in_progress': return Colors.purple;
      case 'completed': return Colors.green;
      case 'rejected': return Colors.red;
      case 'cancelled': return Colors.grey;
      default: return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending': return 'Menunggu';
      case 'accepted': return 'Diterima';
      case 'on_the_way': return 'Dalam Perjalanan';
      case 'arrived': return 'Tiba di Lokasi';
      case 'in_progress': return 'Sedang Bekerja';
      case 'completed': return 'Selesai';
      case 'rejected': return 'Ditolak';
      case 'cancelled': return 'Dibatalkan';
      default: return status;
    }
  }

  String _formatPrice(dynamic price) {
    if (price == null) return 'Rp 0';
    final n = (price is num) ? price.toDouble() : double.tryParse(price.toString()) ?? 0;
    return 'Rp ${NumberFormat('#,###', 'id_ID').format(n)}';
  }

  @override
  Widget build(BuildContext context) {
    final tabs = ['Hari Ini (${_todayOrders.length})', 'Akan Datang (${_upcomingOrders.length})', 'Riwayat (${_historyOrders.length})'];

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manajemen Orderan'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          bottom: TabBar(
            isScrollable: true,
            labelColor: const Color(0xFF0D9488),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF0D9488),
            tabs: tabs.map((t) => Tab(text: t)).toList(),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildOrderList(_todayOrders, true),
                  _buildOrderList(_upcomingOrders, false),
                  _buildOrderList(_historyOrders, false),
                ],
              ),
      ),
    );
  }

  Widget _buildOrderList(List<Map<String, dynamic>> orders, bool isTodayTab) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              isTodayTab ? 'Tidak ada order hari ini' : 'Tidak ada order',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = orders[index];
          final status = order['status'] as String? ?? '';
          final isActive = ['accepted', 'on_the_way', 'arrived', 'in_progress'].contains(status);

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProviderOrderDetailPage(rawOrder: order),
                ),
              );
            },
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _statusColor(status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _statusLabel(status),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _statusColor(status)),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        AppDateUtils.formatShort(order['work_date'] as String?),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    order['description'] as String? ?? 'Tidak ada deskripsi',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Customer: ${order['profiles_customer']?['full_name'] ?? '-'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatPrice(order['total_price']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      if (isTodayTab && isActive) _buildActionButton(order, status) else const SizedBox.shrink(),
                    ],
                  ),
                ],
              ),
            ),
          ),
          );
        },
      ),
    );
  }

  Widget _buildActionButton(Map<String, dynamic> order, String status) {
    if (!OperatingHours.isWithinOperatingHours()) {
      return const Text('Di luar jam operasional', style: TextStyle(fontSize: 11, color: Colors.orange));
    }

    String label;
    String nextStatus;
    switch (status) {
      case 'accepted':
        label = 'Berangkat';
        nextStatus = 'on_the_way';
        break;
      case 'on_the_way':
        label = 'Tiba di Lokasi';
        nextStatus = 'arrived';
        break;
      case 'arrived':
        label = 'Mulai Bekerja';
        nextStatus = 'in_progress';
        break;
      case 'in_progress':
        label = 'Selesaikan Pekerjaan';
        nextStatus = 'completed';
        break;
      default:
        return const SizedBox.shrink();
    }

    return SizedBox(
      height: 36,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        onPressed: () async {
          try {
            await _dio.patch(
              '${ApiEndpoints.updateOrderStatus}${order['id']}/status',
              data: {'status': nextStatus},
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status berhasil diperbarui')));
            _loadOrders();
          } catch (e) {
            final msg = e.toString();
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $msg')));
          }
        },
        child: Text(label),
      ),
    );
  }
}
