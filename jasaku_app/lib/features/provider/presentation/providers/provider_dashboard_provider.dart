import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/provider_dashboard_repository.dart';
import 'package:intl/intl.dart';

class DashboardState {
  final bool isLoading;
  final String? error;

  // Profile
  final String? fullName;
  final String? nickname;
  final String? profilePhoto;
  final double rating;
  final int totalJobs;
  final int totalReviews;
  final bool isActive;
  final bool taskAvailable;
  final int servicesCount;

  // Orders
  final List<Map<String, dynamic>> orders;

  const DashboardState({
    this.isLoading = true,
    this.error,
    this.fullName,
    this.nickname,
    this.profilePhoto,
    this.rating = 0,
    this.totalJobs = 0,
    this.totalReviews = 0,
    this.isActive = true,
    this.taskAvailable = true,
    this.servicesCount = 0,
    this.orders = const [],
  });

  DashboardState copyWith({
    bool? isLoading,
    String? error,
    String? fullName,
    String? nickname,
    String? profilePhoto,
    double? rating,
    int? totalJobs,
    int? totalReviews,
    bool? isActive,
    bool? taskAvailable,
    int? servicesCount,
    List<Map<String, dynamic>>? orders,
  }) {
    return DashboardState(
      isLoading: isLoading ?? false,
      error: error,
      fullName: fullName ?? this.fullName,
      nickname: nickname ?? this.nickname,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      rating: rating ?? this.rating,
      totalJobs: totalJobs ?? this.totalJobs,
      totalReviews: totalReviews ?? this.totalReviews,
      isActive: isActive ?? this.isActive,
      taskAvailable: taskAvailable ?? this.taskAvailable,
      servicesCount: servicesCount ?? this.servicesCount,
      orders: orders ?? this.orders,
    );
  }

  Map<String, dynamic>? get activeOrder {
    try {
      return orders.firstWhere(
        (o) => ['accepted', 'on_the_way', 'arrived', 'in_progress'].contains(o['status']),
      );
    } catch (_) {
      return null;
    }
  }

  int get pendingOrdersCount {
    return orders.where((o) => o['status'] == 'pending').length;
  }

  int get completedOrdersCount {
    return orders.where((o) => o['status'] == 'completed').length;
  }

  double get monthlyEarnings {
    final now = DateTime.now();
    final formatter = DateFormat('yyyy-MM');
    final thisMonth = formatter.format(now);
    double total = 0;
    for (final order in orders) {
      if (order['status'] == 'completed') {
        final createdAt = order['created_at'] as String?;
        if (createdAt != null && createdAt.length >= 7) {
          final orderMonth = createdAt.substring(0, 7);
          if (orderMonth == thisMonth) {
            total += _parsePriceDouble(order['total_price']);
          }
        }
      }
    }
    return total;
  }

  static double _parsePriceDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  double get performance {
    if (totalJobs == 0) return 0;
    final completed = orders.where((o) => o['status'] == 'completed').length;
    return (completed / orders.length) * 100;
  }
}

final dashboardProvider = StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier();
});

class DashboardNotifier extends StateNotifier<DashboardState> {
  DashboardNotifier() : super(const DashboardState());
  final _repo = ProviderDashboardRepository();

  Future<void> loadDashboard() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _repo.getProfile(),
        _repo.getOrders(),
      ]);

      final profile = results[0] as Map<String, dynamic>;
      final orders = results[1] as List<Map<String, dynamic>>;

      state = DashboardState(
        isLoading: false,
        fullName: profile['full_name'] as String?,
        nickname: profile['nickname'] as String?,
        profilePhoto: profile['profile_photo'] as String?,
        rating: (profile['rating'] as num?)?.toDouble() ?? 0,
        totalJobs: (profile['total_jobs'] as num?)?.toInt() ?? 0,
        totalReviews: (profile['total_reviews'] as num?)?.toInt() ?? 0,
        isActive: profile['is_active'] as bool? ?? true,
        taskAvailable: profile['task_available'] as bool? ?? true,
        servicesCount: (profile['services_count'] as num?)?.toInt() ?? 0,
        orders: orders,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> toggleAvailability() async {
    try {
      final newStatus = await _repo.toggleAvailability();
      state = state.copyWith(isActive: newStatus);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> toggleTaskAvailability() async {
    try {
      final newStatus = await _repo.toggleTaskAvailability();
      state = state.copyWith(taskAvailable: newStatus);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}
