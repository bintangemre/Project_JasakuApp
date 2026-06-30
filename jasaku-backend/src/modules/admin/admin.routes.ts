import {Router} from 'express';
import {
  getDashboardMetrics, getPendingProviders, verifyProvider, unverifyProvider,
  getCategories, getServicesByCategory, getPricingTypesByCategory,
  createCategory, updateCategory, deleteCategory,
  createService, updateService, deleteService,
  getAllProviders, getAllCustomers, banUser, unbanUser,
  createPricingType, deletePricingType,
  getPaymentAccounts, createPaymentAccount, updatePaymentAccount, deletePaymentAccount,
  uploadQrisImage
} from './admin.controller';
import { authenticate } from '../../middleware/auth.middleware';
import { isAdmin } from '../../middleware/role.middleware';
import { validate } from '../../middleware/validate.middleware';
import { createCategorySchema, createServiceSchema, verifyProviderSchema } from '../../middleware/schemas';
import { upload } from '../../middleware/upload.middleware';

const router = Router();

// Dashboard
router.get('/dashboard', authenticate, isAdmin, getDashboardMetrics);

// Provider verification
router.get('/providers/pending', authenticate, isAdmin, getPendingProviders);
router.patch('/providers/:providerId/verify', authenticate, isAdmin, validate(verifyProviderSchema), verifyProvider);
router.patch('/providers/:providerId/unverify', authenticate, isAdmin, unverifyProvider);
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
router.get('/categories/:id/services', authenticate, isAdmin, getServicesByCategory);
router.post('/services', authenticate, isAdmin, validate(createServiceSchema), createService);
router.put('/services/:id', authenticate, isAdmin, updateService);
router.delete('/services/:id', authenticate, isAdmin, deleteService);

// Pricing Types
router.get('/categories/:id/pricing-types', authenticate, isAdmin, getPricingTypesByCategory);
router.post('/pricing-types', authenticate, isAdmin, createPricingType);
router.delete('/pricing-types/:id', authenticate, isAdmin, deletePricingType);

// Payment Accounts (Rekber Admin)
router.get('/payment-accounts', authenticate, isAdmin, getPaymentAccounts);
router.post('/payment-accounts', authenticate, isAdmin, createPaymentAccount);
router.put('/payment-accounts/:id', authenticate, isAdmin, updatePaymentAccount);
router.delete('/payment-accounts/:id', authenticate, isAdmin, deletePaymentAccount);
router.post('/payment-accounts/:id/qris-upload', authenticate, isAdmin, upload.single('qris'), uploadQrisImage);

export default router;
