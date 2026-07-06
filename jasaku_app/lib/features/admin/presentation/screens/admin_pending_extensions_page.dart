import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import 'package:intl/intl.dart';

class AdminPendingExtensionsPage extends StatefulWidget {
  const AdminPendingExtensionsPage({super.key});

  @override
  State<AdminPendingExtensionsPage> createState() => _AdminPendingExtensionsPageState();
}

class _AdminPendingExtensionsPageState extends State<AdminPendingExtensionsPage> {
  final Dio _dio = ApiClient().dio;
  List<Map<String, dynamic>> _extensions = [];
  bool _isLoading = true;
  String? _error;
  final Set<String> _loadingIds = {};

  @override
  void initState() {
    super.initState();
    _fetchExtensions();
  }

  Future<void> _fetchExtensions() async {
    setState(() => _isLoading = true);
    try {
      final res = await _dio.get(ApiEndpoints.adminPendingExtensions);
      final data = res.data['data'] as List? ?? [];
      setState(() {
        _extensions = data.cast<Map<String, dynamic>>();
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _act(String extId, String status) async {
    final label = status == 'approved' ? 'setujui' : 'tolak';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: Text('Yakin akan $label extension ini?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(status == 'approved' ? 'Setujui' : 'Tolak'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loadingIds.add(extId));
    try {
      await _dio.patch(ApiEndpoints.adminApproveExtension(extId), data: {'status': status});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'approved' ? 'Extension disetujui' : 'Extension ditolak'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchExtensions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingIds.remove(extId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat('#,###', 'id_ID');
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Pending Extensions'),
        backgroundColor: const Color(0xFF00A651),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchExtensions,
          ),
        ],
      ),
      body: _buildBody(priceFormat, dateFormat),
    );
  }

  Widget _buildBody(NumberFormat priceFormat, DateFormat dateFormat) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchExtensions, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }

    if (_extensions.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('Tidak ada request extension pending',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchExtensions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _extensions.length,
        itemBuilder: (_, i) => _buildCard(_extensions[i], priceFormat, dateFormat),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> ext, NumberFormat priceFormat, DateFormat dateFormat) {
    final orders = ext['orders'] as Map<String, dynamic>?;
    final providerName = orders?['provider_profiles']?['full_name'] as String? ?? '-';
    final customerName = orders?['profiles_customer']?['full_name'] as String? ?? '-';
    final workDate = orders?['work_date'] as String? ?? '';
    final totalPrice = orders?['total_price'];
    final extCount = ext['extension_count'] as int? ?? 1;
    final extId = ext['id'] as String? ?? '';
    final isActing = _loadingIds.contains(extId);
    final addCost = ext['additional_cost'];

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
                const Icon(Icons.swap_horiz, color: Color(0xFFF59E0B), size: 20),
                const SizedBox(width: 8),
                Text('Extension $extCount hari',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow('Provider', providerName, Icons.person_outline),
            _infoRow('Customer', customerName, Icons.person),
            _infoRow('Tgl Kerja', dateFormat.format(DateTime.parse(workDate)), Icons.calendar_today),
            if (totalPrice != null)
              _infoRow('Total Order', 'Rp ${priceFormat.format(_parsePrice(totalPrice))}', Icons.attach_money),
            if (addCost != null)
              _infoRow('Biaya Tambahan', 'Rp ${priceFormat.format(_parsePrice(addCost))}', Icons.money_off),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isActing ? null : () => _act(extId, 'rejected'),
                    child: isActing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A651),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: isActing ? null : () => _act(extId, 'approved'),
                    child: isActing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Setujui', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  double _parsePrice(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }
}