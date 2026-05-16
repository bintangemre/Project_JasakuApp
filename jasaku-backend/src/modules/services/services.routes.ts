import { Router } from "express";
import { getAllCategories, getCategoriesById, getServiceOptions, getServicePricingTypes } from "./services.controller";
import { authenticate } from "../../middleware/auth.middleware";
import { isCustomer } from "../../middleware/role.middleware";

const router = Router();

router.get('/categories', authenticate, isCustomer, getAllCategories);
router.get('/categories/:id', authenticate, isCustomer, getCategoriesById);
router.get('/services/:providerId/:serviceId/options', authenticate, isCustomer, getServiceOptions);
router.get('/services/:serviceId/pricing-types', authenticate, isCustomer, getServicePricingTypes);

export default router;