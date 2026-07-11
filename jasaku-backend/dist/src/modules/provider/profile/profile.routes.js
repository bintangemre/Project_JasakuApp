import { Router } from "express";
import { authenticate } from "../../../middleware/auth.middleware";
import { upload } from "../../../middleware/upload.middleware";
import { getProfile, toggleAvailability, toggleTaskAvailability, completeOnboarding, updateProfile } from "./profile.controller";
const router = Router();
router.get("/profile", authenticate, getProfile);
router.post("/profile/availability", authenticate, toggleAvailability);
router.post("/profile/task-availability", authenticate, toggleTaskAvailability);
router.patch("/profile/complete", authenticate, upload.fields([{ name: "profile_photo", maxCount: 1 }]), completeOnboarding);
router.patch("/profile", authenticate, upload.fields([
    { name: "profile_photo", maxCount: 1 },
    { name: "portfolios", maxCount: 5 },
    { name: "ktp_photo", maxCount: 1 },
    { name: "selfie_photo", maxCount: 1 },
    { name: "documents", maxCount: 5 },
]), updateProfile);
export default router;
