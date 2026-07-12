import { Request, Response, NextFunction } from "express";
import { successResponse, errorResponse } from "../../../utils/response";
import { AuthRequest } from "../../../middleware/auth.middleware";
import * as profileService from "./profile.service";
import { uploadToStorage } from "../../../services/storage.service";

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

        const { full_name, nickname, birth_date, gender, phone, address } = req.body;

        let avatarUrl: string | undefined;
        const file = (req as any).file;
        if (file) {
            avatarUrl = await uploadToStorage(file.buffer, 'customer/avatar', file.originalname);
        }

        const result = await profileService.updateCustomerProfile(
            userId,
            { full_name, nickname, birth_date, gender, phone, address },
            avatarUrl
        );
        return successResponse(res, result, "Profil berhasil diperbarui");
    } catch (error: any) {
        next(error);
    }
};
