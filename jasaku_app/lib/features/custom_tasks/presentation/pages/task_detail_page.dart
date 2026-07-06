import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/custom_tasks_repository.dart';
import '../../data/models/custom_task_model.dart';

class TaskDetailPage extends ConsumerStatefulWidget {
  final String taskId;
  const TaskDetailPage({super.key, required this.taskId});

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  final _repo = CustomTasksRepository();
  CustomTaskModel? _task;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _task = await _repo.getTaskDetail(widget.taskId);
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
                          urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.jasaku.app',
                        ),
                        MarkerLayer(
                          markers: allPoints.asMap().entries.map((e) {
                            final p = e.value;
                            return Marker(
                              point: LatLng(p['lat'] as double, p['lng'] as double),
                              width: 30,
                              height: 30,
                              child: Container(
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
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                ...allPoints.asMap().entries.map((e) {
                  final p = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: p['color'] as Color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(p['label'] as String? ?? 'Titik ${e.key + 1}',
                            style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (task.providers.isNotEmpty)
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
