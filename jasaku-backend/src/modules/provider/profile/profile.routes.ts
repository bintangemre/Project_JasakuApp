import { Router } from "express";
import { authenticate } from "../../../middleware/auth.middleware";
import { upload } from "../../../middleware/upload.middleware";
import { getProfile, toggleAvailability, completeOnboarding } from "./profile.controller";

const router = Router();

router.get("/profile", authenticate, getProfile);
router.post("/profile/availability", authenticate, toggleAvailability);
router.patch(
  "/profile/complete",
  authenticate,
  upload.fields([{ name: "profile_photo", maxCount: 1 }]),
  completeOnboarding
);

export default router;
