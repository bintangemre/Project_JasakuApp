import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/provider_profile_repository.dart';

class ProfileState {
  final bool isLoading;
  final String? error;

  final String? fullName;
  final String? nickname;
  final String? profilePhoto;
  final String? email;
  final String? phone;
  final String? gender;
  final String? birthDate;
  final String? address;
  final String? domicile;
  final bool isVerified;
  final String verificationStatus;
  final double rating;
  final int totalJobs;
  final int totalReviews;
  final bool isActive;
  final int servicesCount;
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> payoutMethods;
  final List<String> portfolios;

  const ProfileState({
    this.isLoading = true,
    this.error,
    this.fullName,
    this.nickname,
    this.profilePhoto,
    this.email,
    this.phone,
    this.gender,
    this.birthDate,
    this.address,
    this.domicile,
    this.isVerified = false,
    this.verificationStatus = '',
    this.rating = 0,
    this.totalJobs = 0,
    this.totalReviews = 0,
    this.isActive = true,
    this.servicesCount = 0,
    this.services = const [],
    this.payoutMethods = const [],
    this.portfolios = const [],
  });

  ProfileState copyWith({
    bool? isLoading,
    String? error,
    String? fullName,
    String? nickname,
    String? profilePhoto,
    String? email,
    String? phone,
    String? gender,
    String? birthDate,
    String? address,
    String? domicile,
    bool? isVerified,
    String? verificationStatus,
    double? rating,
    int? totalJobs,
    int? totalReviews,
    bool? isActive,
    int? servicesCount,
    List<Map<String, dynamic>>? services,
    List<Map<String, dynamic>>? payoutMethods,
    List<String>? portfolios,
  }) {
    return ProfileState(
      isLoading: isLoading ?? false,
      error: error,
      fullName: fullName ?? this.fullName,
      nickname: nickname ?? this.nickname,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      address: address ?? this.address,
      domicile: domicile ?? this.domicile,
      isVerified: isVerified ?? this.isVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      rating: rating ?? this.rating,
      totalJobs: totalJobs ?? this.totalJobs,
      totalReviews: totalReviews ?? this.totalReviews,
      isActive: isActive ?? this.isActive,
      servicesCount: servicesCount ?? this.servicesCount,
      services: services ?? this.services,
      payoutMethods: payoutMethods ?? this.payoutMethods,
      portfolios: portfolios ?? this.portfolios,
    );
  }

  bool get isVerificationPending => verificationStatus == 'pending';
  bool get isVerificationRejected => verificationStatus == 'rejected';
}

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier();
});

class ProfileNotifier extends StateNotifier<ProfileState> {
  ProfileNotifier() : super(const ProfileState());
  final _repo = ProviderProfileRepository();

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _repo.getFullProfile();
      state = ProfileState(
        isLoading: false,
        fullName: data['full_name'] as String?,
        nickname: data['nickname'] as String?,
        profilePhoto: data['profile_photo'] as String?,
        email: data['email'] as String?,
        phone: data['phone'] as String?,
        gender: data['gender'] as String?,
        birthDate: data['birth_date'] as String?,
        address: data['address'] as String?,
        domicile: data['domicile'] as String?,
        isVerified: data['is_verified'] as bool? ?? false,
        verificationStatus: data['verification_status'] as String? ?? '',
        rating: (data['rating'] as num?)?.toDouble() ?? 0,
        totalJobs: (data['total_jobs'] as num?)?.toInt() ?? 0,
        totalReviews: (data['total_reviews'] as num?)?.toInt() ?? 0,
        isActive: data['is_active'] as bool? ?? true,
        servicesCount: (data['services_count'] as num?)?.toInt() ?? 0,
        services: (data['services'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
                .toList() ??
            [],
        payoutMethods: (data['payout_methods'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
                .toList() ??
            [],
        portfolios: (data['portfolios'] as List?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> updateProfile({
    String? fullName,
    String? nickname,
    String? gender,
    String? birthDate,
    String? phone,
    String? address,
    String? domicile,
    String? profilePhotoPath,
    List<String>? portfolios,
    List<File>? newPortfolioFiles,
  }) async {
    try {
      await _repo.updateProfile(
        fullName: fullName,
        nickname: nickname,
        gender: gender,
        birthDate: birthDate,
        phone: phone,
        address: address,
        domicile: domicile,
        profilePhotoPath: profilePhotoPath,
        portfolios: portfolios,
        newPortfolioFiles: newPortfolioFiles,
      );
      await loadProfile();
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }
}
