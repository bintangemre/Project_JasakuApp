import { Router } from "express";
import { authenticate } from "../../../middleware/auth.middleware";
import { upload } from "../../../middleware/upload.middleware";
import { getProfile, updateProfile } from "./profile.controller";
const router = Router();
router.get("/profile", authenticate, getProfile);
router.patch("/profile", authenticate, upload.single("avatar"), updateProfile);
export default router;
