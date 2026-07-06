import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/presentation/pages/customer_order_list_page.dart';
import '../../../reports/presentation/pages/report_form_page.dart';
import '../../../reports/presentation/pages/report_history_page.dart';
import 'customer_edit_info_page.dart';
import '../providers/customer_profile_provider.dart';

class CustomerProfile extends ConsumerStatefulWidget {
  const CustomerProfile({super.key});

  @override
  ConsumerState<CustomerProfile> createState() => _CustomerProfileState();
}

class _CustomerProfileState extends ConsumerState<CustomerProfile> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(customerProfileProvider.notifier).fetchProfile();
    });
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final file =
        await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (file == null) return;
    final err =
        await ref.read(customerProfileProvider.notifier).uploadAvatar(file.path);
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.user?.id != next.user?.id && next.user != null) {
        Future.microtask(() {
          ref.read(customerProfileProvider.notifier).fetchProfile();
        });
      }
    });
    final profileState = ref.watch(customerProfileProvider);
    final authState = ref.watch(authProvider);
    final profile = profileState.data;
    final profileData = profile?.profile;
    final displayName = profileData?.fullName ?? authState.user?.displayName ?? 'Customer';
    final email = profile?.email ?? authState.user?.email ?? '-';
    final phone = profile?.phone ?? '-';
    final nickname = profileData?.nickname;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profil Saya'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
      ),
      body: profileState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : profileState.error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded,
                            size: 64, color: AppColors.textHint),
                        const SizedBox(height: 16),
                        const Text('Gagal memuat profil',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(profileState.error!,
                            textAlign: TextAlign.center,
                            style:
                                const TextStyle(color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () =>
                              ref.read(customerProfileProvider.notifier).fetchProfile(),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildProfileCard(displayName, email, nickname),
                      const SizedBox(height: 16),
                      _buildInfoAkun(email, phone),
                      const SizedBox(height: 20),
                      _buildMenuSection(),
                      const SizedBox(height: 20),
                      _buildLogout(),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileCard(String name, String email, String? nickname) {
    final profileState = ref.watch(customerProfileProvider);
    final data = profileState.data?.profile;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: data?.avatarUrl != null
                      ? NetworkImage(
                          '${ApiEndpoints.baseUrl}${data!.avatarUrl}')
                      : null,
                  child: data?.avatarUrl == null
                      ? const Icon(Icons.person_rounded,
                          size: 48, color: AppColors.textHint)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickAndUploadAvatar,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: profileState.isSaving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.camera_alt_rounded,
                              size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (nickname != null && nickname.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '@$nickname',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              email,
              style: const TextStyle(
                color: AppColors.textHint,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoAkun(String email, String phone) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final changed = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const CustomerEditInfoPage()),
          );
          if (changed == true && mounted) {
            ref.read(customerProfileProvider.notifier).fetchProfile();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.person_outline, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Info Akun',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Column(
        children: [
          _menuTile(
            icon: Icons.receipt_long_outlined,
            color: AppColors.primary,
            title: 'Riwayat Pesanan',
            subtitle: 'Lihat pesanan yang sudah selesai',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CustomerOrderListPage()),
              );
            },
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),
          _menuTile(
            icon: Icons.shield_outlined,
            color: Colors.orange,
            title: 'Laporkan Masalah',
            subtitle: 'Laporkan bug, pembayaran, atau pesanan palsu',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReportFormPage()),
              );
            },
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),
          _menuTile(
            icon: Icons.history_outlined,
            color: AppColors.success,
            title: 'Riwayat Laporan',
            subtitle: 'Cek status laporan yang sudah dikirim',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReportHistoryPage()),
              );
            },
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),
          _menuTile(
            icon: Icons.info_outline,
            color: AppColors.textSecondary,
            title: 'Tentang Aplikasi',
            subtitle: 'Versi 1.0.0 · Jasaku',
            onTap: _showAboutApp,
          ),
        ],
      ),
    );
  }

  void _showAboutApp() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tentang Jasaku'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Jasaku',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Aplikasi jasa home-service untuk kebutuhan harianmu.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            SizedBox(height: 16),
            Text('Versi: 1.0.0'),
            SizedBox(height: 4),
            Text('© 2026 Jasaku Apps'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle,
          style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildLogout() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          ref.read(authProvider.notifier).logout();
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        },
        icon: const Icon(Icons.logout_rounded, color: AppColors.error),
        label: const Text('Logout',
            style: TextStyle(color: AppColors.error)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.error),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
