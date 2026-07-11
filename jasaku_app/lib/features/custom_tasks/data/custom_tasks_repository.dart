import 'dart:io';
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
    String? locationDetail,
    int publishDays = 1,
    List<File> images = const [],
  }) async {
    if (images.isEmpty) {
      final response = await _dio.post(ApiEndpoints.customTasks, data: {
        'title': title,
        'description': description,
        'budget_per_person': budgetPerPerson,
        'required_people': requiredPeople,
        'address': address,
        'lat': lat,
        'lng': lng,
        'locations': locations,
        'location_detail': locationDetail,
        'publish_days': publishDays,
      });
      return CustomTaskModel.fromJson(response.data['data'] as Map<String, dynamic>);
    }

    final form = FormData.fromMap({
      'title': title,
      'budget_per_person': budgetPerPerson,
      'required_people': requiredPeople,
      'address': address,
      'lat': lat,
      'lng': lng,
      'publish_days': publishDays,
    });
    if (description != null) form.fields.add(MapEntry('description', description));
    if (locationDetail != null) form.fields.add(MapEntry('location_detail', locationDetail));
    for (int i = 0; i < locations.length; i++) {
      final l = locations[i];
      form.fields.add(MapEntry('locations[${i}][label]', l['label']?.toString() ?? ''));
      form.fields.add(MapEntry('locations[${i}][address]', l['address']?.toString() ?? ''));
      form.fields.add(MapEntry('locations[${i}][lat]', l['lat'].toString()));
      form.fields.add(MapEntry('locations[${i}][lng]', l['lng'].toString()));
    }
    for (int i = 0; i < images.length; i++) {
      form.files.add(MapEntry(
        'images',
        await MultipartFile.fromFile(images[i].path, filename: images[i].path.split('\\').last.split('/').last),
      ));
    }
    final response = await _dio.post(ApiEndpoints.customTasks, data: form);
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
    final response = await _dio.get(ApiEndpoints.customTasksMyAccepted);
    final data = response.data['data'] as List<dynamic>? ?? [];
    return data
        .map((json) => CustomTaskModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<CustomTaskModel>> getMyActiveTasks() async {
    final response = await _dio.get(ApiEndpoints.customTasksMyActive);
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

  Future<void> updateWorkStatus(String taskId, String workStatus) async {
    await _dio.patch('${ApiEndpoints.customTasks}/$taskId/work-status', data: {'work_status': workStatus});
  }

  Future<void> cancelTask(String taskId) async {
    await _dio.post('${ApiEndpoints.customTasks}/$taskId/cancel');
  }

  Future<void> deleteTask(String taskId) async {
    await _dio.delete('${ApiEndpoints.customTasks}/$taskId');
  }

  Future<void> republishTask(String taskId) async {
    await _dio.post('${ApiEndpoints.customTasks}/$taskId/republish');
  }

  Future<PaymentDetailModel> getPaymentDetail(String taskId) async {
    final response = await _dio.get('${ApiEndpoints.customTasks}/$taskId/payment');
    return PaymentDetailModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  Future<void> uploadPaymentProof(String taskId, File file) async {
    final formData = FormData.fromMap({
      'proof': await MultipartFile.fromFile(file.path, filename: file.path.split('\\').last),
    });
    await _dio.post('${ApiEndpoints.customTasks}/$taskId/payment-proof', data: formData);
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
