import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../orders/presentation/pages/order_tracking_page.dart';

class CustomTaskTrackingPage extends ConsumerStatefulWidget {
  final String taskId;

  const CustomTaskTrackingPage({super.key, required this.taskId});

  @override
  ConsumerState<CustomTaskTrackingPage> createState() => _CustomTaskTrackingPageState();
}

class _CustomTaskTrackingPageState extends ConsumerState<CustomTaskTrackingPage> {
  final Dio _dio = ApiClient().dio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveAndNavigate());
  }

  Future<void> _resolveAndNavigate() async {
    try {
      final response = await _dio.get('${ApiEndpoints.customTaskTracking}${widget.taskId}/tracking');
      final data = response.data['data'] as Map<String, dynamic>?;
      final orderId = data?['orderId'] as String?;

      if (orderId != null && mounted) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OrderTrackingPage(orderId: orderId),
          ),
        );
        return;
      }
    } catch (_) {}

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Belum ada pesanan aktif untuk task ini')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
