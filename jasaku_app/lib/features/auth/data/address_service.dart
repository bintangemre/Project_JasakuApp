import 'dart:convert';
import 'package:http/http.dart' as http;

class AddressItem {
  final String code;
  final String name;
  const AddressItem({required this.code, required this.name});

  @override
  String toString() => name;
}

class AddressService {
  static const _baseUrl = 'https://wilayah.id/api';

  static Future<List<AddressItem>> getProvinces() async {
    final resp = await http.get(Uri.parse('$_baseUrl/provinces.json'));
    if (resp.statusCode != 200) throw Exception('Gagal memuat provinsi');
    final data = jsonDecode(resp.body)['data'] as List;
    return data
        .map((e) => AddressItem(code: e['code'].toString(), name: e['name'].toString()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  static Future<List<AddressItem>> getCities(String provinceCode) async {
    final resp = await http.get(Uri.parse('$_baseUrl/regencies/$provinceCode.json'));
    if (resp.statusCode != 200) throw Exception('Gagal memuat kota/kabupaten');
    final data = jsonDecode(resp.body)['data'] as List;
    return data
        .map((e) => AddressItem(code: e['code'].toString(), name: e['name'].toString()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  static Future<List<AddressItem>> getDistricts(String regencyCode) async {
    final resp = await http.get(Uri.parse('$_baseUrl/districts/$regencyCode.json'));
    if (resp.statusCode != 200) throw Exception('Gagal memuat kecamatan');
    final data = jsonDecode(resp.body)['data'] as List;
    return data
        .map((e) => AddressItem(code: e['code'].toString(), name: e['name'].toString()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  static Future<List<AddressItem>> getVillages(String districtCode) async {
    final resp = await http.get(Uri.parse('$_baseUrl/villages/$districtCode.json'));
    if (resp.statusCode != 200) throw Exception('Gagal memuat kelurahan');
    final data = jsonDecode(resp.body)['data'] as List;
    return data
        .map((e) => AddressItem(code: e['code'].toString(), name: e['name'].toString()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }
}
