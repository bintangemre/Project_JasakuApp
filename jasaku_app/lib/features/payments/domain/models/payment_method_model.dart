class PaymentMethod {
  final String id;
  final String type;
  final String description;
  final String? accountName;
  final String? accountNumber;
  final String? providerName;
  final String? qrisImageUrl;
  final String icon;

  PaymentMethod({
    required this.id,
    required this.type,
    required this.description,
    this.accountName,
    this.accountNumber,
    this.providerName,
    this.qrisImageUrl,
    this.icon = 'money',
  });

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] as String,
      type: json['type'] as String,
      description: json['description'] as String? ?? '',
      accountName: json['account_name'] as String?,
      accountNumber: json['account_number'] as String?,
      providerName: json['provider_name'] as String?,
      qrisImageUrl: json['qris_image_url'] as String?,
      icon: json['icon'] as String? ?? 'money',
    );
  }
}

class PayoutMethod {
  final String id;
  final String type;
  final String providerName;
  final String accountNumber;
  final String accountName;

  PayoutMethod({
    required this.id,
    required this.type,
    required this.providerName,
    required this.accountNumber,
    required this.accountName,
  });

  factory PayoutMethod.fromJson(Map<String, dynamic> json) {
    return PayoutMethod(
      id: json['id'] as String,
      type: json['type'] as String,
      providerName: json['provider_name'] as String? ?? '',
      accountNumber: json['account_number'] as String? ?? '',
      accountName: json['account_name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'provider_name': providerName,
    'account_number': accountNumber,
    'account_name': accountName,
  };
}
