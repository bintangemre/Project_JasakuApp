import { Router } from 'express';
import { createOrder, getOrderDetails, getOrderExtensions, receiveOrderStatus, getProviderOrders, getCustomerOrders, cancelOrder, getTodayOrders, getProviderSchedule, getProviderRequests, getOrderTracking, requestExtension, approveExtension, respondToExtension, activateExtension, getPaymentAccounts, getPublicProviderStatus, getPublicProviderSchedule } from './orders.controller';
import { authenticate } from '../../middleware/auth.middleware';
import { isCustomer, isProvider, isAny, isAdmin } from '../../middleware/role.middleware';
import { validate } from '../../middleware/validate.middleware';
import { createOrderSchema, updateOrderStatusSchema } from '../../middleware/schemas';
const router = Router();
router.post('/orders', authenticate, isCustomer, validate(createOrderSchema), createOrder);
router.get('/orders/:orderId', authenticate, getOrderDetails);
router.patch('/orders/:orderId/status', authenticate, isAny, validate(updateOrderStatusSchema), receiveOrderStatus);
router.post('/orders/:orderId/cancel', authenticate, isCustomer, cancelOrder);
router.get('/orders/:orderId/tracking', authenticate, getOrderTracking);
router.get('/orders/:orderId/extensions', authenticate, getOrderExtensions);
router.get('/provider/orders', authenticate, isProvider, getProviderOrders);
router.get('/provider/requests', authenticate, isProvider, getProviderRequests);
router.get('/provider/today', authenticate, isProvider, getTodayOrders);
router.get('/provider/schedule', authenticate, isProvider, getProviderSchedule);
router.get('/customer/orders', authenticate, isCustomer, getCustomerOrders);
// Public / Customer - lihat status & jadwal mitra
router.get('/provider/:providerId/status', authenticate, getPublicProviderStatus);
router.get('/provider/:providerId/schedule', authenticate, getPublicProviderSchedule);
// Payment accounts (public — customer needs to know where to transfer)
router.get('/payment-accounts', authenticate, getPaymentAccounts);
// Extension
router.post('/orders/:orderId/extend', authenticate, isProvider, requestExtension);
router.post('/extensions/:extensionId/respond', authenticate, isCustomer, respondToExtension);
router.post('/extensions/:extensionId/activate', authenticate, isAdmin, activateExtension);
router.patch('/extensions/:extensionId/approve', authenticate, isAdmin, approveExtension);
export default router;
