import { Router } from "express";
import { upload } from '../../middleware/upload.middleware';
import { validate } from '../../middleware/validate.middleware';
import { authenticate } from '../../middleware/auth.middleware';
import { isProvider, isAdmin } from '../../middleware/role.middleware';
import { registerCustomerSchema, loginSchema, googleLoginSchema, sendOtpSchema, verifyOtpSchema } from '../../middleware/schemas';
import { registerCustomer, registerProvider, login, registerAdmin, loginWithGoogle, sendOtp, verifyOtp, getVerificationStatus, resubmitVerification } from "./auth.controller";
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
router.post('/send-otp', validate(sendOtpSchema), sendOtp);
router.post('/verify-otp', validate(verifyOtpSchema), verifyOtp);
router.get('/provider/verification-status', authenticate, isProvider, getVerificationStatus);
router.post('/provider/resubmit-verification', authenticate, isProvider, resubmitVerification);
export default router;
