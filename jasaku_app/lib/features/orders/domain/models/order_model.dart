import 'package:intl/intl.dart';

class OrderModel {
  final String id;
  final String status;
  final int totalPrice;
  final String? description;
  final DateTime? workDate;
  final DateTime? createdAt;
  final String? providerName;
  final String? providerId;
  final String? customerName;
  final String? address;

  OrderModel({
    required this.id,
    required this.status,
    required this.totalPrice,
    this.description,
    this.workDate,
    this.createdAt,
    this.providerName,
    this.providerId,
    this.customerName,
    this.address,
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
      description: json['description'] as String?,
      workDate: json['work_date'] != null ? DateTime.tryParse(json['work_date'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      providerName: provider?['full_name'] as String?,
      providerId: provider?['user_id'] as String?,
    );
  }

  factory OrderModel.fromProviderJson(Map<String, dynamic> json) {
    final locations = json['order_locations'] as List<dynamic>?;
    String? address;
    if (locations != null && locations.isNotEmpty) {
      address = (locations.first as Map<String, dynamic>)['address'] as String?;
    }
    return OrderModel(
      id: json['id'] as String,
      status: json['status'] as String? ?? 'pending',
      totalPrice: _parsePrice(json['total_price']),
      description: json['description'] as String?,
      workDate: json['work_date'] != null ? DateTime.tryParse(json['work_date'] as String) : null,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      customerName: (json['profiles_customer'] as Map<String, dynamic>?)?['full_name'] as String?,
      address: address,
    );
  }

  String get statusLabel {
    switch (status) {
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
