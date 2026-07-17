import 'package:intl/intl.dart';

class OrderAttachment {
  final String id;
  final String fileUrl;
  final DateTime? createdAt;

  OrderAttachment({required this.id, required this.fileUrl, this.createdAt});

  factory OrderAttachment.fromJson(Map<String, dynamic> json) {
    return OrderAttachment(
      id: json['id'] as String,
      fileUrl: json['file_url'] as String? ?? '',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }
}

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
  final List<OrderAttachment> attachments;
  final List<Map<String, dynamic>> items;

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
    this.attachments = const [],
    this.items = const [],
  });

  static int _parsePrice(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  factory OrderModel.fromCustomerJson(Map<String, dynamic> json) {
    final provider = json['provider_profiles'] as Map<String, dynamic>?;
    final attachments = (json['order_attachments'] as List<dynamic>?)
            ?.map((a) => OrderAttachment.fromJson(a as Map<String, dynamic>))
            .toList() ??
        [];
    final items = (json['order_items'] as List<dynamic>?)
            ?.map((i) => Map<String, dynamic>.from(i as Map))
            .toList() ??
        [];
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
      attachments: attachments,
      items: items,
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
    final attachments = (json['order_attachments'] as List<dynamic>?)
            ?.map((a) => OrderAttachment.fromJson(a as Map<String, dynamic>))
            .toList() ??
        [];
    final items = (json['order_items'] as List<dynamic>?)
            ?.map((i) => Map<String, dynamic>.from(i as Map))
            .toList() ??
        [];
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
      attachments: attachments,
      items: items,
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
      'total_price': totalPrice,
      'additional_fee': additionalFee,
      'description': description,
      'work_date': workDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'profiles_customer': {'full_name': customerName},
      'order_items': items,
      'order_attachments': attachments.map((a) => {'id': a.id, 'file_url': a.fileUrl, 'created_at': a.createdAt?.toIso8601String()}).toList(),
      'order_locations': [
        if (address != null || lat != null || lng != null)
          {'address': address, 'lat': lat?.toString(), 'lng': lng?.toString()},
      ],
    };
  }
}
