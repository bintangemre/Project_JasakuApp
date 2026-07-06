import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'provider_dashboard.dart';
import 'provider_requests_page.dart';
import 'provider_profile_page.dart';
import '../providers/provider_dashboard_provider.dart';
import '../providers/provider_profile_provider.dart';
import '../../../orders/presentation/pages/provider_order_list_page.dart';
import '../../../notifications/data/services/fcm_manager.dart';
import '../../../custom_tasks/presentation/pages/provider_my_bids_page.dart';
import '../../../location/presentation/providers/location_tracker_provider.dart';
import '../../../admin/presentation/screens/admin_pending_extensions_page.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProviderShell extends ConsumerStatefulWidget {
  const ProviderShell({super.key});

  @override
  ConsumerState<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends ConsumerState<ProviderShell> {
  int _selectedIndex = 0;

  List<Widget> _pages(bool isAdmin) => [
        const ProviderHomePage(),
        const ProviderRequestsPage(),
        const ProviderOrderListPage(),
        const ProviderProfilePage(),
        if (isAdmin) const AdminPendingExtensionsPage(),
      ];

  @override
  void initState() {
    super.initState();
    FcmManager.onNotificationTap = _handleNotificationTap;
    ref.read(locationTrackerProvider.notifier).startTracking();
  }

  @override
  void dispose() {
    ref.read(locationTrackerProvider.notifier).stopTracking();
    super.dispose();
  }

  void _handleNotificationTap(String type, Map<String, String> data) {
    if (!mounted) return;
    switch (type) {
      case 'NEW_CUSTOM_TASK':
      case 'CUSTOM_TASK_ACCEPTED':
      case 'CUSTOM_TASK_COMPLETED':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ProviderMyBidsPage()),
        );
        break;
      case 'NEW_ORDER':
        setState(() => _selectedIndex = 1);
        break;
      case 'ORDER_CANCELLED':
      case 'PAYMENT_RECEIVED':
        setState(() => _selectedIndex = 2);
        break;
    }
  }

  void _onTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
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
    debugPrint('[ProviderShell] user role: ${authState.user?.role} isAdmin: $isAdmin');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(child: _pages(isAdmin)[_selectedIndex]),
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
          const BottomNavigationBarItem(icon: Icon(Icons.history_toggle_off), label: 'Permintaan'),
          const BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), label: 'Riwayat'),
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
          if (isAdmin)
            const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings), label: 'Admin'),
        ],
      ),
    );
  }
}
