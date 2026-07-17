import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../services/routing_service.dart';

class OrderTrackingPage extends ConsumerStatefulWidget {
  final String orderId;

  const OrderTrackingPage({super.key, required this.orderId});

  @override
  ConsumerState<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends ConsumerState<OrderTrackingPage> {
  final Dio _dio = ApiClient().dio;
  final MapController _mapController = MapController();
  Timer? _pollTimer;

  LatLng? _providerPos;
  LatLng? _orderPos;
  String? _providerName;
  String? _status;
  bool _isLoading = true;
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _fetchTracking();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchTracking());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchTracking() async {
    try {
      final response = await _dio.get('${ApiEndpoints.getOrderTracking}${widget.orderId}/tracking');
      final rawData = response.data;
      final data = rawData['data'] as Map<String, dynamic>?;
      if (data == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final providerLoc = data['providerLocation'] as Map<String, dynamic>?;
      final orderLoc = data['orderLocation'] as Map<String, dynamic>?;

      setState(() {
        _providerPos = providerLoc != null && providerLoc['lat'] != null
            ? LatLng((providerLoc['lat'] as num).toDouble(), (providerLoc['lng'] as num).toDouble())
            : null;
        _orderPos = orderLoc != null && orderLoc['lat'] != null
            ? LatLng((orderLoc['lat'] as num).toDouble(), (orderLoc['lng'] as num).toDouble())
            : null;
        _providerName = data['providerName'] as String?;
        _status = data['status'] as String?;
        _isLoading = false;
      });

      if (_providerPos != null && _orderPos != null) {
        _fetchRoute();
        _mapController.move(_providerPos!, 15.0);
      } else if (_providerPos != null) {
        _mapController.move(_providerPos!, 15.0);
      } else if (_orderPos != null) {
        _mapController.move(_orderPos!, 15.0);
      }
    } catch (e) {
      debugPrint('[Tracking] Error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_providerName ?? 'Lacak Provider'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _orderPos ?? const LatLng(-3.4423, 114.8321),
                    initialZoom: 15.0,
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
                        if (_orderPos != null)
                          Marker(
                            point: _orderPos!,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.person_pin_circle, color: Colors.red, size: 36),
                          ),
                        if (_providerPos != null)
                          Marker(
                            point: _providerPos!,
                            width: 36,
                            height: 36,
                            child: _providerMarkerIcon(_status ?? ''),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 24,
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.circle, size: 12, color: _status == 'on_the_way' ? Colors.blue : _status == 'arrived' ? Colors.indigo : Colors.green),
                              const SizedBox(width: 8),
                              Text(_statusLabel(_status ?? ''), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_providerPos != null)
                            Text('Provider: ${_providerPos!.latitude.toStringAsFixed(5)}, ${_providerPos!.longitude.toStringAsFixed(5)}',
                                style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          if (_orderPos != null)
                            Text('Lokasi Anda: ${_orderPos!.latitude.toStringAsFixed(5)}, ${_orderPos!.longitude.toStringAsFixed(5)}',
                                style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _fetchRoute() async {
    if (_providerPos == null || _orderPos == null) return;
    final points = await RoutingService.getRoute(_providerPos!, _orderPos!);
    if (mounted) {
      setState(() => _routePoints = points);
    }
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

  String _statusLabel(String status) {
    switch (status) {
      case 'on_the_way': return 'Provider dalam perjalanan';
      case 'arrived': return 'Provider telah tiba';
      case 'in_progress': return 'Pekerjaan sedang berlangsung';
      default: return status;
    }
  }
}
