import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'provider_dashboard.dart';
import 'provider_requests_page.dart';
import '../providers/provider_dashboard_provider.dart';
import '../../../orders/presentation/pages/provider_order_list_page.dart';

class ProviderProfilePage extends StatelessWidget {
  const ProviderProfilePage({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Text("Halaman Profil"));
}

class ProviderShell extends ConsumerStatefulWidget {
  const ProviderShell({super.key});

  @override
  ConsumerState<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends ConsumerState<ProviderShell> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const ProviderHomePage(),
    const ProviderRequestsPage(),
    const ProviderOrderListPage(),
    const ProviderProfilePage(),
  ];

  void _onTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 0) {
      Future.microtask(() => ref.read(dashboardProvider.notifier).loadDashboard());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(child: _pages[_selectedIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF00A651),
        unselectedItemColor: const Color(0xFF94A3B8),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.history_toggle_off), label: 'Permintaan'),
          BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), label: 'Riwayat'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}
