import { Router } from 'express';
import { createReport, getMyReports } from './reports.controller';
import { authenticate } from '../../middleware/auth.middleware';

const router = Router();

router.post('/', authenticate, createReport);
router.get('/mine', authenticate, getMyReports);

export default router;
