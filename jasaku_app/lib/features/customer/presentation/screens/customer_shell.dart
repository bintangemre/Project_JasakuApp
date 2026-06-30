import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/customer_home.dart';
import '../../../orders/presentation/pages/customer_order_list_page.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';

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
    const _PlaceholderPage(icon: Icons.chat_bubble_outline, label: 'Chat'),
  ];

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
      backgroundColor: const Color(0xFFF5F7FB),
      body: SafeArea(child: _pages[_selectedIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF2563EB),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: _onTap,
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Beranda'),
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount > 9 ? '9+' : '$unreadCount'),
              child: const Icon(Icons.access_time_outlined),
            ),
            activeIcon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text(unreadCount > 9 ? '9+' : '$unreadCount'),
              child: const Icon(Icons.access_time),
            ),
            label: 'Pesanan',
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'Chat'),
        ],
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PlaceholderPage({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
        ],
      ),
    );
  }
}
