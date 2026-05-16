import { Router } from "express";
import { updateLocation } from "./locations.controller";
import { authenticate } from "../../middleware/auth.middleware"; // Pastikan path benar

const router = Router();

// Endpoint untuk update lokasi provider
router.put("/update", authenticate, updateLocation);

export default router;