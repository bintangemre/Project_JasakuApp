import { Response } from "express";
import { LocationService } from "./locations.service";
import { successResponse, errorResponse } from "../../utils/response";
import { AuthRequest } from "../../middleware/auth.middleware";

const locationService = new LocationService();

const updateLocation = async (req: AuthRequest, res: Response) => {
    try {
        const userId = req.user?.userId;
        const { lat, lng, address } = req.body;

        if (!userId) return errorResponse(res, 'Akses ditolak: User tidak valid', 401);
        if (!lat || !lng) return errorResponse(res, 'Latitude dan Longitude wajib diisi', 400);

        await locationService.updateProviderLocation(userId, lat, lng, address);

        return successResponse(res, null, 'Lokasi provider berhasil diperbarui secara real-time');
    } catch (error: any) {
        return errorResponse(res, error.message);
    }
};

const getProviderLocation = async (req: AuthRequest, res: Response) => {
    try {
        const providerId = req.params.providerId as string;
        if (!providerId) return errorResponse(res, 'ID provider wajib diisi', 400);

        const location = await locationService.getProviderLocation(providerId);
        if (!location) {
            return successResponse(res, null, 'Lokasi provider belum tersedia');
        }

        return successResponse(res, location, 'Lokasi provider berhasil diambil');
    } catch (error: any) {
        return errorResponse(res, error.message);
    }
};

export { updateLocation, getProviderLocation };