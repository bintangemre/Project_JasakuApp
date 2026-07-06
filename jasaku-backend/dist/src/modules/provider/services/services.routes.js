import { Router } from 'express';
import { authenticate } from '../../../middleware/auth.middleware';
import { getAvailableServices, getAvailablePricingTypes, getProviderServices, updateProviderService } from './services.controller';
const router = Router();
// Public endpoints - tanpa autentikasi
router.get('/available-services', getAvailableServices);
router.get('/available-pricing-types', getAvailablePricingTypes);
// Protected endpoints - memerlukan autentikasi
router.get('/', authenticate, getProviderServices);
router.put('/update-service', authenticate, updateProviderService);
export default router;
