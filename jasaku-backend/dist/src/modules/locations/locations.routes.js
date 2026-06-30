import { Router } from "express";
import { updateLocation, getProviderLocation } from "./locations.controller";
import { authenticate } from "../../middleware/auth.middleware";
const router = Router();
router.put("/update", authenticate, updateLocation);
router.get("/provider/:providerId", authenticate, getProviderLocation);
export default router;
