import { successResponse, errorResponse } from "../../../utils/response";
import * as profileService from "./profile.service";
export const getProfile = async (req, res, next) => {
    try {
        const userId = req.user?.userId;
        if (!userId)
            return errorResponse(res, "Unauthorized", 401);
        const result = await profileService.getCustomerProfile(userId);
        return successResponse(res, result, "Profil berhasil diambil");
    }
    catch (error) {
        next(error);
    }
};
export const updateProfile = async (req, res, next) => {
    try {
        const userId = req.user?.userId;
        if (!userId)
            return errorResponse(res, "Unauthorized", 401);
        const { full_name, nickname, birth_date, gender, phone, address } = req.body;
        const avatarPath = req.file ? `/uploads/${req.file.filename}` : undefined;
        const result = await profileService.updateCustomerProfile(userId, { full_name, nickname, birth_date, gender, phone, address }, avatarPath);
        return successResponse(res, result, "Profil berhasil diperbarui");
    }
    catch (error) {
        next(error);
    }
};
