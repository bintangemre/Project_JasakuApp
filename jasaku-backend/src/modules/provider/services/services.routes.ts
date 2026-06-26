import { Router } from 'express';
import { authenticate } from '../../../middleware/auth.middleware';
import { getAvailableServices, getAvailablePricingTypes, getProviderServices, updateProviderService } from './services.controller';

const router = Router();

// Public endpoints - tanpa autentikasi
router.get('/available-services', getAvailableServices);
router.get('/available-pricing-types', getAvailablePricingTypes);

// Protected endpoints - memerlukan autentikasi
router.get('/services', authenticate, getProviderServices);
router.put('/services/update-service', authenticate, updateProviderService);

export default router;
