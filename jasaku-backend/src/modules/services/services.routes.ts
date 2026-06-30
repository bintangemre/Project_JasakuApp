import { Router } from "express";
import { getAllCategories, getCategoriesById, getProvidersByService, getServiceOptions, getServicePricingTypes, getProvidersByServiceWithoutDistance } from "./services.controller";
import { authenticate } from "../../middleware/auth.middleware";
import { isCustomer, isAny } from "../../middleware/role.middleware";

const router = Router();

router.get('/categories', authenticate, isAny, getAllCategories);
router.get('/categories/:id', authenticate, isAny, getCategoriesById);
router.get('/services/providers', authenticate, isCustomer, getProvidersByService);
router.get('/services/:providerId/:serviceId/options', authenticate, isCustomer, getServiceOptions);
router.get('/services/:serviceId/data', authenticate, isCustomer, getServicePricingTypes);
router.get('/services/providers/non-location/:serviceId', authenticate, isCustomer, getProvidersByServiceWithoutDistance);

export default router;


