import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';

class LocationTrackerState {
  final Position? currentPosition;
  final bool isTracking;

  const LocationTrackerState({this.currentPosition, this.isTracking = false});
}

class LocationTrackerNotifier extends StateNotifier<LocationTrackerState> {
  final Dio _dio = ApiClient().dio;
  StreamSubscription<Position>? _subscription;
  Timer? _updateTimer;

  LocationTrackerNotifier() : super(const LocationTrackerState());

  Future<void> startTracking() async {
    if (state.isTracking) return;

    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return;
    }

    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      state = LocationTrackerState(currentPosition: pos, isTracking: true);
      _sendLocation();
    } catch (e) {
      debugPrint('[LocationTracker] Initial position error: $e');
      return;
    }

    _subscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (position) {
        state = LocationTrackerState(currentPosition: position, isTracking: true);
      },
      onError: (error) {
        debugPrint('[LocationTracker] Stream error: $error');
      },
    );

    _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _sendLocation();
    });
  }

  void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
    _updateTimer?.cancel();
    _updateTimer = null;
    state = const LocationTrackerState();
  }

  Future<void> _sendLocation() async {
    final pos = state.currentPosition;
    if (pos == null) return;

    try {
      await _dio.put(
        ApiEndpoints.updateLocation,
        data: {'lat': pos.latitude, 'lng': pos.longitude},
      );
    } catch (e) {
      debugPrint('[LocationTracker] Failed to send: $e');
    }
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}

final locationTrackerProvider = StateNotifierProvider<LocationTrackerNotifier, LocationTrackerState>((ref) {
  return LocationTrackerNotifier();
});
