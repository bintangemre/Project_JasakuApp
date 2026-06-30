import { Request, Response, NextFunction } from "express";
import { successResponse, errorResponse } from "../../../utils/response";
import { AuthRequest } from "../../../middleware/auth.middleware";
import * as profileService from "./profile.service";

export const getProfile = async (req: Request, res: Response, next: NextFunction) => {
    try {
        const userId = (req as AuthRequest).user?.userId;
        if (!userId) return errorResponse(res, "Unauthorized", 401);
        const result = await profileService.getCustomerProfile(userId);
        return successResponse(res, result, "Profil berhasil diambil");
    } catch (error: any) {
        next(error);
    }
};

export const updateProfile = async (req: Request, res: Response, next: NextFunction) => {
    try {
        const userId = (req as AuthRequest).user?.userId;
        if (!userId) return errorResponse(res, "Unauthorized", 401);

        const { full_name, nickname } = req.body;
        const avatarPath = (req as any).file ? `/uploads/${(req as any).file.filename}` : undefined;

        const result = await profileService.updateCustomerProfile(userId, { full_name, nickname }, avatarPath);
        return successResponse(res, result, "Profil berhasil diperbarui");
    } catch (error: any) {
        next(error);
    }
};
