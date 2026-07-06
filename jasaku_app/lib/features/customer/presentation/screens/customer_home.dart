import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/domain/models/order_model.dart';
import '../../../orders/presentation/pages/customer_order_list_page.dart';
import '../../../orders/presentation/pages/review_bottom_sheet.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../custom_tasks/presentation/pages/customer_create_task_page.dart';
import 'customer_services.dart';
import 'customer_providers_by_category.dart';
final customerHomeOrdersProvider = FutureProvider.autoDispose<List<OrderModel>>((ref) async {
  final response = await ApiClient().dio.get(ApiEndpoints.getCustomerOrders);
  final data = response.data['data'] as List<dynamic>? ?? [];
  return data
      .map((json) => OrderModel.fromCustomerJson(json as Map<String, dynamic>))
      .take(3)
      .toList();
});

class CustomerHome extends ConsumerWidget {
  const CustomerHome({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'accepted': return Colors.blue;
      case 'on_the_way': return const Color(0xFF0288D1);
      case 'arrived': return Colors.indigo;
      case 'in_progress': return Colors.purple;
      case 'completed': return Colors.green;
      case 'rejected': return Colors.red;
      case 'cancelled': return Colors.grey;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final ordersAsync = ref.watch(customerHomeOrdersProvider);
    final userName =
        (authState.user?.displayName ?? 'Customer').split(' ').first;
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(customerHomeOrdersProvider),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, ref, userName),
            _buildServiceGrid(context),
            _buildPromoBanner(context),
            _buildRecentOrders(context, ref, ordersAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, String userName) {
    final unreadNotif = ref.watch(unreadNotifProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      constraints: BoxConstraints(
        minHeight: screenHeight * 0.30,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Halo, $userName!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Apa yang bisa kami bantu?',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 24),
                  ),
                  if (unreadNotif > 0)
                    Positioned(
                      right: 4,
                      top: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unreadNotif > 9 ? '9+' : '$unreadNotif',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CustomerServices()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search, color: Colors.white70, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Cari layanan...',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceGrid(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ApiClient().dio.get(ApiEndpoints.getAllCategories).then((res) {
        final data = res.data['data'] as List<dynamic>? ?? [];
        return data.map((c) {
          final rawName = c['name'] as String? ?? '';
          final name = rawName.trim();
          debugPrint('CATEGORY_NAME: "$rawName"');
          IconData icon;
          Color iconColor;
          Color bgColor;
          String? imagePath;
          if (name.contains('listrik') || name.contains('Listrik') || name.contains('KELISTRIKAN')) {
            icon = Icons.electric_bolt;
            iconColor = const Color(0xFFFFB300);
            bgColor = const Color(0xFFFEF3C7);
            imagePath = 'assets/icons/icon_perbaikan_kelistrikan.png';
          } else if (name.contains('Bangunan') || name.contains('bangunan')) {
            icon = Icons.home_repair_service;
            iconColor = const Color(0xFFFF6B00);
            bgColor = const Color(0xFFFFEDD5);
            imagePath = 'assets/icons/icon_perbaikan_bangunan.png';
          } else if (name.contains('Kebersihan') || name.contains('kebersihan')) {
            icon = Icons.cleaning_services;
            iconColor = const Color(0xFF059669);
            bgColor = const Color(0xFFD1FAE5);
          } else if (name.contains('Pindahan') || name.contains('pindahan')) {
            icon = Icons.local_shipping;
            iconColor = const Color(0xFF2563EB);
            bgColor = const Color(0xFFDBEAFE);
          } else if (name.contains('Kayu') || name.contains('kayu')) {
            icon = Icons.handyman;
            iconColor = const Color(0xFF7C3AED);
            bgColor = const Color(0xFFEDE9FE);
          } else if (name.contains('AC') || name.contains('Elektronik') || name.contains('elektronik')) {
            icon = Icons.ac_unit;
            iconColor = const Color(0xFF0891B2);
            bgColor = const Color(0xFFCFFAFE);
          } else {
            icon = Icons.build_circle;
            iconColor = const Color(0xFF6B7280);
            bgColor = const Color(0xFFF3F4F6);
          }
          return {
            'id': c['id'] as String,
            'name': name,
            'icon': icon,
            'iconColor': iconColor,
            'bgColor': bgColor,
            'imagePath': imagePath,
          };
        }).toList();
      }),
      builder: (context, snapshot) {
        final cats = snapshot.data ?? [];
        if (cats.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Layanan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.85,
                mainAxisSpacing: 8,
                crossAxisSpacing: 4,
                children: [
                  _buildServiceIcon(
                    icon: Icons.add,
                    iconColor: const Color(0xFF059669),
                    bgColor: const Color(0xFFD1FAE5),
                    label: 'Custom Task',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CustomerCreateTaskPage()),
                      );
                    },
                  ),
                  ...cats.take(6).map((cat) {
                    return _buildServiceIcon(
                      icon: cat['icon'] as IconData,
                      iconColor: cat['iconColor'] as Color,
                      bgColor: cat['bgColor'] as Color,
                      label: cat['name'] as String,
                      imagePath: cat['imagePath'] as String?,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => CustomerProvidersByCategory(
                              categoryId: cat['id'] as String,
                              categoryName: cat['name'] as String,
                            ),
                          ),
                        );
                      },
                    );
                  }),
                  _buildServiceIcon(
                    icon: Icons.grid_view_rounded,
                    iconColor: AppColors.primary,
                    bgColor: AppColors.primary.withValues(alpha: 0.1),
                    label: 'Lainnya',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CustomerServices()),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildServiceIcon({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String label,
    required VoidCallback onTap,
    String? imagePath,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: imagePath != null
                ? ClipOval(child: Image.asset(imagePath, width: 50, height: 50, fit: BoxFit.cover))
                : Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: SizedBox(
        height: 150,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _PromoCard(
              width: 260,
              color: const Color(0xFF1E40AF),
              title: 'Jasaku Mitra',
              subtitle: 'Dapatkan layanan\nerbaikk dari kami',
            ),
            const SizedBox(width: 12),
            _PromoCard(
              width: 260,
              color: const Color(0xFF059669),
              title: 'Custom Task',
              subtitle: 'Buat tugas sesuai\nkebutuhan Anda',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentOrders(BuildContext context, WidgetRef ref, AsyncValue<List<OrderModel>> ordersAsync) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pesanan Terbaru',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CustomerOrderListPage()),
                ),
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ordersAsync.when(
            data: (orders) {
              if (orders.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 8),
                        const Text('Belum ada pesanan', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                );
              }
              return Column(
                children: orders.map((order) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildOrderCard(context, ref, order),
                )).toList(),
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text('Gagal memuat', style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, WidgetRef ref, OrderModel order) {
    final isCompleted = order.status == 'completed';
    return GestureDetector(
      onTap: isCompleted
          ? () => _openReview(context, order)
          : () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CustomerOrderListPage()),
            ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.providerName ?? 'Provider',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(order.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    order.statusLabel,
                    style: TextStyle(
                      color: _statusColor(order.status),
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(order.formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 80),
                Text('Rp ${order.formattedPrice}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
            if (isCompleted) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _openReview(context, order),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Beri Rating',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500, fontSize: 13),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.star, size: 16, color: AppColors.primary),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openReview(BuildContext context, OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ReviewBottomSheet(
        orderId: order.id,
        providerId: order.providerId ?? '',
        providerName: order.providerName ?? 'Provider',
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final double width;
  final Color color;
  final String title;
  final String subtitle;

  const _PromoCard({
    required this.width,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
