import { Router } from 'express';
import { authenticate } from '../../middleware/auth.middleware';
import { upload } from '../../middleware/upload.middleware';
import { uploadFile } from './upload.controller';

const router = Router();

router.post('/upload', authenticate, upload.single('file'), uploadFile);

export default router;
