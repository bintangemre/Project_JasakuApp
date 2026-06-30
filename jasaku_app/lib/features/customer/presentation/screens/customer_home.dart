import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/domain/models/order_model.dart';
import '../../../orders/presentation/pages/customer_order_list_page.dart';
import '../../../orders/presentation/pages/review_bottom_sheet.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_endpoints.dart';
import 'customer_services.dart';
import 'customer_providers_by_category.dart';
import 'customer_profile.dart';

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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
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
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Apa yang bisa kami bantu hari ini?',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CustomerProfile()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CustomerServices(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: Color(0xFFE0E7FF),
                                child: Icon(Icons.search, color: Color(0xFF2563EB)),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Cari\nJasa',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Color(0xFFDCFCE7),
                              child: Icon(Icons.add, color: Color(0xFF16A34A)),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Custom\nTask',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Kategori Jasa',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CustomerServices()),
                        );
                      },
                      child: const Text(
                        'Lihat Semua',
                        style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildCategoryCard(
                        icon: Icons.home_repair_service,
                        iconColor: const Color(0xFFFF6B00),
                        bgColor: const Color(0xFFFFEDD5),
                        title: 'Perbaikan\nBangunan',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CustomerProvidersByCategory(
                                categoryId: 'eba91362-4c0a-4045-bcca-51da9263a35d',
                                categoryName: 'Perbaikan Bangunan',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildCategoryCard(
                        icon: Icons.bolt,
                        iconColor: const Color(0xFFD4A100),
                        bgColor: const Color(0xFFFEF3C7),
                        title: 'Perbaikan\nKelistrikan',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CustomerProvidersByCategory(
                                categoryId: 'a7003a03-7318-41e0-8ece-f4810e80abf7',
                                categoryName: 'Perbaikan Kelistrikan',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Pesanan Terbaru',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CustomerOrderListPage()),
                      ),
                      child: const Text(
                        'Lihat Semua',
                        style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ordersAsync.when(
                  data: (orders) {
                    if (orders.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
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
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildOrderCard(context, ref, order),
                      )).toList(),
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
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
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: iconColor, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
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
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.providerName ?? 'Provider',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor(order.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    order.statusLabel,
                    style: TextStyle(
                      color: _statusColor(order.status),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 18, color: Colors.grey),
                const SizedBox(width: 6),
                Text(order.formattedDate, style: const TextStyle(color: Colors.grey)),
                const Spacer(),
                Text('Rp ${order.formattedPrice}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
              ],
            ),
            if (isCompleted) ...[
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _openReview(context, order),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Beri Rating',
                      style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w500),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.star, size: 18, color: Color(0xFF2563EB)),
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
