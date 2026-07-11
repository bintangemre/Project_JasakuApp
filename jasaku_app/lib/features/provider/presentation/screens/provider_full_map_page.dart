import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../location/presentation/providers/location_tracker_provider.dart';

class ProviderFullMapPage extends ConsumerWidget {
  final LatLng? customerPos;
  final List<LatLng> routePoints;
  final String status;

  const ProviderFullMapPage({
    super.key,
    this.customerPos,
    required this.routePoints,
    required this.status,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackerState = ref.watch(locationTrackerProvider);
    final providerPos = trackerState.currentPosition;

    final customerPos = this.customerPos;
    final initialCenter = customerPos ?? (providerPos != null ? LatLng(providerPos.latitude, providerPos.longitude) : const LatLng(-6.2088, 106.8456));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lokasi Customer'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: initialCenter,
          initialZoom: 15.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.jasaku.app',
          ),
          if (routePoints.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints,
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
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.person_pin_circle, color: Colors.red, size: 40),
                ),
              if (providerPos != null)
                Marker(
                  point: LatLng(providerPos.latitude, providerPos.longitude),
                  width: 40,
                  height: 40,
                  child: _providerMarkerIcon(status),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _providerMarkerIcon(String status) {
    final isOnWay = status == 'accepted' || status == 'on_the_way';
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isOnWay ? const Color(0xFF0288D1) : const Color(0xFF10B981),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: isOnWay
          ? const Icon(Icons.motorcycle, color: Colors.white, size: 24)
          : const Icon(Icons.waving_hand, color: Colors.white, size: 24),
    );
  }
}
