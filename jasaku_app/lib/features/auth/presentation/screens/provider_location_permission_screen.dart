import 'package:flutter/material.dart';
import '../../../../services/location_service.dart';

class ProviderLocationPermissionScreen extends StatefulWidget {
  const ProviderLocationPermissionScreen({super.key});

  @override
  State<ProviderLocationPermissionScreen> createState() =>
      _ProviderLocationPermissionScreenState();
}

class _ProviderLocationPermissionScreenState
    extends State<ProviderLocationPermissionScreen> {
  bool _isLoading = false;
  bool _isLocationEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkLocationService();
  }

  Future<void> _checkLocationService() async {
    final isEnabled =
        await LocationPermissionService.isLocationServiceEnabled();
    if (mounted) {
      setState(() => _isLocationEnabled = isEnabled);
    }
  }

  Future<void> _requestLocationPermission() async {
    setState(() => _isLoading = true);

    final hasPermission =
        await LocationPermissionService.requestLocationPermission();

    if (!mounted) return;

    if (hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Izin lokasi berhasil diberikan!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to next screen or home
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Izin lokasi ditolak. Anda dapat mengubahnya di pengaturan.',
          ),
          backgroundColor: Colors.orange,
        ),
      );

      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0F766E).withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  size: 50,
                  color: Color(0xFF0F766E),
                ),
              ),
              const SizedBox(height: 32),

              // Title
              const Text(
                'Aktifkan Akses Lokasi',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Subtitle
              const Text(
                'Kami memerlukan akses lokasi Anda untuk:',
                style: TextStyle(fontSize: 14, color: Color(0xFF7A7A7A)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              if (!_isLocationEnabled)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF1E0C9)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.location_off, color: Color(0xFFB45309)),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Layanan lokasi perangkat belum aktif. Silakan aktifkan GPS atau layanan lokasi di pengaturan.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Benefits List
              _buildBenefitItem(
                icon: Icons.assignment_turned_in,
                title: 'Tampilkan Profil Anda',
                subtitle: 'Agar pelanggan mudah menemukan lokasi Anda',
              ),
              const SizedBox(height: 16),
              _buildBenefitItem(
                icon: Icons.trending_up,
                title: 'Tingkatkan Rating',
                subtitle: 'Lokasi terdekat mendapat prioritas pencarian',
              ),
              const SizedBox(height: 16),
              _buildBenefitItem(
                icon: Icons.notifications_active,
                title: 'Notifikasi Pesanan',
                subtitle: 'Terima pesanan dari area kerja Anda',
              ),
              const SizedBox(height: 40),

              // Request Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed:
                      _isLoading || !_isLocationEnabled
                          ? null
                          : _requestLocationPermission,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                            'Izinkan Akses Lokasi',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                ),
              ),
              const SizedBox(height: 12),

              // Skip Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed:
                      _isLoading
                          ? null
                          : () {
                            Navigator.pop(context, false);
                          },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Lewati untuk Sekarang',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFFFAFCFE),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF0F766E).withValues(alpha: 0.1),
            ),
            child: Icon(icon, color: const Color(0xFF0F766E), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7A7A7A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
