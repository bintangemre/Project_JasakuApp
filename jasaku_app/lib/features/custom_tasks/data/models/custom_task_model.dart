double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int _toInt(dynamic v, {int fallback = 0}) {
  if (v == null) return fallback;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? fallback;
}

DateTime _parseDateTime(dynamic v) {
  if (v == null) return DateTime.now();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
  return DateTime.now();
}

DateTime? _parseDateTimeNullable(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

class TaskLocationModel {
  final String id;
  final String? label;
  final String address;
  final double? lat;
  final double? lng;
  final int stopOrder;

  TaskLocationModel({
    required this.id,
    this.label,
    required this.address,
    this.lat,
    this.lng,
    this.stopOrder = 0,
  });

  factory TaskLocationModel.fromJson(Map<String, dynamic> json) {
    return TaskLocationModel(
      id: json['id'] as String? ?? '',
      label: json['label'] as String?,
      address: json['address'] as String? ?? '',
      lat: _toDouble(json['lat']),
      lng: _toDouble(json['lng']),
      stopOrder: _toInt(json['stop_order']),
    );
  }
}

class TaskProviderModel {
  final String id;
  final String? fullName;
  final String? profilePhoto;
  final double? rating;
  final String status;
  final bool payoutConfirmed;
  final String? orderId;
  final String? orderStatus;
  final double? orderTotalPrice;

  TaskProviderModel({
    required this.id,
    this.fullName,
    this.profilePhoto,
    this.rating,
    required this.status,
    this.payoutConfirmed = false,
    this.orderId,
    this.orderStatus,
    this.orderTotalPrice,
  });

  factory TaskProviderModel.fromJson(Map<String, dynamic> json) {
    final provider = json['provider_profiles'] as Map<String, dynamic>?;
    final order = json['orders'] as List<dynamic>?;
    final firstOrder = order?.isNotEmpty == true ? order![0] as Map<String, dynamic> : null;
    return TaskProviderModel(
      id: json['id'] as String? ?? '',
      fullName: provider?['full_name'] as String?,
      profilePhoto: provider?['profile_photo'] as String?,
      rating: _toDouble(provider?['rating']),
      status: json['status'] as String? ?? 'accepted',
      payoutConfirmed: json['payout_confirmed'] as bool? ?? false,
      orderId: firstOrder?['id'] as String?,
      orderStatus: firstOrder?['status'] as String?,
      orderTotalPrice: _toDouble(firstOrder?['total_price']),
    );
  }
}

class CustomTaskModel {
  final String id;
  final String title;
  final String? description;
  final double budgetPerPerson;
  final int requiredPeople;
  final int acceptedCount;
  final double platformFeeRate;
  final String? address;
  final String? locationDetail;
  final int publishDays;
  final DateTime? expiresAt;
  final String? paymentProof;
  final String paymentStatus;
  final double? lat;
  final double? lng;
  final String status;
  final String? customerName;
  final double? distanceMeters;
  final DateTime createdAt;
  final List<TaskLocationModel> locations;
  final List<TaskProviderModel> providers;
  final int totalProviders;
  final int completedCount;
  final String? tpId;
  final String? tpStatus;
  final String? workStatus;
  final String? orderId;
  final String? orderStatus;
  final double? totalPrice;
  final double? platformFee;
  final bool payoutConfirmed;
  final List<String> images;

  CustomTaskModel({
    required this.id,
    required this.title,
    this.description,
    required this.budgetPerPerson,
    required this.requiredPeople,
    this.acceptedCount = 0,
    this.platformFeeRate = 5,
    this.address,
    this.locationDetail,
    this.publishDays = 1,
    this.expiresAt,
    this.paymentProof,
    this.paymentStatus = 'unpaid',
    this.lat,
    this.lng,
    this.status = 'open',
    this.customerName,
    this.distanceMeters,
    required this.createdAt,
    this.locations = const [],
    this.providers = const [],
    this.totalProviders = 0,
    this.completedCount = 0,
    this.tpId,
    this.tpStatus,
    this.workStatus,
    this.orderId,
    this.orderStatus,
    this.totalPrice,
    this.platformFee,
    this.payoutConfirmed = false,
    this.images = const [],
  });

  double get totalBudget => budgetPerPerson * requiredPeople;
  double get feeAmount => totalBudget * platformFeeRate / 100;
  double get totalPayable => totalBudget + feeAmount;
  int get slotsLeft => requiredPeople - acceptedCount;
  bool get isFull => acceptedCount >= requiredPeople;
  bool get isOpen => status == 'open';
  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());

  factory CustomTaskModel.fromJson(Map<String, dynamic> json) {
    final locs = json['task_locations'] as List<dynamic>?;
    final provs = json['task_providers'] as List<dynamic>?;

    return CustomTaskModel(
      id: json['task_id'] as String? ?? json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      budgetPerPerson: _toDouble(json['budget_per_person']) ?? 0,
      requiredPeople: _toInt(json['required_people'], fallback: 1),
      acceptedCount: _toInt(json['accepted_count']),
      platformFeeRate: _toDouble(json['platform_fee_rate']) ?? 5,
      address: json['address'] as String?,
      locationDetail: json['location_detail'] as String?,
      publishDays: _toInt(json['publish_days'], fallback: 1),
      expiresAt: _parseDateTimeNullable(json['expires_at']),
      paymentProof: json['payment_proof'] as String?,
      paymentStatus: json['payment_status'] as String? ?? 'unpaid',
      lat: _toDouble(json['lat']),
      lng: _toDouble(json['lng']),
      status: json['task_status'] as String? ?? json['status'] as String? ?? 'open',
      customerName: json['customer_name'] as String?,
      distanceMeters: _toDouble(json['distance_meters']),
      createdAt: _parseDateTime(json['created_at']),
      locations: locs?.map((e) => TaskLocationModel.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      providers: provs?.map((e) => TaskProviderModel.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      totalProviders: _toInt(json['total_providers']),
      completedCount: _toInt(json['completed_count']),
      tpId: json['tp_id'] as String?,
      tpStatus: json['tp_status'] as String?,
      workStatus: json['work_status'] as String?,
      orderId: json['order_id'] as String?,
      orderStatus: json['order_status'] as String?,
      totalPrice: _toDouble(json['total_price']),
      platformFee: _toDouble(json['platform_fee']),
      payoutConfirmed: json['payout_confirmed'] as bool? ?? false,
      images: (json['images'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

class AdminAccountModel {
  final String id;
  final String type;
  final String accountName;
  final String accountNumber;
  final String providerName;
  final String? qrisImageUrl;

  AdminAccountModel({
    required this.id,
    required this.type,
    required this.accountName,
    required this.accountNumber,
    required this.providerName,
    this.qrisImageUrl,
  });

  factory AdminAccountModel.fromJson(Map<String, dynamic> json) {
    return AdminAccountModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      accountName: json['account_name'] as String? ?? '',
      accountNumber: json['account_number'] as String? ?? '',
      providerName: json['provider_name'] as String? ?? '',
      qrisImageUrl: json['qris_image_url'] as String?,
    );
  }
}

class PaymentDetailModel {
  final String taskId;
  final String title;
  final int acceptedCount;
  final int requiredPeople;
  final double budgetPerPerson;
  final double feePerPerson;
  final double totalAmount;
  final String paymentStatus;
  final String? paymentProof;
  final List<AdminAccountModel> adminAccounts;

  PaymentDetailModel({
    required this.taskId,
    required this.title,
    required this.acceptedCount,
    required this.requiredPeople,
    required this.budgetPerPerson,
    required this.feePerPerson,
    required this.totalAmount,
    required this.paymentStatus,
    this.paymentProof,
    this.adminAccounts = const [],
  });

  factory PaymentDetailModel.fromJson(Map<String, dynamic> json) {
    final accounts = json['admin_accounts'] as List<dynamic>?;
    return PaymentDetailModel(
      taskId: json['task_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      acceptedCount: _toInt(json['accepted_count']),
      requiredPeople: _toInt(json['required_people']),
      budgetPerPerson: _toDouble(json['budget_per_person']) ?? 0,
      feePerPerson: _toDouble(json['fee_per_person']) ?? 0,
      totalAmount: _toDouble(json['total_amount']) ?? 0,
      paymentStatus: json['payment_status'] as String? ?? 'unpaid',
      paymentProof: json['payment_proof'] as String?,
      adminAccounts: accounts
              ?.map((e) => AdminAccountModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
