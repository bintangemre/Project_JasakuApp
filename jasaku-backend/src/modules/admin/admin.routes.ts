import {Router} from 'express';
import {
  getDashboardMetrics, getPendingProviders, verifyProvider, unverifyProvider, getProviderDetail,
  getCategories, getServicesByCategory, getAllServices, getAllPricingUnits,
  createCategory, updateCategory, deleteCategory,
  createService, updateService, deleteService,
  getAllProviders, getAllCustomers, banUser, unbanUser,
  createPricingUnit, updatePricingUnit, deletePricingUnit,
  getAllContractTypes, createContractType, updateContractType, deleteContractType,
  getServicePricingUnits, addServicePricingUnit, removeServicePricingUnit,
  getServiceContractTypes, addServiceContractType, removeServiceContractType,
  getPaymentAccounts, createPaymentAccount, updatePaymentAccount, deletePaymentAccount,
  uploadQrisImage,
  getPendingPaymentOrders,
  getAllOrders,
  getPendingExtensions,
  getAllExtensions,
  getPendingPaymentExtensions,
  getOpenReports,
  respondToReport,
  getPendingTaskPayments,
  getPendingTaskPaymentsByTask,
  getPendingTaskPayouts,
  confirmTaskPayment,
  confirmTaskPaymentByTask,
  confirmTaskPayout,
  getNotificationCounts,
  getCompletedOrdersPendingPayout,
  confirmOrderPayout,
} from './admin.controller';
import { confirmPaymentByAdmin, approveExtension, activateExtension } from '../orders/orders.controller';
import { authenticate } from '../../middleware/auth.middleware';
import { isAdmin } from '../../middleware/role.middleware';
import { validate } from '../../middleware/validate.middleware';
import { createCategorySchema, createServiceSchema, createPricingUnitSchema, updatePricingUnitSchema, createContractTypeSchema, updateContractTypeSchema, verifyProviderSchema } from '../../middleware/schemas';
import { upload } from '../../middleware/upload.middleware';

const router = Router();

// Dashboard & Notifications
router.get('/dashboard', authenticate, isAdmin, getDashboardMetrics);
router.get('/notifications/counts', authenticate, isAdmin, getNotificationCounts);

// Provider verification
router.get('/providers/pending', authenticate, isAdmin, getPendingProviders);
router.patch('/providers/:providerId/verify', authenticate, isAdmin, validate(verifyProviderSchema), verifyProvider);
router.patch('/providers/:providerId/unverify', authenticate, isAdmin, unverifyProvider);
router.get('/providers/:providerId/detail', authenticate, isAdmin, getProviderDetail);
router.get('/providers', authenticate, isAdmin, getAllProviders);

// Customer management
router.get('/customers', authenticate, isAdmin, getAllCustomers);
router.patch('/customers/:userId/ban', authenticate, isAdmin, banUser);
router.patch('/customers/:userId/unban', authenticate, isAdmin, unbanUser);

// Categories
router.get('/categories', authenticate, isAdmin, getCategories);
router.post('/categories', authenticate, isAdmin, validate(createCategorySchema), createCategory);
router.put('/categories/:id', authenticate, isAdmin, updateCategory);
router.delete('/categories/:id', authenticate, isAdmin, deleteCategory);

// Services
router.get('/services', authenticate, isAdmin, getAllServices);
router.get('/categories/:id/services', authenticate, isAdmin, getServicesByCategory);
router.post('/services', authenticate, isAdmin, validate(createServiceSchema), createService);
router.put('/services/:id', authenticate, isAdmin, updateService);
router.delete('/services/:id', authenticate, isAdmin, deleteService);

// Pricing Units (global, no category filter)
router.get('/pricing-units', authenticate, isAdmin, getAllPricingUnits);
router.post('/pricing-units', authenticate, isAdmin, validate(createPricingUnitSchema), createPricingUnit);
router.put('/pricing-units/:id', authenticate, isAdmin, validate(updatePricingUnitSchema), updatePricingUnit);
router.delete('/pricing-units/:id', authenticate, isAdmin, deletePricingUnit);

// Service ↔ Pricing Units (pivot)
router.get('/services/:serviceId/pricing-units', authenticate, isAdmin, getServicePricingUnits);
router.post('/services/:serviceId/pricing-units', authenticate, isAdmin, addServicePricingUnit);
router.delete('/services/:serviceId/pricing-units/:pricingUnitId', authenticate, isAdmin, removeServicePricingUnit);

// Service ↔ Contract Types (pivot)
router.get('/services/:serviceId/contract-types', authenticate, isAdmin, getServiceContractTypes);
router.post('/services/:serviceId/contract-types', authenticate, isAdmin, addServiceContractType);
router.delete('/services/:serviceId/contract-types/:contractTypeId', authenticate, isAdmin, removeServiceContractType);

// Contract Types
router.get('/contract-types', authenticate, isAdmin, getAllContractTypes);
router.post('/contract-types', authenticate, isAdmin, validate(createContractTypeSchema), createContractType);
router.put('/contract-types/:id', authenticate, isAdmin, validate(updateContractTypeSchema), updateContractType);
router.delete('/contract-types/:id', authenticate, isAdmin, deleteContractType);

// Payment Accounts (Rekber Admin)
router.get('/payment-accounts', authenticate, isAdmin, getPaymentAccounts);
router.post('/payment-accounts', authenticate, isAdmin, createPaymentAccount);
router.put('/payment-accounts/:id', authenticate, isAdmin, updatePaymentAccount);
router.delete('/payment-accounts/:id', authenticate, isAdmin, deletePaymentAccount);
router.post('/payment-accounts/:id/qris-upload', authenticate, isAdmin, upload.single('qris'), uploadQrisImage);

// Payment Confirmation (Rekber) — order service
router.get('/orders/pending-payment', authenticate, isAdmin, getPendingPaymentOrders);
router.get('/orders/all', authenticate, isAdmin, getAllOrders);
router.patch('/orders/:orderId/confirm-payment', authenticate, isAdmin, confirmPaymentByAdmin);

// Payout Confirmation (Pencairan Dana) — regular orders
router.get('/orders/pending-payout', authenticate, isAdmin, getCompletedOrdersPendingPayout);
router.patch('/orders/:orderId/confirm-payout', authenticate, isAdmin, confirmOrderPayout);

// Extensions
router.get('/extensions/all', authenticate, isAdmin, getAllExtensions);
router.get('/extensions/pending', authenticate, isAdmin, getPendingExtensions);
router.get('/extensions/pending-payment', authenticate, isAdmin, getPendingPaymentExtensions);
router.patch('/extensions/:extensionId/approve', authenticate, isAdmin, approveExtension);
router.patch('/extensions/:extensionId/activate', authenticate, isAdmin, activateExtension);

// Custom Tasks — Payment & Payout
router.get('/tasks/pending-payment', authenticate, isAdmin, getPendingTaskPayments);
router.get('/tasks/pending-payment-by-task', authenticate, isAdmin, getPendingTaskPaymentsByTask);
router.get('/tasks/pending-payout', authenticate, isAdmin, getPendingTaskPayouts);
router.patch('/tasks/:tpId/confirm-payment', authenticate, isAdmin, confirmTaskPayment);
router.patch('/tasks/:taskId/confirm-payment-task', authenticate, isAdmin, confirmTaskPaymentByTask);
router.patch('/tasks/:tpId/confirm-payout', authenticate, isAdmin, confirmTaskPayout);

// Reports
router.get('/reports/open', authenticate, isAdmin, getOpenReports);
router.patch('/reports/:reportId/respond', authenticate, isAdmin, respondToReport);

export default router;
