import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../data/custom_tasks_repository.dart';
import '../../data/models/custom_task_model.dart';
import 'task_detail_page.dart';

class ProviderMyBidsPage extends ConsumerStatefulWidget {
  const ProviderMyBidsPage({super.key});

  @override
  ConsumerState<ProviderMyBidsPage> createState() => _ProviderMyBidsPageState();
}

class _ProviderMyBidsPageState extends ConsumerState<ProviderMyBidsPage> {
  final _repo = CustomTasksRepository();
  List<CustomTaskModel> _tasks = [];
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
      _tasks = await _repo.getMyAcceptedTasks();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat('#,###', 'id_ID');
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Task Saya'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _tasks.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        itemCount: _tasks.length,
                        itemBuilder: (_, i) => _buildCard(_tasks[i], f),
                      ),
                    ),
    );
  }

  Widget _buildCard(CustomTaskModel task, NumberFormat f) {
    final tpStatus = task.tpStatus ?? 'accepted';
    final statusColor = tpStatus == 'accepted'
        ? const Color(0xFFF59E0B)
        : tpStatus == 'completed'
            ? const Color(0xFF10B981)
            : Colors.grey;
    final statusLabel = tpStatus == 'accepted'
        ? 'Berjalan'
        : tpStatus == 'completed'
            ? 'Selesai'
            : tpStatus;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TaskDetailPage(taskId: task.id, isProvider: true)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(task.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(statusLabel,
                          style: TextStyle(
                              fontSize: 11,
                              color: statusColor,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.monetization_on_outlined, size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text('Rp${f.format(task.budgetPerPerson.toInt())}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700])),
                  ],
                ),
                if (task.description != null && task.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(task.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                ],
                if (task.orderId != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 16, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text('Order: ${task.orderStatus ?? task.orderId!.substring(0, 8)}...',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ],
                if (task.lat != null && task.lng != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      height: 100,
                      width: double.infinity,
                      child: IgnorePointer(
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(task.lat!, task.lng!),
                            initialZoom: 14.0,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.jasaku.app',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(task.lat!, task.lng!),
                                  width: 30,
                                  height: 30,
                                  child: const Icon(Icons.location_on, color: Color(0xFF2563EB), size: 28),
                                ),
                                ...task.locations
                                    .where((loc) => loc.lat != null && loc.lng != null)
                                    .toList()
                                    .asMap()
                                    .entries
                                    .map((e) {
                                  final loc = e.value;
                                  final idx = e.key + 1;
                                  return Marker(
                                    point: LatLng(loc.lat!, loc.lng!),
                                    width: 26,
                                    height: 26,
                                    child: Container(
                                      alignment: Alignment.center,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text('$idx',
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                if (task.locations.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.flag_outlined, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text('${task.locations.length + 1} titik',
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
                if (task.paymentStatus != 'paid') ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 6),
                        Text(
                          task.paymentStatus == 'unpaid'
                              ? 'Menunggu penyesuaian customer'
                              : 'Menunggu konfirmasi admin',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
                if (tpStatus == 'accepted' && task.paymentStatus == 'paid' && !(task.payoutConfirmed)) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        try {
                          await _repo.completeTask(task.id);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Task selesai!')),
                          );
                          _load();
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal: $e')),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Selesaikan Task'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 20),
            Text('Gagal memuat task',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700])),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F7F0),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.handshake_outlined,
                  size: 48, color: Color(0xFF00A651)),
            ),
            const SizedBox(height: 24),
            const Text('Belum ada task diambil',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            Text(
              'Cari task tersedia dan ambil\ntask yang sesuai dengan kamu',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
