import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../data/custom_tasks_repository.dart';
import '../../data/models/custom_task_model.dart';
import 'customer_create_task_page.dart';
import 'custom_task_tracking_page.dart';
import 'task_detail_page.dart';

class CustomerMyTasksPage extends ConsumerStatefulWidget {
  const CustomerMyTasksPage({super.key});

  @override
  ConsumerState<CustomerMyTasksPage> createState() => _CustomerMyTasksPageState();
}

class _CustomerMyTasksPageState extends ConsumerState<CustomerMyTasksPage> {
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
      _tasks = await _repo.getMyTasks();
    } catch (e) {
      if (e is DioException && e.response?.data is Map) {
        _error = (e.response!.data as Map)['message']?.toString() ?? e.toString();
      } else {
        _error = e.toString();
      }
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
        actions: [
          if (!_loading && _tasks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CustomerCreateTaskPage()),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Buat'),
              ),
            ),
        ],
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
    String effectiveStatus = task.status;
    if (effectiveStatus == 'open' && task.acceptedCount > 0) {
      effectiveStatus = 'in_progress';
    }
    final statusColor = effectiveStatus == 'open'
        ? const Color(0xFF2563EB)
        : effectiveStatus == 'in_progress'
            ? const Color(0xFFF59E0B)
            : effectiveStatus == 'completed' || effectiveStatus == 'fulfilled'
                ? const Color(0xFF10B981)
                : Colors.grey;
    final statusLabel = effectiveStatus == 'open'
        ? 'Mencari Mitra'
        : effectiveStatus == 'in_progress'
            ? 'Berjalan'
            : effectiveStatus == 'completed' || effectiveStatus == 'fulfilled'
                ? 'Selesai'
                : effectiveStatus == 'cancelled'
                    ? 'Dibatalkan'
                    : effectiveStatus;

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
            MaterialPageRoute(builder: (_) => TaskDetailPage(taskId: task.id)),
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
                    Icon(Icons.people_outline, size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      '${task.acceptedCount}/${task.requiredPeople} mitra',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.monetization_on_outlined, size: 16, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text('Rp${f.format(task.budgetPerPerson.toInt())}/org',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
                if (task.locations.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${task.locations.length + 1} titik',
                          style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                        ),
                      ),
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
                                  child: const Icon(Icons.person_pin_circle, color: Colors.red, size: 28),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                if (effectiveStatus == 'in_progress') ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CustomTaskTrackingPage(taskId: task.id),
                        ),
                      ),
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: const Text('Lacak Mitra', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
                if (task.status == 'completed' || task.status == 'fulfilled') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: const Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          task.status == 'fulfilled'
                              ? 'Semua dibayar'
                              : '${task.completedCount}/${task.totalProviders} selesai',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ),
                      InkWell(
                        onTap: () => _confirmDelete(task),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_outline, size: 14, color: Colors.red[400]),
                              const SizedBox(width: 4),
                              Text('Hapus',
                                  style: TextStyle(fontSize: 12, color: Colors.red[400], fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (task.expiresAt != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        task.isExpired ? Icons.timer_off : Icons.timer,
                        size: 16,
                        color: task.isExpired ? Colors.red : const Color(0xFFF59E0B),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          task.isExpired
                              ? 'Kedaluwarsa ${DateFormat('dd MMM yyyy', 'id').format(task.expiresAt!)}'
                              : 'Berlaku hingga ${DateFormat('dd MMM yyyy', 'id').format(task.expiresAt!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: task.isExpired ? Colors.red : Colors.grey[500],
                            fontWeight: task.isExpired ? FontWeight.w600 : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (task.isExpired && task.status == 'open') ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          await _repo.republishTask(task.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Task dipublikasi ulang!')),
                            );
                            _load();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.toString())),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Publikasi Ulang', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFF2563EB)),
                        visualDensity: VisualDensity.compact,
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

  Future<void> _confirmDelete(CustomTaskModel task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Task?'),
        content: Text('Task "${task.title}" akan dihapus permanen. Lanjutkan?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteTask(task.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task berhasil dihapus')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
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
            const Text('Gagal memuat task',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B))),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600])),
            ],
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
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.assignment_outlined,
                  size: 48, color: Color(0xFF2563EB)),
            ),
            const SizedBox(height: 24),
            const Text('Belum ada task',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            Text(
              'Buat task custom untuk kebutuhan kamu',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CustomerCreateTaskPage()),
                ),
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: const Text('Buat Task Baru'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
