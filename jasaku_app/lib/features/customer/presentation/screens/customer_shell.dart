import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'customer_home.dart';
import 'customer_notifications_page.dart';
import 'customer_profile.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../orders/presentation/pages/customer_order_list_page.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../notifications/data/services/fcm_manager.dart';
import '../../../custom_tasks/presentation/pages/task_detail_page.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

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
    FcmManager.onForegroundMessage = _onForegroundMessage;
    _reRegisterFcm();
    _restoreUserIfNeeded();
  }

  Future<void> _reRegisterFcm() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await ApiClient().dio.post(ApiEndpoints.registerDevice, data: {
          'fcmToken': token,
          'deviceType': 'android',
        });
        debugPrint('[FCM] CustomerShell device registered OK');
      }
    } catch (e) {
      debugPrint('[FCM] CustomerShell register FAILED: $e');
    }
  }

  Future<void> _restoreUserIfNeeded() async {
    final authState = ref.read(authProvider);
    if (authState.user != null) return;
    try {
      final response = await ApiClient().dio.get(
        '${ApiEndpoints.baseUrl}/api/auth/me',
      );
      final body = response.data;
      if (body is Map<String, dynamic>) {
        final meData = body['data'] as Map<String, dynamic>?;
        if (meData != null && mounted) {
          ref.read(authProvider.notifier).restoreSession(meData);
        }
      }
    } catch (_) {}
  }

  void _onForegroundMessage(RemoteMessage msg) {
    final type = msg.data['type'] ?? '';
    if (type == 'EXTENSION_REQUEST') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ada permintaan perpanjangan waktu baru'),
          action: SnackBarAction(
            label: 'Lihat',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CustomerNotificationsPage()),
              );
            },
          ),
        ),
      );
    }
    if (type == 'ORDER_ACCEPTED' || type == 'ORDER_CANCELLED' ||
        type == 'ON_THE_WAY' || type == 'ARRIVED' || type == 'IN_PROGRESS' ||
        type == 'COMPLETED' || type == 'PAYMENT_SUCCESS' || type == 'PAYMENT_FAILED' ||
        type == 'EXTENSION_ACTIVATED' || type == 'EXTENSION_REJECTED' ||
        type == 'CUSTOM_TASK_ACCEPTED' || type == 'CUSTOM_TASK_COMPLETED' ||
        type == 'PAYMENT_CONFIRMED' || type == 'CUSTOM_TASK_WORK_STATUS' ||
        type == 'CUSTOM_TASK_REPUBLISHED' || type == 'CUSTOM_TASK_PAYMENT_CONFIRMED') {
      ref.invalidate(customerHomeOrdersProvider);
    }
  }

  void _handleNotificationTap(String type, Map<String, String> data) {
    if (!mounted) return;
    ref.invalidate(customerHomeOrdersProvider);
    switch (type) {
      case 'NEW_CUSTOM_TASK':
      case 'CUSTOM_TASK_ACCEPTED':
      case 'CUSTOM_TASK_COMPLETED':
      case 'CUSTOM_TASK_WORK_STATUS':
      case 'CUSTOM_TASK_REPUBLISHED':
      case 'CUSTOM_TASK_PAYMENT_CONFIRMED':
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
      case 'PAYMENT_CONFIRMED':
      case 'EXTENSION_REQUEST':
      case 'EXTENSION_ACTIVATED':
      case 'EXTENSION_REJECTED':
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
      ref.invalidate(customerHomeOrdersProvider);
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
