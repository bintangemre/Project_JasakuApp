// Defines backend API endpoint URLs for shared Jasaku App network calls.
class ApiEndpoints {
  static const String baseUrl = 'http://10.241.188.20:3000';
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
  static const String getCustomerActiveOrders = '$baseUrl/api/orders/customer/orders?status=active';
  static const String getProviderOrders = '$baseUrl/api/orders/provider/orders';
  static const String getProviderRequests = '$baseUrl/api/orders/provider/requests';
  static const String updateOrderStatus = '$baseUrl/api/orders/orders/'; // + {orderId}/status

  // OTP
  static const String sendOtp = '$baseUrl/api/auth/send-otp';
  static const String verifyOtp = '$baseUrl/api/auth/verify-otp';

  // FCM Device
  static const String registerDevice = '$baseUrl/api/notifications/devices/register';

  // Reviews
  static const String createReview = '$baseUrl/api/reviews';
  static const String getProviderReviews = '$baseUrl/api/reviews/provider/'; // + {providerId}

  // Payments
  static const String paymentMethods = '$baseUrl/api/payment-methods';
  static const String createPayment = '$baseUrl/api/payments';
  static const String getPaymentByOrder = '$baseUrl/api/payments/order/'; // + {orderId}
  static const String savePaymentMethod = '$baseUrl/api/payment-methods/save';
  static const String getMyPaymentMethods = '$baseUrl/api/payment-methods/mine';

  // Order status tracking
  static const String cancelOrder = '$baseUrl/api/orders/orders/'; // + {orderId}/cancel
  static const String getOrderTracking = '$baseUrl/api/orders/orders/'; // + {orderId}/tracking
  static const String getProviderLocation = '$baseUrl/api/locations/provider/'; // + {providerId}

  // Admin
  static const String adminDashboard = '$baseUrl/api/admin/dashboard';
  static const String adminPendingProviders = '$baseUrl/api/admin/providers/pending';
  static const String adminVerifyProvider = '$baseUrl/api/admin/providers/'; // + {providerId}/verify
  static const String adminAllProviders = '$baseUrl/api/admin/providers';
  static const String adminAllCustomers = '$baseUrl/api/admin/customers';
  static const String adminBanUser = '$baseUrl/api/admin/users/'; // + {userId}/ban
  static const String adminCreateCategory = '$baseUrl/api/admin/categories';
  static const String adminCreateService = '$baseUrl/api/admin/services';

  // Customer Profile
  static const String customerProfile = '$baseUrl/api/customer/profile';

  // Custom Tasks
  static const String customTasks = '$baseUrl/api/custom-tasks';
  static const String customTasksAvailable = '$baseUrl/api/custom-tasks/available';
  static const String customTasksMine = '$baseUrl/api/custom-tasks/mine';

  // Reports
  static const String createReport = '$baseUrl/api/reports';
  static const String myReports = '$baseUrl/api/reports/mine';

  // Provider Dashboard
  static const String providerProfile = '$baseUrl/api/provider/profile';
  static const String providerServices = '$baseUrl/api/provider/services';
  static const String providerAvailability = '$baseUrl/api/provider/profile/availability';
  static const String providerCompleteOnboarding = '$baseUrl/api/provider/profile/complete';
  static const String providerUpdateProfile = '$baseUrl/api/provider/profile';
  static const String providerPayoutMethods = '$baseUrl/api/provider/payout-methods';

  // Public provider status & schedule (customer view)
  static String providerStatus(String providerId) => '$baseUrl/api/orders/provider/$providerId/status';
  static String providerSchedule(String providerId) => '$baseUrl/api/orders/provider/$providerId/schedule';

  // Extensions
  static String requestExtension(String orderId) => '$baseUrl/api/orders/orders/$orderId/extend';
  static const String adminPendingExtensions = '$baseUrl/api/admin/extensions/pending';
  static String adminApproveExtension(String extensionId) => '$baseUrl/api/admin/extensions/$extensionId/approve';
}
