// Model user yang menyimpan informasi role dan menyediakan helper isCustomer/isProvider.
class UserModel {
  final String id;
  final String email;
  final String role;
  final String? name;

  UserModel({
    required this.id,
    required this.email,
    required this.role,
    this.name,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final name =
        json['name'] as String? ??
        json['full_name'] as String? ??
        json['fullName'] as String?;

    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      name: name,
    );
  }

  String get displayName => name ?? email;

  bool get isAdmin => role == 'admin';
  bool get isCustomer => role == 'customer';
  bool get isProvider => role == 'provider';
}
