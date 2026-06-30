import {Router} from 'express';
import { sendNotificationToUser, registerDevice } from './notifications.controller';
import { authenticate } from '../../middleware/auth.middleware';
import { validate } from '../../middleware/validate.middleware';
import { registerDeviceSchema } from '../../middleware/schemas';

const router = Router();

router.post('/notifications/send', authenticate, sendNotificationToUser);
router.post('/devices/register', authenticate, validate(registerDeviceSchema), registerDevice);

export default router;
