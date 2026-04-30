import { Router } from "express";
import { registerCustomer, registerProvider, login } from "./auth.controller";

const router = Router();

router.post('/register/customer', registerCustomer);
router.post('/register/provider', registerProvider);
router.post('/login', login);

export default router;