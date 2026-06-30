import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../domain/models/order_model.dart';

class OrderListState {
  final List<OrderModel> orders;
  final bool isLoading;
  final String? error;

  OrderListState({List<OrderModel>? orders, this.isLoading = false, this.error})
      : orders = orders ?? [];
}

class OrderListNotifier extends StateNotifier<OrderListState> {
  final Dio _dio;
  final String _endpoint;
  final bool _isProvider;
  final String? _statusFilter;

  OrderListNotifier(this._dio, this._endpoint, this._isProvider, [this._statusFilter])
      : super(OrderListState());

  Future<void> fetchOrders() async {
    state = OrderListState(isLoading: true);
    try {
      final queryParams = <String, dynamic>{};
      if (_statusFilter != null) {
        queryParams['status'] = _statusFilter;
      }
      final response = await _dio.get(_endpoint, queryParameters: queryParams);
      final data = response.data['data'] as List<dynamic>? ?? [];
      final orders = data.map((json) => _isProvider
          ? OrderModel.fromProviderJson(json as Map<String, dynamic>)
          : OrderModel.fromCustomerJson(json as Map<String, dynamic>)
      ).toList();
      state = OrderListState(orders: orders);
    } catch (e) {
      state = OrderListState(error: e.toString());
    }
  }
}

final customerOrderListProvider = StateNotifierProvider<OrderListNotifier, OrderListState>((ref) {
  return OrderListNotifier(ApiClient().dio, ApiEndpoints.getCustomerOrders, false);
});

final providerOrderListProvider = StateNotifierProvider<OrderListNotifier, OrderListState>((ref) {
  return OrderListNotifier(ApiClient().dio, ApiEndpoints.getProviderOrders, true);
});

final providerCompletedOrdersProvider = StateNotifierProvider<OrderListNotifier, OrderListState>((ref) {
  return OrderListNotifier(ApiClient().dio, ApiEndpoints.getProviderOrders, true, 'completed');
});
