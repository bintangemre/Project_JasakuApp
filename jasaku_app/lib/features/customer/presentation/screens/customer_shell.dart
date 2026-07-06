import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'customer_home.dart';
import 'customer_profile.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../orders/presentation/pages/customer_order_list_page.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../notifications/data/services/fcm_manager.dart';
import '../../../custom_tasks/presentation/pages/task_detail_page.dart';

class CustomerShell extends ConsumerStatefulWidget {
  const CustomerShell({super.key});

  @override
  ConsumerState<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends ConsumerState<CustomerShell> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const CustomerHome(),
    const CustomerOrderListPage(),
    const CustomerProfile(),
  ];

  @override
  void initState() {
    super.initState();
    FcmManager.onNotificationTap = _handleNotificationTap;
  }

  void _handleNotificationTap(String type, Map<String, String> data) {
    if (!mounted) return;
    switch (type) {
      case 'CUSTOM_TASK_BID':
      case 'NEW_CUSTOM_TASK':
      case 'CUSTOM_TASK_ACCEPTED':
      case 'CUSTOM_TASK_COMPLETED':
        final taskId = data['taskId'] ?? '';
        if (taskId.isNotEmpty) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TaskDetailPage(taskId: taskId),
            ),
          );
        }
        break;
      case 'NEW_ORDER':
      case 'ORDER_ACCEPTED':
      case 'ORDER_REJECTED':
      case 'ON_THE_WAY':
      case 'ARRIVED':
      case 'IN_PROGRESS':
      case 'COMPLETED':
      case 'ORDER_CANCELLED':
      case 'PAYMENT_SUCCESS':
      case 'PAYMENT_FAILED':
        setState(() => _selectedIndex = 1);
        ref.read(unreadNotifProvider.notifier).state = 0;
        break;
    }
  }

  void _onTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 1) {
      ref.read(unreadNotifProvider.notifier).state = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(unreadNotifProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textHint,
        type: BottomNavigationBarType.fixed,
        onTap: _onTap,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home_rounded), label: 'Beranda'),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount > 9 ? '9+' : '$unreadCount'),
              child: const Icon(Icons.access_time_outlined),
            ),
            activeIcon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount > 9 ? '9+' : '$unreadCount'),
              child: const Icon(Icons.access_time_rounded),
            ),
            label: 'Pesanan',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: 'Profil'),
        ],
      ),
    );
  }
}
