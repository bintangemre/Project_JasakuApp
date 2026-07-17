import { Router } from "express";
import multer from "multer";
import { authenticate } from "../../../middleware/auth.middleware";
import { upload } from "../../../middleware/upload.middleware";
import { getProfile, toggleAvailability, toggleTaskAvailability, completeOnboarding, updateProfile, getCounts } from "./profile.controller";
const router = Router();
function handleMulterError(err, req, res, next) {
    if (err instanceof multer.MulterError) {
        if (err.code === "LIMIT_FILE_SIZE") {
            return res.status(400).json({ success: false, message: "Ukuran file melebihi 10 MB" });
        }
        if (err.code === "LIMIT_UNEXPECTED_FILE") {
            return res.status(400).json({ success: false, message: `Field file tidak terduga: ${err.field}` });
        }
        return res.status(400).json({ success: false, message: err.message });
    }
    if (err) {
        return res.status(400).json({ success: false, message: err.message });
    }
    next();
}
router.get("/counts", authenticate, getCounts);
router.get("/profile", authenticate, getProfile);
router.post("/profile/availability", authenticate, toggleAvailability);
router.post("/profile/task-availability", authenticate, toggleTaskAvailability);
router.patch("/profile/complete", authenticate, upload.fields([{ name: "profile_photo", maxCount: 1 }]), handleMulterError, completeOnboarding);
router.patch("/profile", authenticate, upload.fields([
    { name: "profile_photo", maxCount: 1 },
    { name: "portfolios", maxCount: 5 },
    { name: "ktp_photo", maxCount: 1 },
    { name: "selfie_photo", maxCount: 1 },
    { name: "documents", maxCount: 5 },
]), handleMulterError, updateProfile);
export default router;
