// Defines backend API endpoint URLs for shared Jasaku App network calls.
class ApiEndpoints {
  static const String _raw = String.fromEnvironment('BASE_URL', defaultValue: 'jasakuapp.onrender.com');
  static final String baseUrl = _raw.startsWith('http') ? _raw : 'https://$_raw';
  static final String login = '$baseUrl/api/auth/login';
  static final String loginGoogle = '$baseUrl/api/auth/login/google';
  static final String registerCustomer = '$baseUrl/api/auth/register/customer';
  static final String registerProvider = '$baseUrl/api/auth/register/provider';
  static final String logout = '$baseUrl/api/auth/logout';

  static final String getAllCategories = '$baseUrl/api/services/categories';
  static final String getCategoriesByid = '$baseUrl/api/services/categories/'; // + {id}
  static final String getProviderByService = '$baseUrl/api/services/providers/'; // + {serviceId}
  static final String getProvidersByServiceWithoutDistance = '$baseUrl/api/services/services/providers/non-location';
  static final String searchServicesApi = '$baseUrl/api/services/services/search'; // + ?q=
  static final String updateLocation = '$baseUrl/api/locations/update';
  static final String updateProviderService = '$baseUrl/api/provider/services/update-service';
  static final String providerAvailableServices = '$baseUrl/api/provider/services/available-services';
  static final String providerAvailablePricingTypes = '$baseUrl/api/provider/services/available-pricing-types';
  static final String createOrder = '$baseUrl/api/orders/orders';
  static final String getOrderDetails = '$baseUrl/api/orders/orders/'; // + {orderId}
  static final String getCustomerOrders = '$baseUrl/api/orders/customer/orders';
  static final String getCustomerActiveOrders = '$baseUrl/api/orders/customer/orders?status=active';
  static final String getProviderOrders = '$baseUrl/api/orders/provider/orders';
  static final String getProviderRequests = '$baseUrl/api/orders/provider/requests';
  static final String updateOrderStatus = '$baseUrl/api/orders/orders/'; // + {orderId}/status

  // FCM Device
  static final String registerDevice = '$baseUrl/api/notifications/devices/register';

  // Reviews
  static final String createReview = '$baseUrl/api/reviews';
  static final String getProviderReviews = '$baseUrl/api/reviews/provider/'; // + {providerId}

  // Payments
  static final String paymentMethods = '$baseUrl/api/payment-methods';
  static final String createPayment = '$baseUrl/api/payments';
  static final String getPaymentByOrder = '$baseUrl/api/payments/order/'; // + {orderId}
  static final String uploadPaymentProof = '$baseUrl/api/payments/upload-proof/'; // + {orderId}
  static final String savePaymentMethod = '$baseUrl/api/payment-methods/save';
  static final String getMyPaymentMethods = '$baseUrl/api/payment-methods/mine';

  // Order status tracking
  static final String cancelOrder = '$baseUrl/api/orders/orders/'; // + {orderId}/cancel
  static final String getOrderTracking = '$baseUrl/api/orders/orders/'; // + {orderId}/tracking
  static final String getProviderLocation = '$baseUrl/api/locations/provider/'; // + {providerId}

  // Admin
  static final String adminDashboard = '$baseUrl/api/admin/dashboard';
  static final String adminPendingProviders = '$baseUrl/api/admin/providers/pending';
  static final String adminVerifyProvider = '$baseUrl/api/admin/providers/'; // + {providerId}/verify
  static final String adminAllProviders = '$baseUrl/api/admin/providers';
  static final String adminAllCustomers = '$baseUrl/api/admin/customers';
  static final String adminBanUser = '$baseUrl/api/admin/users/'; // + {userId}/ban
  static final String adminCreateCategory = '$baseUrl/api/admin/categories';
  static final String adminCreateService = '$baseUrl/api/admin/services';
  static final String adminCategories = '$baseUrl/api/admin/categories';
  static String adminPricingTypes(String categoryId) => '$baseUrl/api/admin/categories/$categoryId/pricing-types';
  static final String adminCreatePricingType = '$baseUrl/api/admin/pricing-types';
  static String adminUpdatePricingType(String id) => '$baseUrl/api/admin/pricing-types/$id';
  static String adminDeletePricingType(String id) => '$baseUrl/api/admin/pricing-types/$id';

  // Customer Profile
  static final String customerProfile = '$baseUrl/api/customer/profile';

  // Custom Tasks
  static final String customTasks = '$baseUrl/api/custom-tasks';
  static final String customTasksAvailable = '$baseUrl/api/custom-tasks/available';
  static final String customTasksMine = '$baseUrl/api/custom-tasks/mine';
  static final String customTasksMyAccepted = '$baseUrl/api/custom-tasks/my-accepted';
  static final String customTasksMyActive = '$baseUrl/api/custom-tasks/my-active';
  static final String customTaskTracking = '$baseUrl/api/custom-tasks/'; // + {taskId}/tracking

  // Reports
  static final String createReport = '$baseUrl/api/reports';
  static final String myReports = '$baseUrl/api/reports/mine';

  // Provider Dashboard
  static final String providerProfile = '$baseUrl/api/provider/profile';
  static final String providerCounts = '$baseUrl/api/provider/counts';
  static final String providerServices = '$baseUrl/api/provider/services';
  static final String providerAvailability = '$baseUrl/api/provider/profile/availability';
  static final String providerCompleteOnboarding = '$baseUrl/api/provider/profile/complete';
  static final String providerUpdateProfile = '$baseUrl/api/provider/profile';
  static final String providerPayoutMethods = '$baseUrl/api/provider/payout-methods';

  // Auth
  static final String resubmitVerification = '$baseUrl/api/auth/provider/resubmit-verification';

  // Public provider status & schedule (customer view)
  static String providerStatus(String providerId) => '$baseUrl/api/orders/provider/$providerId/status';
  static String providerSchedule(String providerId) => '$baseUrl/api/orders/provider/$providerId/schedule';

  // Payment accounts (rekber — customer needs to know where to transfer)
  static final String paymentAccounts = '$baseUrl/api/orders/payment-accounts';

  // Extensions
  static String requestExtension(String orderId) => '$baseUrl/api/orders/orders/$orderId/extend';
  static String orderExtensions(String orderId) => '$baseUrl/api/orders/orders/$orderId/extensions';
  static String respondExtension(String extensionId) => '$baseUrl/api/orders/extensions/$extensionId/respond';
  static final String adminAllExtensions = '$baseUrl/api/admin/extensions/all';
  static final String adminPendingExtensions = '$baseUrl/api/admin/extensions/pending';
  static String adminApproveExtension(String extensionId) => '$baseUrl/api/admin/extensions/$extensionId/approve';
}
