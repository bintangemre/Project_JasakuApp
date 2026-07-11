import 'package:intl/intl.dart';

class OrderModel {
  final String id;
  final String status;
  final int totalPrice;
  final int additionalFee;
  final String? description;
  final DateTime? workDate;
  final DateTime? endDate;
  final DateTime? createdAt;
  final String? providerName;
  final String? providerId;
  final String? customerName;
  final String? address;
  final double? lat;
  final double? lng;

  OrderModel({
    required this.id,
    required this.status,
    required this.totalPrice,
    this.additionalFee = 0,
    this.description,
    this.workDate,
    this.endDate,
    this.createdAt,
    this.providerName,
    this.providerId,
    this.customerName,
    this.address,
    this.lat,
    this.lng,
  });

  static int _parsePrice(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  factory OrderModel.fromCustomerJson(Map<String, dynamic> json) {
    final provider = json['provider_profiles'] as Map<String, dynamic>?;
    return OrderModel(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'pending',
      totalPrice: _parsePrice(json['total_price']),
      additionalFee: _parsePrice(json['additional_fee']),
      description: json['description'] as String?,
      workDate: json['work_date'] != null ? DateTime.tryParse(json['work_date'] as String) : null,
      endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      providerName: provider?['full_name'] as String?,
      providerId: provider?['user_id'] as String?,
    );
  }

  factory OrderModel.fromProviderJson(Map<String, dynamic> json) {
    final locations = json['order_locations'] as List<dynamic>?;
    String? address;
    double? lat;
    double? lng;
    if (locations != null && locations.isNotEmpty) {
      final loc = locations.first as Map<String, dynamic>;
      address = loc['address'] as String?;
      lat = loc['lat'] != null ? double.tryParse(loc['lat'].toString()) : null;
      lng = loc['lng'] != null ? double.tryParse(loc['lng'].toString()) : null;
    }
    return OrderModel(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'pending',
      totalPrice: _parsePrice(json['total_price']),
      additionalFee: _parsePrice(json['additional_fee']),
      description: json['description'] as String?,
      workDate: json['work_date'] != null ? DateTime.tryParse(json['work_date'] as String) : null,
      endDate: json['end_date'] != null ? DateTime.tryParse(json['end_date'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      customerName: (json['profiles_customer'] as Map<String, dynamic>?)?['full_name'] as String?,
      address: address,
      lat: lat,
      lng: lng,
    );
  }

  String get statusLabel {
    switch (status) {
      case 'pending_payment': return 'Menunggu Pembayaran';
      case 'pending': return 'Menunggu';
      case 'accepted': return 'Diterima';
      case 'on_the_way': return 'Dalam Perjalanan';
      case 'arrived': return 'Telah Tiba';
      case 'in_progress': return 'Sedang Dikerjakan';
      case 'completed': return 'Selesai';
      case 'rejected': return 'Ditolak';
      case 'cancelled': return 'Dibatalkan';
      default: return status;
    }
  }

  String get formattedDate {
    if (workDate == null) return '-';
    if (endDate != null && endDate != workDate) {
      return '${workDate!.day} ${_monthName(workDate!.month)} ${workDate!.year} - ${endDate!.day} ${_monthName(endDate!.month)} ${endDate!.year}';
    }
    return '${workDate!.day} ${_monthName(workDate!.month)} ${workDate!.year}';
  }

  String get formattedPrice {
    return NumberFormat('#,###', 'id_ID').format(totalPrice);
  }

  static String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return months[month - 1];
  }
}
