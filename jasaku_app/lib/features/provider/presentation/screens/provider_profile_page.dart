import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/provider_profile_provider.dart';
import '../../../payments/presentation/screens/provider_payout_screen.dart';
import 'provider_profile_edit_screen.dart';
import 'provider_reviews_page.dart';
import 'provider_services_edit_screen.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/utils/image_url.dart';
import '../../../reports/presentation/pages/report_form_page.dart';
import '../../../reports/presentation/pages/report_history_page.dart';
import '../../../orders/presentation/pages/provider_order_list_page.dart';

class ProviderProfilePage extends ConsumerStatefulWidget {
  const ProviderProfilePage({super.key});

  @override
  ConsumerState<ProviderProfilePage> createState() =>
      _ProviderProfilePageState();
}

class _ProviderProfilePageState extends ConsumerState<ProviderProfilePage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(profileProvider.notifier).loadProfile());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 16),
            Text('Gagal memuat profil', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              state.error!,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(profileProvider.notifier).loadProfile(),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(profileProvider.notifier).loadProfile(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(state, theme, cs),
            const SizedBox(height: 20),
            _buildVerificationStatus(state, cs),
            const SizedBox(height: 20),
            _buildStats(state, cs),
            const SizedBox(height: 20),
            _buildInfoSection(state, theme, cs),
            const SizedBox(height: 16),
            _buildServicesSection(state, theme, cs),
            if (state.portfolios.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildPortfolioSection(state, theme, cs),
            ],
            const SizedBox(height: 16),
            _buildPayoutLink(theme, cs),
            const SizedBox(height: 16),
            _buildReportSection(theme, cs),
            const SizedBox(height: 16),
            _buildOrderManagement(theme, cs),
            const SizedBox(height: 16),
            _buildEditButton(theme, cs),
            const SizedBox(height: 12),
            _buildLogoutButton(theme, cs),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ProfileState state, ThemeData theme, ColorScheme cs) {
    return Row(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundImage:
              state.profilePhoto != null
                  ? NetworkImage(
                    imageUrl(state.profilePhoto),
                  )
                  : null,
          backgroundColor: cs.primaryContainer.withValues(alpha: 0.5),
          child:
              state.profilePhoto == null
                  ? Icon(Icons.person, size: 40, color: cs.primary)
                  : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.fullName ?? 'Mitra',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (state.nickname != null && state.nickname!.isNotEmpty)
                Text(
                  '@${state.nickname}',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                ),
            ],
          ),
        ),
        IconButton(
          icon: Icon(Icons.edit_outlined, color: cs.primary),
          onPressed: () => _openEditScreen(context),
        ),
      ],
    );
  }

  Widget _buildVerificationStatus(ProfileState state, ColorScheme cs) {
    Color bgColor;
    Color textColor;
    IconData icon;
    String label;

    if (state.isVerificationPending) {
      bgColor = cs.tertiaryContainer.withValues(alpha: 0.4);
      textColor = cs.onTertiaryContainer;
      icon = Icons.hourglass_empty;
      label = 'Menunggu verifikasi admin';
    } else if (state.isVerificationRejected) {
      bgColor = cs.errorContainer.withValues(alpha: 0.4);
      textColor = cs.onErrorContainer;
      icon = Icons.cancel_outlined;
      label = 'Verifikasi ditolak';
    } else {
      bgColor = cs.primaryContainer.withValues(alpha: 0.4);
      textColor = cs.onPrimaryContainer;
      icon = Icons.verified;
      label = 'Terverifikasi';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(ProfileState state, ColorScheme cs) {
    return Row(
      children: [
        _statCard(
          Icons.star_rounded,
          state.rating.toStringAsFixed(1),
          'Rating',
          cs.tertiary,
          cs.tertiaryContainer.withValues(alpha: 0.4),
          null,
        ),
        const SizedBox(width: 12),
        _statCard(
          Icons.work_rounded,
          state.totalJobs.toString(),
          'Pekerjaan',
          cs.primary,
          cs.primaryContainer.withValues(alpha: 0.4),
          null,
        ),
        const SizedBox(width: 12),
        _statCard(
          Icons.reviews_rounded,
          '${state.totalReviews}',
          'Ulasan',
          cs.secondary,
          cs.secondaryContainer.withValues(alpha: 0.4),
          () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProviderReviewsPage()),
            );
          },
        ),
      ],
    );
  }

  Widget _statCard(
    IconData icon,
    String value,
    String label,
    Color iconColor,
    Color bgColor,
    VoidCallback? onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Card _card(ColorScheme cs, Widget child) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      elevation: 0,
      color: cs.surface,
      surfaceTintColor: Colors.transparent,
      child: child,
    );
  }

  Widget _buildInfoSection(
    ProfileState state,
    ThemeData theme,
    ColorScheme cs,
  ) {
    return _card(
      cs,
      ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.person_outline, color: cs.primary, size: 20),
        ),
        title: const Text(
          'Informasi Pribadi',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Nama, nomor telepon, alamat, dan data diri lainnya',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        onTap: () => _openEditScreen(context),
      ),
    );
  }

  Widget _buildServicesSection(
    ProfileState state,
    ThemeData theme,
    ColorScheme cs,
  ) {
    return _card(
      cs,
      ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.miscellaneous_services_outlined,
            color: cs.secondary,
            size: 20,
          ),
        ),
        title: const Text(
          'Layanan Saya',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          state.servicesCount > 0
              ? '${state.servicesCount} layanan terdaftar'
              : 'Belum ada layanan',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ProviderServicesEditScreen(),
          ),
        ),
      ),
    );
  }

  Widget _buildPortfolioSection(
    ProfileState state,
    ThemeData theme,
    ColorScheme cs,
  ) {
    return _card(
      cs,
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_library_outlined, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(
                  'Portofolio',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (state.portfolios.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Belum ada portofolio',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    state.portfolios.map((url) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl(url),
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => Container(
                                width: 100,
                                height: 100,
                                color: cs.surfaceContainerHighest,
                                child: Icon(
                                  Icons.broken_image,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                        ),
                      );
                    }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutLink(ThemeData theme, ColorScheme cs) {
    return _card(
      cs,
      ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.account_balance_wallet_outlined,
            color: cs.onSecondaryContainer,
            size: 20,
          ),
        ),
        title: const Text(
          'Metode Penerimaan',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Atur rekening bank / e-wallet untuk payout',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProviderPayoutScreen()),
          );
        },
      ),
    );
  }

  Widget _buildReportSection(ThemeData theme, ColorScheme cs) {
    return _card(
      cs,
      Column(
        children: [
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: Colors.orange,
                size: 20,
              ),
            ),
            title: const Text(
              'Laporkan Masalah',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Laporkan bug, pembayaran, atau pesanan palsu',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            onTap: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const ReportFormPage()));
            },
          ),
          const Divider(height: 1, indent: 56, endIndent: 16),
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.history_outlined, color: cs.primary, size: 20),
            ),
            title: const Text(
              'Riwayat Laporan',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              'Cek status laporan yang sudah dikirim',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReportHistoryPage()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOrderManagement(ThemeData theme, ColorScheme cs) {
    return _card(
      cs,
      ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.assignment_outlined, color: cs.primary, size: 20),
        ),
        title: const Text(
          'Manajemen Orderan',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Lihat riwayat dan kelola pesanan',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
        trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProviderOrderListPage()),
          );
        },
      ),
    );
  }

  Widget _buildEditButton(ThemeData theme, ColorScheme cs) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        icon: const Icon(Icons.edit_outlined, size: 20),
        label: const Text('Edit Profil', style: TextStyle(fontSize: 16)),
        onPressed: () => _openEditScreen(context),
      ),
    );
  }

  Widget _buildLogoutButton(ThemeData theme, ColorScheme cs) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.error,
          side: BorderSide(color: cs.error.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.logout_outlined, size: 20),
        label: const Text('Keluar', style: TextStyle(fontSize: 16)),
        onPressed: () => _confirmLogout(cs),
      ),
    );
  }

  void _confirmLogout(ColorScheme cs) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('Keluar'),
            content: const Text('Apakah kamu yakin ingin keluar?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: cs.error,
                  foregroundColor: cs.onError,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  ref.read(authProvider.notifier).logout();
                  Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login', (route) => false);
                },
                child: const Text('Keluar'),
              ),
            ],
          ),
    );
  }

  void _openEditScreen(BuildContext context) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProviderProfileEditScreen()),
    );
    if (changed == true && mounted) {
      ref.read(profileProvider.notifier).loadProfile();
    }
  }

}
