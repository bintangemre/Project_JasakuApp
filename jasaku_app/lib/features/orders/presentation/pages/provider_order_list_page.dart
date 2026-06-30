import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/order_model.dart';
import '../providers/order_list_provider.dart';

class ProviderOrderListPage extends ConsumerStatefulWidget {
  const ProviderOrderListPage({super.key});

  @override
  ConsumerState<ProviderOrderListPage> createState() => _ProviderOrderListPageState();
}

class _ProviderOrderListPageState extends ConsumerState<ProviderOrderListPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(providerCompletedOrdersProvider.notifier).fetchOrders());
  }

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

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending': return Icons.hourglass_empty;
      case 'accepted': return Icons.check_circle_outline;
      case 'on_the_way': return Icons.directions_bike;
      case 'arrived': return Icons.location_on;
      case 'in_progress': return Icons.build;
      case 'completed': return Icons.assignment_turned_in;
      case 'rejected': return Icons.cancel;
      case 'cancelled': return Icons.cancel;
      default: return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(providerCompletedOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Pesanan'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _buildBody(state),
    );
  }

  Widget _buildBody(OrderListState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Gagal memuat riwayat', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(state.error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.read(providerCompletedOrdersProvider.notifier).fetchOrders(),
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('Belum ada riwayat', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey)),
              const SizedBox(height: 8),
              const Text('Pesanan yang selesai akan muncul di sini', style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(providerCompletedOrdersProvider.notifier).fetchOrders(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.orders.length,
        itemBuilder: (context, index) => _buildOrderCard(state.orders[index]),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Pesanan: ${order.id}')),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _statusColor(order.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(_statusIcon(order.status), color: _statusColor(order.status), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(order.customerName ?? 'Pelanggan', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        if (order.address != null) ...[
                          const SizedBox(height: 2),
                          Text(order.address!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor(order.status).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(order.statusLabel, style: TextStyle(color: _statusColor(order.status), fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Rp ${order.formattedPrice}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF00A651))),
                  Text(order.formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
