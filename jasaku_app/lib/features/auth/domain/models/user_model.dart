class UserModel {
  final String id;
  final String email;
  final String role;

  UserModel({
    required this.id,
    required this.email,
    required this.role,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id:    json['id'],
      email: json['email'],
      role:  json['role'],
    );
  }

  // Helper cek role
  bool get isAdmin    => role == 'admin';
  bool get isCustomer => role == 'customer';
  bool get isProvider => role == 'jasa';
}