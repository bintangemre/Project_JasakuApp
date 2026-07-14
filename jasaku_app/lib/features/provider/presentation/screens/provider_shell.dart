import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import 'provider_dashboard.dart';
import 'provider_requests_page.dart';
import 'provider_profile_page.dart';
import 'provider_order_management_page.dart';
import '../providers/provider_dashboard_provider.dart';
import '../providers/provider_profile_provider.dart';
import '../../../custom_tasks/presentation/pages/provider_my_bids_page.dart';
import '../../../location/presentation/providers/location_tracker_provider.dart';
import '../../../admin/presentation/screens/admin_pending_extensions_page.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/screens/provider_verification_pending_screen.dart';
import '../../../notifications/data/services/fcm_manager.dart';

final unreadProviderProvider = StateProvider<int>((ref) => 0);

class ProviderCounts {
  final int pendingRequests;
  final int todayOrders;
  final int upcomingOrders;
  final int availableTasks;
  final int myAcceptedTasks;

  const ProviderCounts({
    this.pendingRequests = 0,
    this.todayOrders = 0,
    this.upcomingOrders = 0,
    this.availableTasks = 0,
    this.myAcceptedTasks = 0,
  });
}

final providerCountsProvider = StateProvider<ProviderCounts>((ref) => const ProviderCounts());

class ProviderShell extends ConsumerStatefulWidget {
  const ProviderShell({super.key});

  @override
  ConsumerState<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends ConsumerState<ProviderShell> {
  int _selectedIndex = 0;
  Timer? _countsTimer;
  final Dio _dio = ApiClient().dio;

  List<Widget> _pages(bool isAdmin) => [
        const ProviderHomePage(),
        const ProviderRequestsPage(),
        const ProviderOrderManagementPage(),
        const ProviderProfilePage(),
        if (isAdmin) const AdminPendingExtensionsPage(),
      ];

  @override
  void initState() {
    super.initState();
    FcmManager.onNotificationTap = _handleNotificationTap;
    FcmManager.onForegroundMessage = _handleForegroundMessage;
    ref.read(locationTrackerProvider.notifier).startTracking();
    _fetchCounts();
    _countsTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchCounts());
  }

  @override
  void dispose() {
    _countsTimer?.cancel();
    ref.read(locationTrackerProvider.notifier).stopTracking();
    super.dispose();
  }

  Future<void> _fetchCounts() async {
    if (!mounted) return;
    try {
      final response = await _dio.get(ApiEndpoints.providerCounts);
      final data = response.data['data'] as Map<String, dynamic>;
      if (mounted) {
        ref.read(providerCountsProvider.notifier).state = ProviderCounts(
          pendingRequests: data['pendingRequests'] ?? 0,
          todayOrders: data['todayOrders'] ?? 0,
          upcomingOrders: data['upcomingOrders'] ?? 0,
          availableTasks: data['availableTasks'] ?? 0,
          myAcceptedTasks: data['myAcceptedTasks'] ?? 0,
        );
      }
    } catch (_) {}
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (!mounted) return;
    final data = message.data as Map<String, String>? ?? {};
    final type = data['type'] ?? '';
    if (type == 'NEW_ORDER' || type == 'NEW_CUSTOM_TASK' || type == 'CUSTOM_TASK_ACCEPTED' ||
        type == 'CUSTOM_TASK_PAYOUT_CONFIRMED' || type == 'NEW_REVIEW') {
      ref.read(unreadProviderProvider.notifier).state++;
    }
    if (type == 'PAYMENT_RECEIVED' || type == 'ORDER_CANCELLED' ||
        type == 'EXTENSION_APPROVED' || type == 'EXTENSION_REJECTED' ||
        type == 'EXTENSION_ACTIVATED' || type == 'NEW_ORDER' ||
        type == 'CUSTOM_TASK_ACCEPTED' || type == 'CUSTOM_TASK_COMPLETED' ||
        type == 'PROVIDER_VERIFIED' || type == 'PROVIDER_REJECTED' ||
        type == 'CUSTOM_TASK_PAYOUT_CONFIRMED' || type == 'CUSTOM_TASK_FULL') {
      ref.read(dashboardProvider.notifier).loadDashboard();
    }
  }

  void _handleNotificationTap(String type, Map<String, String> data) {
    if (!mounted) return;
    ref.read(unreadProviderProvider.notifier).state = 0;
    ref.read(dashboardProvider.notifier).loadDashboard();
    switch (type) {
      case 'NEW_CUSTOM_TASK':
      case 'CUSTOM_TASK_ACCEPTED':
      case 'CUSTOM_TASK_COMPLETED':
      case 'CUSTOM_TASK_FULL':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProviderMyBidsPage()),
        );
        break;
      case 'NEW_ORDER':
        setState(() => _selectedIndex = 1);
        break;
      case 'ORDER_CANCELLED':
      case 'PAYMENT_RECEIVED':
      case 'EXTENSION_APPROVED':
      case 'EXTENSION_REJECTED':
      case 'EXTENSION_ACTIVATED':
      case 'CUSTOM_TASK_PAYOUT_CONFIRMED':
        setState(() => _selectedIndex = 2);
        break;
      case 'PROVIDER_VERIFIED':
        ref.read(profileProvider.notifier).loadProfile();
        setState(() => _selectedIndex = 3);
        break;
      case 'PROVIDER_REJECTED':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProviderVerificationPendingScreen(status: 'rejected')),
        );
        break;
    }
  }

  void _onTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 1 || index == 2) {
      ref.read(unreadProviderProvider.notifier).state = 0;
    }
    if (index == 0) {
      _fetchCounts();
      Future.microtask(() => ref.read(dashboardProvider.notifier).loadDashboard());
    }
    if (index == 3) {
      Future.microtask(() => ref.read(profileProvider.notifier).loadProfile());
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isAdmin = authState.user?.isAdmin ?? false;
    final unreadCount = ref.watch(unreadProviderProvider);
    final counts = ref.watch(providerCountsProvider);
    debugPrint('[ProviderShell] user role: ${authState.user?.role} isAdmin: $isAdmin');

    final requestBadge = unreadCount > 0 ? unreadCount : counts.pendingRequests;
    final orderBadge = counts.todayOrders + counts.upcomingOrders;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(child: IndexedStack(
        index: _selectedIndex,
        children: _pages(isAdmin),
      )),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF00A651),
        unselectedItemColor: const Color(0xFF94A3B8),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        onTap: _onTap,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Beranda'),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _selectedIndex != 1 && requestBadge > 0,
              label: Text(requestBadge > 9 ? '9+' : '$requestBadge'),
              child: const Icon(Icons.history_toggle_off),
            ),
            label: 'Permintaan',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _selectedIndex != 2 && orderBadge > 0,
              label: Text(orderBadge > 9 ? '9+' : '$orderBadge'),
              child: const Icon(Icons.assignment_outlined),
            ),
            label: 'Orderan',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
          if (isAdmin)
            const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
        ],
      ),
    );
  }
}
