import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/utils/image_url.dart';
import '../../../../services/routing_service.dart';
import '../../../location/presentation/providers/location_tracker_provider.dart';
import '../../data/custom_tasks_repository.dart';
import '../../data/models/custom_task_model.dart';
import 'customer_payment_page.dart';

class TaskDetailPage extends ConsumerStatefulWidget {
  final String taskId;
  final bool isProvider;
  const TaskDetailPage({super.key, required this.taskId, this.isProvider = false});

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  final _repo = CustomTasksRepository();
  CustomTaskModel? _task;
  bool _loading = true;
  String? _error;
  List<LatLng> _routePoints = [];
  LatLng? _providerLatLng;
  Timer? _routeTimer;

  void _goToPayment() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CustomerPaymentPage(taskId: widget.taskId)),
    );
  }

  @override
  void initState() {
    super.initState();
    _load();
    if (widget.isProvider) {
      _routeTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshRoute());
    }
  }

  @override
  void dispose() {
    _routeTimer?.cancel();
    super.dispose();
  }

  void _refreshRoute() {
    final tracker = ref.read(locationTrackerProvider);
    final pos = tracker.currentPosition;
    if (pos == null || _task == null) return;
    final taskLat = _task!.lat;
    final taskLng = _task!.lng;
    if (taskLat == null || taskLng == null) return;
    final from = LatLng(pos.latitude, pos.longitude);
    final to = LatLng(taskLat, taskLng);
    setState(() => _providerLatLng = from);
    RoutingService.getRoute(from, to).then((points) {
      if (mounted) setState(() => _routePoints = points);
    });
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _task = await _repo.getTaskDetail(widget.taskId);
      if (widget.isProvider && _task != null) {
        Future.microtask(_refreshRoute);
      }
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat('#,###', 'id_ID');
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Task')),
      backgroundColor: const Color(0xFFF8FAFC),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Gagal memuat: $_error'))
              : _task == null
                  ? const Center(child: Text('Task tidak ditemukan'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: _buildDetail(_task!, f),
                    ),
    );
  }

  Widget _buildDetail(CustomTaskModel task, NumberFormat f) {
    final allPoints = <Map<String, dynamic>>[
      {'lat': task.lat, 'lng': task.lng, 'label': 'Lokasi Awal', 'color': const Color(0xFF2563EB)},
      ...task.locations.asMap().entries.map((e) => {
        'lat': e.value.lat,
        'lng': e.value.lng,
        'label': e.value.label ?? 'Titik ${e.key + 1}',
        'color': Colors.red,
      }),
    ].where((p) => p['lat'] != null && p['lng'] != null).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              Text(task.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 4),
              _statusBadge(task.status),
              if (task.description != null && task.description!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(task.description!,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5)),
              ],
              if (task.images.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: task.images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final imgUrl = imageUrl(task.images[i]);
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imgUrl,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 100, height: 100,
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
        // Belum ada provider yang menerima (customer only)
        if (!widget.isProvider && task.acceptedCount == 0 && task.status == 'open') ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: const Row(
              children: [
                Icon(Icons.hourglass_empty, color: Color(0xFF2563EB)),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Menunggu diterima provider',
                      style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E40AF))),
                ),
              ],
            ),
          ),
        ],
        // Payment status banner (customer only)
        if (!widget.isProvider && task.acceptedCount > 0 && task.paymentStatus != 'paid') ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: task.paymentStatus == 'proof_uploaded'
                  ? const Color(0xFFFEF3C7)
                  : const Color(0xFFFFF1F0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: task.paymentStatus == 'proof_uploaded'
                    ? const Color(0xFFFDE68A)
                    : const Color(0xFFFECACA),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  task.paymentStatus == 'proof_uploaded'
                      ? Icons.hourglass_top
                      : Icons.payment,
                  color: task.paymentStatus == 'proof_uploaded'
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFFEF4444),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.paymentStatus == 'proof_uploaded'
                            ? 'Menunggu Konfirmasi'
                            : 'Pembayaran Diperlukan',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: task.paymentStatus == 'proof_uploaded'
                              ? const Color(0xFF92400E)
                              : const Color(0xFF991B1B),
                        ),
                      ),
                      Text(
                        task.paymentStatus == 'proof_uploaded'
                            ? 'Admin sedang memverifikasi pembayaran Anda'
                            : 'Bayar dulu agar provider bisa mulai bekerja',
                        style: TextStyle(
                          fontSize: 12,
                          color: task.paymentStatus == 'proof_uploaded'
                              ? const Color(0xFF92400E)
                              : const Color(0xFF991B1B),
                        ),
                      ),
                    ],
                  ),
                ),
                if (task.paymentStatus == 'unpaid')
                  TextButton(
                    onPressed: _goToPayment,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Bayar', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
              ],
            ),
          ),
        ],
        if (!widget.isProvider && task.paymentStatus == 'paid' && task.acceptedCount > 0) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF10B981)),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Pembayaran sudah dikonfirmasi',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF065F46))),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (widget.isProvider)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(Icons.celebration, size: 32, color: Colors.white),
                const SizedBox(height: 8),
                const Text(
                  'Yeay! Setelah menyelesaikan tugas ini\nkamu mendapatkan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Rp${f.format(task.totalBudget.toInt())}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          )
        else
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
                const Text('Budget',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const Divider(height: 20),
                _rowDetail('Budget per orang', 'Rp${f.format(task.budgetPerPerson.toInt())}'),
                _rowDetail('Jumlah mitra', '${task.acceptedCount}/${task.requiredPeople}'),
                _rowDetail('Total budget', 'Rp${f.format(task.totalBudget.toInt())}'),
                _rowDetail('Fee aplikasi', 'Rp${f.format(task.feeAmount.toInt())}'),
                const Divider(height: 16),
                _rowDetail('Total dibayar', 'Rp${f.format(task.totalPayable.toInt())}', bold: true),
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (allPoints.isNotEmpty)
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
                const Text('Lokasi',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(
                          allPoints.first['lat'] as double,
                          allPoints.first['lng'] as double,
                        ),
                        initialZoom: 13,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.jasaku.app',
                        ),
                        if (_routePoints.length > 1)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _routePoints,
                                color: const Color(0xFF2563EB),
                                strokeWidth: 4,
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            ...allPoints.asMap().entries.map((e) {
                              final p = e.value;
                              final isFirst = e.key == 0;
                              return Marker(
                                point: LatLng(p['lat'] as double, p['lng'] as double),
                                width: isFirst ? 30 : 30,
                                height: isFirst ? 30 : 30,
                                child: isFirst
                                    ? const Icon(Icons.location_on, color: Color(0xFF2563EB), size: 30)
                                    : Container(
                                        decoration: BoxDecoration(
                                          color: p['color'] as Color,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                        child: Center(
                                          child: Text('${e.key + 1}',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12)),
                                        ),
                                      ),
                              );
                            }),
                            if (widget.isProvider && _providerLatLng != null)
                              Marker(
                                point: _providerLatLng!,
                                width: 36,
                                height: 36,
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0288D1),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2.5),
                                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                                  ),
                                  child: const Icon(Icons.motorcycle, color: Colors.white, size: 22),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (task.address != null || task.locationDetail != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (task.address != null)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.location_on, size: 16, color: const Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(task.address!,
                                    style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                              ),
                            ],
                          ),
                        if (task.locationDetail != null && task.locationDetail!.isNotEmpty) ...[
                          if (task.address != null) const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.notes, size: 16, color: Colors.grey[500]),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(task.locationDetail!,
                                    style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                ...allPoints.asMap().entries.map((e) {
                  final p = e.value;
                  final locIdx = e.key - 1;
                  final loc = locIdx >= 0 && locIdx < task.locations.length ? task.locations[locIdx] : null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: p['color'] as Color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p['label'] as String? ?? 'Titik ${e.key + 1}',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                              if (loc != null && loc.address.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(loc.address,
                                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (widget.isProvider) ...[
          // Provider view: show customer info
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
                const Text('Customer',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const Divider(height: 20),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFF2563EB).withOpacity(0.1),
                      child: const Icon(Icons.person, size: 18, color: Color(0xFF2563EB)),
                    ),
                    const SizedBox(width: 12),
                    Text(task.customerName ?? 'Customer',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
        ] else if (task.providers.isNotEmpty)
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
                const Text('Mitra',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const Divider(height: 20),
                ...task.providers.map((p) => _buildProviderCard(p, f)),
              ],
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildProviderCard(TaskProviderModel p, NumberFormat f) {
    final tpStatusColor = p.status == 'accepted'
        ? const Color(0xFFF59E0B)
        : p.status == 'completed'
            ? const Color(0xFF10B981)
            : Colors.grey;
    final tpStatusLabel = p.status == 'accepted'
        ? 'Berjalan'
        : p.status == 'completed'
            ? 'Selesai'
            : p.status;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF00A651).withOpacity(0.1),
            child: const Icon(Icons.person, size: 18, color: Color(0xFF00A651)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.fullName ?? 'Mitra',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                if (p.orderId != null)
                  Text('Order: ${p.orderStatus}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tpStatusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(tpStatusLabel,
                style: TextStyle(
                    fontSize: 11,
                    color: tpStatusColor,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final statusColor = status == 'open'
        ? const Color(0xFF2563EB)
        : status == 'in_progress'
            ? const Color(0xFFF59E0B)
            : status == 'completed'
                ? const Color(0xFF10B981)
                : Colors.grey;
    final statusLabel = status == 'open'
        ? 'Mencari Mitra'
        : status == 'in_progress'
            ? 'Berjalan'
            : status == 'completed'
                ? 'Selesai'
                : status;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(statusLabel,
          style: TextStyle(
              fontSize: 12,
              color: statusColor,
              fontWeight: FontWeight.w600)),
    );
  }

  Widget _rowDetail(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }
}
