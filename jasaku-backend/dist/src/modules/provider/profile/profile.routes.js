import { Router } from "express";
import { authenticate } from "../../../middleware/auth.middleware";
import { getProfile, toggleAvailability } from "./profile.controller";
const router = Router();
router.get("/profile", authenticate, getProfile);
router.post("/profile/availability", authenticate, toggleAvailability);
export default router;
