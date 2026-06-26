// Defines backend API endpoint URLs for shared Jasaku App network calls.
class ApiEndpoints {
  static const String baseUrl = 'http://10.25.4.20:3000';
  static const String login = '$baseUrl/api/auth/login';
  static const String loginGoogle = '$baseUrl/api/auth/login/google';
  static const String registerCustomer = '$baseUrl/api/auth/register/customer';
  static const String registerProvider = '$baseUrl/api/auth/register/provider';
  static const String logout = '$baseUrl/api/auth/logout';

  static const String getAllCategories = '$baseUrl/api/services/categories';
  static const String getCategoriesByid = '$baseUrl/api/services/categories/'; // + {id}
  static const String getProviderByService = '$baseUrl/api/services/providers/'; // + {serviceId}
  static const String getProvidersByServiceWithoutDistance = '$baseUrl/api/services/services/providers/non-location';
  static const String updateLocation = '$baseUrl/api/locations/update';
  static const String updateProviderService = '$baseUrl/api/provider/services/update-service';
  static const String providerAvailableServices = '$baseUrl/api/provider/services/available-services';
  static const String providerAvailablePricingTypes = '$baseUrl/api/provider/services/available-pricing-types';
  static const String createOrder = '$baseUrl/api/orders/orders';
  static const String getOrderDetails = '$baseUrl/api/orders/orders/'; // + {orderId}
  static const String getCustomerOrders = '$baseUrl/api/orders/customer/orders';
  static const String getProviderOrders = '$baseUrl/api/orders/provider/orders';
  static const String updateOrderStatus = '$baseUrl/api/orders/orders/'; // + {orderId}/status
}
