import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../location/presentation/providers/location_tracker_provider.dart';
import '../../../../services/routing_service.dart';
import '../providers/provider_dashboard_provider.dart';
import '../../../custom_tasks/presentation/pages/provider_available_tasks_page.dart';
import '../../../custom_tasks/presentation/pages/provider_my_bids_page.dart';
import 'provider_full_map_page.dart';

class ProviderHomePage extends ConsumerStatefulWidget {
  const ProviderHomePage({super.key});

  @override
  ConsumerState<ProviderHomePage> createState() => _ProviderHomePageState();
}

class _ProviderHomePageState extends ConsumerState<ProviderHomePage> {
  final Dio _dio = ApiClient().dio;
  List<LatLng> _routePoints = [];
  LatLng? _customerLatLng;
  final MapController _mapController = MapController();
  Timer? _routeTimer;
  LatLng? _lastProviderPos;
  bool _extensionLoading = false;

  @override
  void initState() {
    super.initState();
    _routeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final state = ref.read(dashboardProvider);
      final activeOrder = state.activeOrder;
      if (activeOrder == null) return;
      final locs = activeOrder['order_locations'] as List? ?? [];
      final lat = locs.isNotEmpty ? (locs[0]['lat'] as num?)?.toDouble() : null;
      final lng = locs.isNotEmpty ? (locs[0]['lng'] as num?)?.toDouble() : null;
      if (lat == null || lng == null) return;
      final trackerState = ref.read(locationTrackerProvider);
      final pos = trackerState.currentPosition;
      if (pos == null) return;
      _fetchRoute(LatLng(pos.latitude, pos.longitude), LatLng(lat, lng));
    });
    Future.microtask(() {
      ref.read(dashboardProvider.notifier).loadDashboard();
    });
  }

  @override
  void dispose() {
    _routeTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchRoute(LatLng from, LatLng to) async {
    final points = await RoutingService.getRoute(from, to);
    if (mounted) {
      setState(() => _routePoints = points);
    }
  }

  Future<void> _updateStatus(String orderId, String status) async {
    try {
      await _dio.patch('${ApiEndpoints.updateOrderStatus}$orderId/status', data: {'status': status});
      ref.read(dashboardProvider.notifier).loadDashboard();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Status: ${_statusLabel(status)}'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _requestExtension(String orderId) async {
    final days = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Minta Perpanjangan Waktu'),
        children: [1, 2, 3].map((n) => SimpleDialogOption(
          onPressed: () => Navigator.pop(ctx, n),
          child: Text('$n hari'),
        )).toList(),
      ),
    );
    if (days == null || !mounted) return;

    setState(() => _extensionLoading = true);
    try {
      await _dio.post(ApiEndpoints.requestExtension(orderId), data: {'additionalDays': days});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permintaan perpanjangan diajukan'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _extensionLoading = false);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'on_the_way': return 'Dalam Perjalanan';
      case 'arrived': return 'Telah Tiba';
      case 'in_progress': return 'Sedang Dikerjakan';
      case 'completed': return 'Selesai';
      default: return status;
    }
  }

  String _nextStatusLabel(String current) {
    switch (current) {
      case 'accepted': return 'Berangkat';
      case 'on_the_way': return 'Tiba di Lokasi';
      case 'arrived': return 'Mulai Bekerja';
      case 'in_progress': return 'Selesaikan Pekerjaan';
      default: return 'Lanjutkan';
    }
  }

  String _nextStatus(String current) {
    switch (current) {
      case 'accepted': return 'on_the_way';
      case 'on_the_way': return 'arrived';
      case 'arrived': return 'in_progress';
      case 'in_progress': return 'completed';
      default: return '';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted': return const Color(0xFFF59E0B);
      case 'on_the_way': return const Color(0xFF0288D1);
      case 'arrived': return Colors.indigo;
      case 'in_progress': return const Color(0xFF2563EB);
      case 'completed': return Colors.green;
      default: return Colors.grey;
    }
  }

  String _activeStatusDisplay(String status) {
    switch (status) {
      case 'accepted': return 'Diterima';
      case 'on_the_way': return 'Dalam Perjalanan';
      case 'arrived': return 'Telah Tiba';
      case 'in_progress': return 'Sedang Dikerjakan';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.fullName == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(state.error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(dashboardProvider.notifier).loadDashboard(),
              child: const Text("Coba Lagi"),
            ),
          ],
        ),
      );
    }

    final activeOrder = state.activeOrder;
    final activeServiceName = activeOrder?['order_items'] != null &&
            (activeOrder!['order_items'] as List).isNotEmpty
        ? (activeOrder['order_items'][0]['services']?['name'] as String? ?? "Pekerjaan")
        : "Pekerjaan Aktif";
    final activeCustomerName =
        activeOrder?['profiles_customer']?['full_name'] as String? ?? "";
    final activeAddress = activeOrder?['order_locations'] != null &&
            (activeOrder!['order_locations'] as List).isNotEmpty
        ? (activeOrder['order_locations'][0]['address'] as String? ?? "")
        : "";
    final activeStatus = activeOrder?['status'] as String? ?? "";
    final activeOrderId = activeOrder?['id'] as String? ?? "";

    final activeOrderLocations = activeOrder?['order_locations'] as List? ?? [];
    final activeOrderLat = activeOrderLocations.isNotEmpty
        ? (activeOrderLocations[0]['lat'] as num?)?.toDouble()
        : null;
    final activeOrderLng = activeOrderLocations.isNotEmpty
        ? (activeOrderLocations[0]['lng'] as num?)?.toDouble()
        : null;
    _customerLatLng = (activeOrderLat != null && activeOrderLng != null)
        ? LatLng(activeOrderLat, activeOrderLng)
        : null;

    final trackerState = ref.watch(locationTrackerProvider);
    final providerPos = trackerState.currentPosition;
    final providerLatLng = providerPos != null
        ? LatLng(providerPos.latitude, providerPos.longitude)
        : null;

    final customerLoc = _customerLatLng;
    if (customerLoc != null && providerLatLng != null && _routePoints.isEmpty) {
      Future.microtask(() => _fetchRoute(providerLatLng, customerLoc));
    }

    if (providerLatLng != null && _lastProviderPos != providerLatLng) {
      _lastProviderPos = providerLatLng;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mapController.move(providerLatLng, 15.0);
      });
    }

    final priceFormat = NumberFormat('#,###', 'id_ID');
    final monthlyEarnings = state.monthlyEarnings;
    final displayEarnings = monthlyEarnings > 0
        ? "Rp ${priceFormat.format(monthlyEarnings)}"
        : "Rp 0";
    final perfDisplay = state.performance.toStringAsFixed(0);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: double.infinity,
                height: 200,
                decoration: const BoxDecoration(
                  color: Color(0xFF00A651),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(32),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            image: state.profilePhoto != null
                                ? DecorationImage(
                                    image: NetworkImage(state.profilePhoto!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: state.profilePhoto == null
                              ? const Icon(Icons.person, color: Colors.grey, size: 36)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    state.fullName ?? "Provider",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.check_circle, color: Colors.white, size: 16),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                state.servicesCount > 0
                                    ? "${state.servicesCount} layanan tersedia"
                                    : (state.nickname ?? "Provider"),
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 24),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 110,
                left: 20,
                right: 20,
                child: Row(
                  children: [
                    _buildStatCard(
                      state.rating.toStringAsFixed(1),
                      "Rating",
                      isRating: true,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      state.totalJobs.toString(),
                      "Selesai",
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      perfDisplay,
                      "Performa",
                      isPercent: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 65),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Status Ketersediaan",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              state.isActive
                                  ? "Anda sedang menerima pesanan"
                                  : "Anda sedang tidak menerima pesanan",
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: state.isActive,
                        activeColor: const Color(0xFF00A651),
                        onChanged: (_) {
                          ref.read(dashboardProvider.notifier).toggleAvailability();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Terima Task Custom",
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              state.taskAvailable
                                  ? "Kamu bisa menerima task"
                                  : "Kamu tidak menerima task",
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: state.taskAvailable,
                        activeColor: const Color(0xFF00A651),
                        onChanged: (_) {
                          ref.read(dashboardProvider.notifier).toggleTaskAvailability();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (activeOrder != null) ...[
                  const Text(
                    "Pekerjaan Aktif",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              activeServiceName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(activeStatus),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _activeStatusDisplay(activeStatus),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (activeCustomerName.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            activeCustomerName,
                            style: const TextStyle(
                              color: Color(0xFF4B5563),
                              fontSize: 14,
                            ),
                          ),
                        ],
                        if (activeAddress.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            activeAddress,
                            style: const TextStyle(
                              color: Color(0xFF6B7280),
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: activeOrderId.isNotEmpty
                                ? () => _updateStatus(activeOrderId, _nextStatus(activeStatus))
                                : null,
                            child: Text(
                              _nextStatusLabel(activeStatus),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                        ),
                        if (activeStatus == 'in_progress') ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFF59E0B),
                                side: const BorderSide(color: Color(0xFFF59E0B)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _extensionLoading
                                  ? null
                                  : () => _requestExtension(activeOrderId),
                              icon: _extensionLoading
                                  ? const SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.timer_outlined, size: 20),
                              label: const Text('Minta Perpanjangan Waktu'),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        _buildRouteMap(providerLatLng, _customerLatLng, activeStatus),
                  const SizedBox(height: 24),
                ],
                const SizedBox(height: 24),
                _buildShortcutCard(
                  icon: Icons.assignment_outlined,
                  title: 'Task Tersedia',
                  subtitle: 'Lihat dan ajukan penawaran task dari customer',
                  color: const Color(0xFF00A651),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProviderAvailableTasksPage()),
                  ),
                ),
                const SizedBox(height: 12),
                _buildShortcutCard(
                  icon: Icons.handshake_outlined,
                  title: 'Task Saya',
                  subtitle: 'Lihat task yang sudah diambil',
                  color: const Color(0xFF2563EB),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProviderMyBidsPage()),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Penghasilan Bulan Ini",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF475569),
                            ),
                          ),
                          Icon(
                            Icons.attach_money,
                            color: Colors.grey.shade400,
                            size: 22,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        displayEarnings,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      if (monthlyEarnings > 0) ...[
                        const SizedBox(height: 8),
                        const Row(
                          children: [
                            Icon(Icons.trending_up, color: Color(0xFF10B981), size: 16),
                            SizedBox(width: 4),
                            Text(
                              "Pendapatan bulan ini",
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String value,
    String title, {
    bool isRating = false,
    bool isPercent = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isRating) ...[
                  const Icon(Icons.star, color: Color(0xFFFFC107), size: 16),
                  const SizedBox(width: 4),
                ],
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (isPercent) ...[
                  const Text(
                    "%",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteMap(LatLng? providerPos, LatLng? customerPos, String status) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Lokasi Customer",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProviderFullMapPage(
                customerPos: customerPos,
                routePoints: _routePoints,
                status: status,
              ),
            ),
          ),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                children: [
                  FlutterMap(
                    key: const ValueKey('dashboard-route-map'),
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: customerPos ?? providerPos ?? const LatLng(-6.2088, 106.8456),
                      initialZoom: 14.0,
                      interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
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
                          if (customerPos != null)
                            Marker(
                              point: customerPos,
                              width: 36,
                              height: 36,
                              child: const Icon(Icons.person_pin_circle, color: Colors.red, size: 36),
                            ),
                          if (providerPos != null)
                            Marker(
                              point: providerPos,
                              width: 36,
                              height: 36,
                              child: _providerMarkerIcon(status),
                            ),
                        ],
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fullscreen, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'Perbesar',
                            style: TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _providerMarkerIcon(String status) {
    final isOnWay = status == 'accepted' || status == 'on_the_way';
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isOnWay ? const Color(0xFF0288D1) : const Color(0xFF10B981),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: isOnWay
          ? const Icon(Icons.motorcycle, color: Colors.white, size: 22)
          : const Icon(Icons.waving_hand, color: Colors.white, size: 22),
    );
  }
}
