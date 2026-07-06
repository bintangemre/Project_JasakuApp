import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/constants/api_endpoints.dart';
import 'models/custom_task_model.dart';

class CustomTasksRepository {
  final Dio _dio;
  CustomTasksRepository() : _dio = ApiClient().dio;

  Future<CustomTaskModel> createTask({
    required String title,
    String? description,
    required double budgetPerPerson,
    required int requiredPeople,
    required String address,
    required double lat,
    required double lng,
    List<Map<String, dynamic>> locations = const [],
  }) async {
    final response = await _dio.post(ApiEndpoints.customTasks, data: {
      'title': title,
      'description': description,
      'budget_per_person': budgetPerPerson,
      'required_people': requiredPeople,
      'address': address,
      'lat': lat,
      'lng': lng,
      'locations': locations,
    });
    return CustomTaskModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<List<CustomTaskModel>> getAvailableTasks({
    double? lat,
    double? lng,
    double? radius,
  }) async {
    final queryParams = <String, dynamic>{};
    if (lat != null && lng != null) {
      queryParams['lat'] = lat;
      queryParams['lng'] = lng;
      if (radius != null) queryParams['radius'] = radius;
    }
    final response = await _dio.get(
      ApiEndpoints.customTasksAvailable,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((json) => CustomTaskModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<CustomTaskModel>> getMyTasks() async {
    final response = await _dio.get(ApiEndpoints.customTasksMine);
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((json) => CustomTaskModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<CustomTaskModel>> getMyAcceptedTasks() async {
    final response = await _dio.get('${ApiEndpoints.customTasks}/my-accepted');
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((json) => CustomTaskModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<CustomTaskModel> getTaskDetail(String taskId) async {
    final response = await _dio.get('${ApiEndpoints.customTasks}/$taskId');
    return CustomTaskModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> acceptTask(String taskId) async {
    await _dio.post('${ApiEndpoints.customTasks}/$taskId/accept');
  }

  Future<void> completeTask(String taskId) async {
    await _dio.patch('${ApiEndpoints.customTasks}/$taskId/complete');
  }

  Future<void> cancelTask(String taskId) async {
    await _dio.post('${ApiEndpoints.customTasks}/$taskId/cancel');
  }

  Future<List<Map<String, dynamic>>> searchLocation(String query, {double? lat, double? lng}) async {
    final queryParams = <String, dynamic>{'q': query};
    if (lat != null) queryParams['lat'] = lat;
    if (lng != null) queryParams['lng'] = lng;
    try {
      final response = await _dio.get(
        '${ApiEndpoints.customTasks}/search-location',
        queryParameters: queryParams,
      );
      return (response.data['data'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          [];
    } catch (_) {
      return [];
    }
  }
}
