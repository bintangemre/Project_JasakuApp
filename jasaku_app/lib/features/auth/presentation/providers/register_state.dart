import 'dart:io';

class RegisterState {
  String phone = '';
  List<Map<String, dynamic>> selectedServices = [];
  String fullName = '';
  String nickname = '';
  String email = '';
  String password = '';
  String birthDate = '';
  String gender = '';
  String address = '';
  String domicile = '';
  String province = '';
  String city = '';
  String district = '';
  String village = '';
  String? profilePhotoPath;
  String? ktpPhotoPath;
  String? selfiePhotoPath;
  String? ijazahPhotoPath;
  List<Map<String, dynamic>> certificates = [];
  List<File> portfolioFiles = [];
  bool termsAgreed = false;

  // OCR KTP
  String? ocrNik;
  String? ocrFullName;
  String? ocrBirthPlace;
  String? ocrBirthDate;
  String? ocrAddress;
  String? ocrGender;
  String? ocrBloodType;
  String? ocrReligion;

  // Liveness
  Map<String, dynamic>? livenessData;
}
