import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/image_url.dart';
import '../../../../core/utils/operating_hours.dart';
import '../../../orders/domain/models/order_model.dart';
import '../../../reports/presentation/pages/report_form_page.dart';

class ProviderOrderDetailPage extends StatefulWidget {
  final Map<String, dynamic> rawOrder;

  const ProviderOrderDetailPage({super.key, required this.rawOrder});

  @override
  State<ProviderOrderDetailPage> createState() => _ProviderOrderDetailPageState();
}

class _ProviderOrderDetailPageState extends State<ProviderOrderDetailPage> {
  late final Dio _dio;
  late Map<String, dynamic> _order;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _dio = ApiClient().dio;
    _order = widget.rawOrder;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'on_the_way':
        return const Color(0xFF0288D1);
      case 'arrived':
        return Colors.indigo;
      case 'in_progress':
        return Colors.purple;
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'accepted':
        return 'Diterima';
      case 'on_the_way':
        return 'Dalam Perjalanan';
      case 'arrived':
        return 'Tiba di Lokasi';
      case 'in_progress':
        return 'Sedang Bekerja';
      case 'completed':
        return 'Selesai';
      case 'rejected':
        return 'Ditolak';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final d = DateTime.parse(dateStr);
      return DateFormat('d MMM yyyy', 'id_ID').format(d);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final d = DateTime.parse(dateStr);
      return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(d);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatPrice(dynamic price) {
    if (price == null) return 'Rp 0';
    final n = (price is num) ? price.toDouble() : double.tryParse(price.toString()) ?? 0;
    return 'Rp ${NumberFormat('#,###', 'id_ID').format(n)}';
  }

  List<OrderAttachment> _parseAttachments() {
    final raw = _order['order_attachments'] as List<dynamic>?;
    if (raw == null || raw.isEmpty) return [];
    return raw
        .map((a) => OrderAttachment.fromJson(Map<String, dynamic>.from(a as Map)))
        .toList();
  }

  List<Map<String, dynamic>> _parseItems() {
    final raw = _order['order_items'] as List<dynamic>?;
    if (raw == null || raw.isEmpty) return [];
    return raw.map((i) => Map<String, dynamic>.from(i as Map)).toList();
  }

  String? _parseAddress() {
    final locs = _order['order_locations'] as List<dynamic>?;
    if (locs == null || locs.isEmpty) return null;
    return (locs.first as Map<String, dynamic>)['address'] as String?;
  }

  Map<String, dynamic>? _parseLocation() {
    final locs = _order['order_locations'] as List<dynamic>?;
    if (locs == null || locs.isEmpty) return null;
    final loc = locs.first as Map<String, dynamic>;
    if (loc['lat'] != null && loc['lng'] != null) {
      return {'lat': loc['lat'], 'lng': loc['lng']};
    }
    return null;
  }

  String get _status => _order['status'] as String? ?? '';
  bool get _isActive => ['accepted', 'on_the_way', 'arrived', 'in_progress'].contains(_status);

  Widget _nextActionButton() {
    if (!OperatingHours.isWithinOperatingHours()) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.access_time, size: 16, color: Colors.orange),
            SizedBox(width: 8),
            Text('Di luar jam operasional', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    String label;
    String nextStatus;
    IconData icon;
    switch (_status) {
      case 'accepted':
        label = 'Berangkat';
        nextStatus = 'on_the_way';
        icon = Icons.directions_walk;
        break;
      case 'on_the_way':
        label = 'Tiba di Lokasi';
        nextStatus = 'arrived';
        icon = Icons.location_on;
        break;
      case 'arrived':
        label = 'Mulai Bekerja';
        nextStatus = 'in_progress';
        icon = Icons.build;
        break;
      case 'in_progress':
        label = 'Selesaikan Pekerjaan';
        nextStatus = 'completed';
        icon = Icons.check_circle;
        break;
      default:
        return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        icon: _updating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        onPressed: _updating ? null : () => _updateStatus(nextStatus),
      ),
    );
  }

  Future<void> _updateStatus(String nextStatus) async {
    setState(() => _updating = true);
    try {
      await _dio.patch(
        '${ApiEndpoints.updateOrderStatus}${_order['id']}/status',
        data: {'status': nextStatus},
      );
      if (!mounted) return;
      setState(() {
        _order = {..._order, 'status': nextStatus};
        _updating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status berhasil diperbarui'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _updating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final attachments = _parseAttachments();
    final items = _parseItems();
    final address = _parseAddress();
    final location = _parseLocation();
    final customerName = (_order['profiles_customer'] as Map<String, dynamic>?)?['full_name'] as String? ?? '-';

    return PopScope(
      canPop: !_updating,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detail Orderan'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _statusColor(_status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _statusLabel(_status),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _statusColor(_status),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(_order['work_date'] as String?),
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _infoRow(Icons.person_outline, 'Customer', customerName),
                  const SizedBox(height: 10),
                  _infoRow(Icons.calendar_today, 'Tanggal Kerja', _formatDate(_order['work_date'] as String?)),
                  if (_order['end_date'] != null) ...[
                    const SizedBox(height: 10),
                    _infoRow(Icons.event, 'Selesai', _formatDate(_order['end_date'] as String?)),
                  ],
                  const SizedBox(height: 10),
                  _infoRow(Icons.access_time, 'Dibuat', _formatDateTime(_order['created_at'] as String?)),
                ],
              ),
            ),
            if (address != null && address.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Lokasi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(address, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                        ),
                      ],
                    ),
                    if (location != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Koordinat: ${location['lat']}, ${location['lng']}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (_order['description'] != null &&
                (_order['description'] as String).isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Deskripsi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(
                      _order['description'] as String,
                      style: TextStyle(fontSize: 13, color: Colors.grey[700], height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.photo_library, size: 18, color: Color(0xFF2563EB)),
                        const SizedBox(width: 8),
                        Text(
                          'Foto dari Customer (${attachments.length})',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: attachments.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) {
                          final url = imageUrl(attachments[i].fileUrl);
                          return GestureDetector(
                            onTap: () => _showFullImage(context, url),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                url,
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 120,
                                  height: 120,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image, color: Colors.grey),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (items.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Layanan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    ...items.map((item) {
                      final serviceName = (item['services'] as Map<String, dynamic>?)?['name'] as String? ?? '-';
                      final qty = item['quantity'] ?? 1;
                      final price = _formatPrice(item['price']);
                      final subtotal = _formatPrice(item['subtotal']);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(serviceName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                  Text('$qty x $price', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                ],
                              ),
                            ),
                            Text(subtotal, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  if (_order['additional_fee'] != null && (double.tryParse(_order['additional_fee'].toString()) ?? 0) > 0)
                    _priceRow('Biaya Tambahan', _formatPrice(_order['additional_fee'])),
                  _priceRow('Total Bayaran', _formatPrice(_order['total_price']), isBold: true),
                ],
              ),
            ),
            if (_isActive) ...[
              const SizedBox(height: 16),
              _nextActionButton(),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('Laporkan Masalah'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReportFormPage(orderId: _order['id'] as String?),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[400]),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      ],
    );
  }

  Widget _priceRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isBold ? 15 : 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(
            fontSize: isBold ? 16 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: isBold ? const Color(0xFF00A651) : null,
          )),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _FullScreenImagePage(imageUrl: url),
    ));
  }
}

class _FullScreenImagePage extends StatelessWidget {
  final String imageUrl;

  const _FullScreenImagePage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image, color: Colors.grey, size: 64),
            ),
          ),
        ),
      ),
    );
  }
}
