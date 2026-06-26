import { CategoriesService } from "./services.service";
import { successResponse, errorResponse } from "../../utils/response";
const getAllCategories = async (req, res) => {
    try {
        const userId = req.user?.userId;
        if (!userId) {
            return errorResponse(res, 'Anda harus login terlebih dahulu', 401);
        }
        const categoriesService = new CategoriesService();
        const result = await categoriesService.getAllCategories();
        return successResponse(res, result, 'Daftar kategori berhasil diambil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const getCategoriesById = async (req, res) => {
    try {
        const userId = req.user?.userId;
        const { id } = req.params;
        if (!userId) {
            return errorResponse(res, 'Anda harus login terlebih dahulu', 401);
        }
        const categoriesService = new CategoriesService();
        const result = await categoriesService.getCategoriesById(id);
        return successResponse(res, result, 'Kategori berhasil diambil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const getProvidersByService = async (req, res) => {
    try {
        const userId = req.user?.userId;
        const { serviceId, lat, lng } = req.query;
        if (!userId) {
            return errorResponse(res, 'Anda harus login terlebih dahulu', 401);
        }
        if (!serviceId || !lat || !lng) {
            return errorResponse(res, 'serviceId, lat, dan lng wajib diisi', 400);
        }
        const categoriesService = new CategoriesService();
        const result = await categoriesService.getProvidersByService({
            serviceId: String(serviceId),
            lat: parseFloat(String(lat)),
            lng: parseFloat(String(lng)),
        });
        return successResponse(res, result, 'Daftar provider berhasil diambil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
// sebagai contoh tampilan nya
const getProvidersByServiceWithoutDistance = async (req, res) => {
    try {
        const userId = req.user?.userId;
        const { serviceId } = req.params;
        if (!userId) {
            return errorResponse(res, 'Anda harus login terlebih dahulu', 401);
        }
        if (!serviceId) {
            return errorResponse(res, 'serviceId wajib diisi', 400);
        }
        // Ambil data dari service (Lengkapi bagian ini)
        const categoriesService = new CategoriesService();
        const result = await categoriesService.getProvidersByServiceWithoutDistance(serviceId);
        return successResponse(res, result, 'Daftar provider tanpa jarak berhasil diambil');
    }
    catch (err) {
        // Blok catch yang sebelumnya hilang wajib ditambahkan
        return errorResponse(res, err.message);
    }
};
const getServiceOptions = async (req, res) => {
    try {
        const userId = req.user?.userId;
        const { providerId, serviceId } = req.params;
        if (!userId) {
            return errorResponse(res, 'Anda harus login terlebih dahulu', 401);
        }
        const categoriesService = new CategoriesService();
        const result = await categoriesService.getServiceOptions(providerId, serviceId);
        return successResponse(res, result, 'Opsi layanan berhasil diambil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const getServicePricingTypes = async (req, res) => {
    try {
        const userId = req.user?.userId;
        const { serviceId } = req.params;
        if (!userId) {
            return errorResponse(res, 'Anda harus login terlebih dahulu', 401);
        }
        const categoriesService = new CategoriesService();
        const result = await categoriesService.getServicePricingTypes(serviceId);
        return successResponse(res, result, 'Metode pengerjaan berhasil diambil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
export { getAllCategories, getCategoriesById, getProvidersByService, getServiceOptions, getServicePricingTypes, getProvidersByServiceWithoutDistance };
