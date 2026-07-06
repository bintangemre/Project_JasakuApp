class CustomerProfileModel {
  final String id;
  final String email;
  final String? phone;
  final CustomerProfileData? profile;

  CustomerProfileModel({
    required this.id,
    required this.email,
    this.phone,
    this.profile,
  });

  factory CustomerProfileModel.fromJson(Map<String, dynamic> json) {
    return CustomerProfileModel(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      profile: json['profiles_customer'] != null
          ? CustomerProfileData.fromJson(json['profiles_customer'] as Map<String, dynamic>)
          : null,
    );
  }
}

class CustomerProfileData {
  final String id;
  final String fullName;
  final String? nickname;
  final String? birthDate;
  final String? gender;
  final String? address;
  final String? avatarUrl;

  CustomerProfileData({
    required this.id,
    required this.fullName,
    this.nickname,
    this.birthDate,
    this.gender,
    this.address,
    this.avatarUrl,
  });

  factory CustomerProfileData.fromJson(Map<String, dynamic> json) {
    return CustomerProfileData(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? '',
      nickname: json['nickname'] as String?,
      birthDate: json['birth_date'] as String?,
      gender: json['gender'] as String?,
      address: json['address'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
