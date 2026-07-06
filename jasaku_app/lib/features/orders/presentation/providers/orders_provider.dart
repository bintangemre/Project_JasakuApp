import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../domain/models/order_payload_model.dart';

class OrderFormState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;
  final String? orderId;
  final String? paymentMethod;

  OrderFormState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
    this.orderId,
    this.paymentMethod,
  });
}

class OrderFormNotifier extends StateNotifier<OrderFormState> {
  final Dio _dio;
  OrderFormNotifier(this._dio) : super(OrderFormState());

  Future<void> submitNewOrder({
    required OrderPayloadModel payload,
    required String paymentMethod,
    required double paymentAmount,
  }) async {
    state = OrderFormState(isLoading: true);
    try {
      final orderResponse = await _dio.post(ApiEndpoints.createOrder, data: {
        ...payload.toJson(),
        'paymentMethod': paymentMethod,
      });
      if (orderResponse.statusCode != 200 && orderResponse.statusCode != 201) {
        state = OrderFormState(isLoading: false, errorMessage: "Gagal membuat pesanan");
        return;
      }

      final orderId = orderResponse.data['data']?['id'] as String?;
      if (orderId == null) {
        state = OrderFormState(isLoading: false, errorMessage: "Gagal mendapatkan ID pesanan");
        return;
      }

      await _dio.post(ApiEndpoints.createPayment, data: {
        'orderId': orderId,
        'method': paymentMethod,
        'amount': paymentAmount,
      });

      state = OrderFormState(isLoading: false, isSuccess: true, orderId: orderId, paymentMethod: paymentMethod);
    } on DioException catch (e) {
      final message = e.response?.data?['message'] as String? ?? e.message ?? 'Gagal membuat pesanan';
      state = OrderFormState(isLoading: false, errorMessage: message);
    } catch (e) {
      state = OrderFormState(isLoading: false, errorMessage: e.toString());
    }
  }
}

final orderFormProvider =
    StateNotifierProvider<OrderFormNotifier, OrderFormState>((ref) {
      return OrderFormNotifier(ApiClient().dio);
    });
