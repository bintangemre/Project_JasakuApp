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
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      stopOrder: json['stop_order'] as int? ?? 0,
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
      rating: (provider?['rating'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'accepted',
      payoutConfirmed: json['payout_confirmed'] as bool? ?? false,
      orderId: firstOrder?['id'] as String?,
      orderStatus: firstOrder?['status'] as String?,
      orderTotalPrice: (firstOrder?['total_price'] as num?)?.toDouble(),
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
  final String? orderId;
  final String? orderStatus;
  final double? totalPrice;
  final double? platformFee;
  final bool payoutConfirmed;

  CustomTaskModel({
    required this.id,
    required this.title,
    this.description,
    required this.budgetPerPerson,
    required this.requiredPeople,
    this.acceptedCount = 0,
    this.platformFeeRate = 5,
    this.address,
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
    this.orderId,
    this.orderStatus,
    this.totalPrice,
    this.platformFee,
    this.payoutConfirmed = false,
  });

  double get totalBudget => budgetPerPerson * requiredPeople;
  double get feeAmount => totalBudget * platformFeeRate / 100;
  double get totalPayable => totalBudget + feeAmount;
  int get slotsLeft => requiredPeople - acceptedCount;
  bool get isFull => acceptedCount >= requiredPeople;
  bool get isOpen => status == 'open';

  factory CustomTaskModel.fromJson(Map<String, dynamic> json) {
    final locs = json['task_locations'] as List<dynamic>?;
    final provs = json['task_providers'] as List<dynamic>?;

    return CustomTaskModel(
      id: json['task_id'] as String? ?? json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      budgetPerPerson: (json['budget_per_person'] as num?)?.toDouble() ?? 0,
      requiredPeople: json['required_people'] as int? ?? 1,
      acceptedCount: json['accepted_count'] as int? ?? 0,
      platformFeeRate: (json['platform_fee_rate'] as num?)?.toDouble() ?? 5,
      address: json['address'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      status: json['task_status'] as String? ?? json['status'] as String? ?? 'open',
      customerName: json['customer_name'] as String?,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      locations: locs?.map((e) => TaskLocationModel.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      providers: provs?.map((e) => TaskProviderModel.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      totalProviders: json['total_providers'] as int? ?? 0,
      completedCount: json['completed_count'] as int? ?? 0,
      tpId: json['tp_id'] as String?,
      tpStatus: json['tp_status'] as String?,
      orderId: json['order_id'] as String?,
      orderStatus: json['order_status'] as String?,
      totalPrice: (json['total_price'] as num?)?.toDouble(),
      platformFee: (json['platform_fee'] as num?)?.toDouble(),
      payoutConfirmed: json['payout_confirmed'] as bool? ?? false,
    );
  }
}
