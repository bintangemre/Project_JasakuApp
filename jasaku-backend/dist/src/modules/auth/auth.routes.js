import { Router } from "express";
import { upload } from '../../middleware/upload.middleware';
import { validate } from '../../middleware/validate.middleware';
import { authenticate } from '../../middleware/auth.middleware';
import { isProvider, isAdmin } from '../../middleware/role.middleware';
import { registerCustomerSchema, loginSchema, googleLoginSchema } from '../../middleware/schemas';
import { registerCustomer, registerProvider, login, registerAdmin, loginWithGoogle, getVerificationStatus, resubmitVerification, getMe } from "./auth.controller";
const router = Router();
router.post('/register/customer', validate(registerCustomerSchema), registerCustomer);
router.post('/register/provider', upload.fields([
    { name: 'profile_photo', maxCount: 1 },
    { name: 'ktp_photo', maxCount: 1 },
    { name: 'selfie_photo', maxCount: 1 },
    { name: 'portfolios', maxCount: 5 },
    { name: 'ijazah_photo', maxCount: 1 },
    { name: 'certificate_files', maxCount: 10 },
]), registerProvider);
router.post('/register/admin', authenticate, isAdmin, registerAdmin);
router.post('/login', validate(loginSchema), login);
router.post('/login/google', validate(googleLoginSchema), loginWithGoogle);
router.get('/provider/verification-status', authenticate, isProvider, getVerificationStatus);
router.post('/provider/resubmit-verification', authenticate, isProvider, resubmitVerification);
router.get('/me', authenticate, getMe);
export default router;
