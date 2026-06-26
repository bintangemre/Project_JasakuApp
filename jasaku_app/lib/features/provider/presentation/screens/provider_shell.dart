import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'provider_dashboard.dart'; // Impor halaman beranda mitra di bawah

// Placeholder halaman lain agar tidak error saat dipanggil di shell
class ProviderRequestsPage extends StatelessWidget { const ProviderRequestsPage({super.key}); @override Widget build(BuildContext context) => const Center(child: Text("Halaman Permintaan")); }
class ProviderHistoryPage extends StatelessWidget { const ProviderHistoryPage({super.key}); @override Widget build(BuildContext context) => const Center(child: Text("Halaman Riwayat")); }
class ProviderProfilePage extends StatelessWidget { const ProviderProfilePage({super.key}); @override Widget build(BuildContext context) => const Center(child: Text("Halaman Profil")); }

class ProviderShell extends ConsumerStatefulWidget {
  const ProviderShell({super.key});

  @override
  ConsumerState<ProviderShell> createState() => _ProviderShellState();
}

class _ProviderShellState extends ConsumerState<ProviderShell> {
  int _selectedIndex = 0;

  // List halaman disesuaikan dengan menu BottomNavigationBar Mitra
  static const List<Widget> _pages = [
    ProviderHomePage(), // Tab 0
    ProviderRequestsPage(),  // Tab 1
    ProviderHistoryPage(),   // Tab 2
    ProviderProfilePage(),   // Tab 3
  ];

  void _onTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _pages[_selectedIndex]),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF00A651), // Warna hijau khas mitra
        unselectedItemColor: const Color(0xFF94A3B8), // Slate grey agar clean
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        onTap: _onTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Beranda',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_toggle_off),
            label: 'Permintaan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            label: 'Riwayat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}