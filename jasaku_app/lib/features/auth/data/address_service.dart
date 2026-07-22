import '../../../core/network/api_client.dart';

class AddressItem {
  final String code;
  final String name;
  const AddressItem({required this.code, required this.name});

  @override
  String toString() => name;
}

class AddressService {
  static String get _baseUrl => '${ApiClient().dio.options.baseUrl}/api/wilayah';

  static Future<List<AddressItem>> getProvinces() async {
    final resp = await ApiClient().dio.get('$_baseUrl/provinsi');
    final data = (resp.data['data'] as List)
        .map((e) => AddressItem(code: e['code'].toString(), name: e['name'].toString()))
        .toList();
    return data..sort((a, b) => a.name.compareTo(b.name));
  }

  static Future<List<AddressItem>> getCities(String provinceCode) async {
    final resp = await ApiClient().dio.get('$_baseUrl/kota', queryParameters: {'provinsi': provinceCode});
    final data = (resp.data['data'] as List)
        .map((e) => AddressItem(code: e['code'].toString(), name: e['name'].toString()))
        .toList();
    return data..sort((a, b) => a.name.compareTo(b.name));
  }

  static Future<List<AddressItem>> getDistricts(String regencyCode) async {
    final resp = await ApiClient().dio.get('$_baseUrl/kecamatan', queryParameters: {'kota': regencyCode});
    final data = (resp.data['data'] as List)
        .map((e) => AddressItem(code: e['code'].toString(), name: e['name'].toString()))
        .toList();
    return data..sort((a, b) => a.name.compareTo(b.name));
  }

  static Future<List<AddressItem>> getVillages(String districtCode) async {
    final resp = await ApiClient().dio.get('$_baseUrl/kelurahan', queryParameters: {'kecamatan': districtCode});
    final data = (resp.data['data'] as List)
        .map((e) => AddressItem(code: e['code'].toString(), name: e['name'].toString()))
        .toList();
    return data..sort((a, b) => a.name.compareTo(b.name));
  }
}
