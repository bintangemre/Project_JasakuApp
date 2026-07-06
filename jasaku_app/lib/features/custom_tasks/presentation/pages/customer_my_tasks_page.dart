import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../data/custom_tasks_repository.dart';
import '../../data/models/custom_task_model.dart';
import 'customer_create_task_page.dart';
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
    final statusColor = task.status == 'open'
        ? const Color(0xFF2563EB)
        : task.status == 'in_progress'
            ? const Color(0xFFF59E0B)
            : task.status == 'completed'
                ? const Color(0xFF10B981)
                : Colors.grey;
    final statusLabel = task.status == 'open'
        ? 'Mencari Mitra'
        : task.status == 'in_progress'
            ? 'Berjalan'
            : task.status == 'completed'
                ? 'Selesai'
                : task.status;

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
                              urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
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
                if (task.status == 'completed') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: const Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      Text(
                        '${task.completedCount}/${task.totalProviders} selesai',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
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
