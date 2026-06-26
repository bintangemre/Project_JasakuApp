import { LocationService } from "./locations.service";
import { successResponse, errorResponse } from "../../utils/response";
// Inisialisasi Service
const locationService = new LocationService();
const updateLocation = async (req, res) => {
    try {
        const userId = req.user?.userId;
        const { lat, lng, address } = req.body;
        // Validasi Dasar
        if (!userId)
            return errorResponse(res, 'Akses ditolak: User tidak valid', 401);
        if (!lat || !lng)
            return errorResponse(res, 'Latitude dan Longitude wajib diisi', 400);
        // Panggil service untuk eksekusi ke database
        await locationService.updateProviderLocation(userId, lat, lng, address);
        return successResponse(res, null, 'Lokasi provider berhasil diperbarui secara real-time');
    }
    catch (error) {
        return errorResponse(res, error.message);
    }
};
export { updateLocation };
