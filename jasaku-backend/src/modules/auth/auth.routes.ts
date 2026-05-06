import { Router } from "express";
import { registerCustomer, registerProvider, login, registerAdmin } from "./auth.controller";

const router = Router();

router.post('/register/customer', registerCustomer);
router.post('/register/provider', registerProvider);
router.post('/register/admin', registerAdmin);
router.post('/login', login);

export default router;