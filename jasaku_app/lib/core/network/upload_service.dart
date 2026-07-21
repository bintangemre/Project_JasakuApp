import 'dart:io';
import 'package:dio/dio.dart';
import '../constants/api_endpoints.dart';
import 'api_client.dart';

class UploadService {
  static Future<String?> uploadFile(File file, {String folder = 'order-attachments'}) async {
    try {
      final fileName = file.path.split('/').last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: fileName),
        'folder': folder,
      });

      final response = await ApiClient().dio.post(
        '${ApiEndpoints.baseUrl}/api/upload',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      if (response.statusCode == 201 && response.data['data'] != null) {
        return response.data['data']['url'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<List<String>> uploadFiles(List<File> files, {String folder = 'order-attachments'}) async {
    final urls = <String>[];
    for (final file in files) {
      final url = await uploadFile(file, folder: folder);
      if (url != null) urls.add(url);
    }
    return urls;
  }
}
