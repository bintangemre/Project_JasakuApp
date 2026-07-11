import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_endpoints.dart';

class SearchResultCategory {
  final String id;
  final String name;
  final String? iconUrl;

  SearchResultCategory({required this.id, required this.name, this.iconUrl});

  factory SearchResultCategory.fromJson(Map<String, dynamic> json) {
    return SearchResultCategory(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      iconUrl: json['icon_url'] as String?,
    );
  }
}

class SearchResultService {
  final String id;
  final String name;
  final String? description;
  final String categoryId;
  final String categoryName;

  SearchResultService({
    required this.id,
    required this.name,
    this.description,
    required this.categoryId,
    required this.categoryName,
  });

  factory SearchResultService.fromJson(Map<String, dynamic> json) {
    return SearchResultService(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      categoryId: json['category_id'] as String? ?? '',
      categoryName: (json['categories'] as Map<String, dynamic>?)?['name'] as String? ?? '',
    );
  }
}

class SearchState {
  final String query;
  final bool isLoading;
  final List<SearchResultCategory> categories;
  final List<SearchResultService> services;
  final String? error;

  SearchState({
    this.query = '',
    this.isLoading = false,
    this.categories = const [],
    this.services = const [],
    this.error,
  });

  SearchState copyWith({
    String? query,
    bool? isLoading,
    List<SearchResultCategory>? categories,
    List<SearchResultService>? services,
    String? error,
  }) {
    return SearchState(
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      categories: categories ?? this.categories,
      services: services ?? this.services,
      error: error,
    );
  }
}

class CustomerSearchNotifier extends StateNotifier<SearchState> {
  final Dio _dio;
  CustomerSearchNotifier() : _dio = ApiClient().dio, super(SearchState());

  Future<void> search(String q) async {
    if (q.length < 2) {
      state = state.copyWith(query: q, categories: [], services: [], isLoading: false);
      return;
    }
    state = state.copyWith(query: q, isLoading: true, error: null);
    try {
      final response = await _dio.get(ApiEndpoints.searchServicesApi, queryParameters: {'q': q});
      final data = response.data['data'] as Map<String, dynamic>? ?? {};
      final categories = (data['categories'] as List<dynamic>?)
              ?.map((e) => SearchResultCategory.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      final services = (data['services'] as List<dynamic>?)
              ?.map((e) => SearchResultService.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
      state = state.copyWith(categories: categories, services: services, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clear() {
    state = SearchState();
  }
}

final customerSearchProvider = StateNotifierProvider<CustomerSearchNotifier, SearchState>((ref) {
  return CustomerSearchNotifier();
});
