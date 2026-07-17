import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../location/presentation/providers/location_tracker_provider.dart';
import '../../../../core/utils/map_marker_utils.dart';

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
    final initialCenter = customerPos ?? (providerPos != null ? LatLng(providerPos.latitude, providerPos.longitude) : const LatLng(-3.4423, 114.8321));

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

  Widget _providerMarkerIcon(String status) => buildProviderMarkerIcon(status, size: 40);
}
