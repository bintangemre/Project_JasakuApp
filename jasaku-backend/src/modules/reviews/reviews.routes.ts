import {Router} from 'express';
import { createReview, getProviderReviews } from './reviews.controller';
import { authenticate } from '../../middleware/auth.middleware';
import { isCustomer } from '../../middleware/role.middleware';
import { validate } from '../../middleware/validate.middleware';
import { createReviewSchema } from '../../middleware/schemas';

const router = Router();

router.post('/reviews', authenticate, isCustomer, validate(createReviewSchema), createReview);
router.get('/reviews/provider/:providerId', authenticate, getProviderReviews);

export default router;
