import { Router } from "express";
import { getAllCategories, getCategoriesById } from "./services.controller";
import { authenticate } from "../../middleware/auth.middleware";
import { isCustomer } from "../../middleware/role.middleware";

const router = Router();

router.get('/categories', authenticate, isCustomer, getAllCategories);
router.get('/categories/:id', authenticate, isCustomer, getCategoriesById);

export default router;