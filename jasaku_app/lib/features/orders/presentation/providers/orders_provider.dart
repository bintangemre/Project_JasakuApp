import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../domain/models/order_payload_model.dart';

// State manajemen penanda loading aplikasi
class OrderFormState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;

  OrderFormState({
    this.isLoading = false,
    this.errorMessage,
    this.isSuccess = false,
  });
}

class OrderFormNotifier extends StateNotifier<OrderFormState> {
  final Dio _dio; // Inject Dio Client milikmu di sini
  OrderFormNotifier(this._dio) : super(OrderFormState());

  Future<void> submitNewOrder(OrderPayloadModel payload, String url) async {
    state = OrderFormState(isLoading: true);
    try {
      final response = await _dio.post(url, data: payload.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        state = OrderFormState(isLoading: false, isSuccess: true);
      } else {
        state = OrderFormState(
          isLoading: false,
          errorMessage: "Gagal membuat pesanan",
        );
      }
    } catch (e) {
      state = OrderFormState(isLoading: false, errorMessage: e.toString());
    }
  }
}

// Ganti 'Dio()' dengan ApiClient().dio milikmu jika menggunakan custom class
final orderFormProvider =
    StateNotifierProvider<OrderFormNotifier, OrderFormState>((ref) {
      return OrderFormNotifier(Dio());
    });
