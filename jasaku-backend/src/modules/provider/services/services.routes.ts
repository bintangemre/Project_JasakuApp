import { Router } from 'express';
import { authenticate } from '../../../middleware/auth.middleware';
import { postProviderService, getProviderServices, updateProviderService } from './services.controller';

const router = Router();

router.post('/services', authenticate, postProviderService);
router.get('/services', authenticate, getProviderServices);
router.put('/services', authenticate, updateProviderService);

export default router;