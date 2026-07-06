import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

class RoutingService {
  static const String _baseUrl = 'https://api.openrouteservice.org/v2/directions/driving-car/geojson';
  static String? _apiKey;

  static void init(String apiKey) {
    _apiKey = apiKey;
  }

  static Future<List<LatLng>> getRoute(LatLng origin, LatLng destination) async {
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      try {
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ));

        final response = await dio.post(
          _baseUrl,
          options: Options(
            headers: {
              'Authorization': _apiKey,
              'Content-Type': 'application/json',
            },
          ),
          data: {
            'coordinates': [
              [origin.longitude, origin.latitude],
              [destination.longitude, destination.latitude],
            ],
          },
        );

        final data = response.data;
        final coords = data['features']?[0]?['geometry']?['coordinates'] as List?;
        if (coords != null && coords.isNotEmpty) {
          return coords.map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
        }
      } catch (e) {
        debugPrint('[RoutingService] ORS error: $e');
      }
    }
    return [origin, destination];
  }
}
