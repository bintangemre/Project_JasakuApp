import { Router } from "express";
import { registerCustomer, registerProvider, login, registerAdmin, loginWithGoogle } from "./auth.controller";
const router = Router();
router.post('/register/customer', registerCustomer);
router.post('/register/provider', registerProvider);
router.post('/register/admin', registerAdmin);
router.post('/login', login);
router.post('/login/google', loginWithGoogle);
export default router;
