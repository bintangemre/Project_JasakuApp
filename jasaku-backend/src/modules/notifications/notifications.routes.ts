import {Router} from 'express';
import { sendNotificationToUser } from './notifications.controller';
import { authenticate } from '../../middleware/auth.middleware';

const router = Router();

router.post('/notifications/send', authenticate, sendNotificationToUser);

export default router;
