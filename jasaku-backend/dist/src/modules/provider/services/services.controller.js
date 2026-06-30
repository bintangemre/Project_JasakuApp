import { ProviderServicesService } from "./services.service";
import { successResponse, errorResponse } from "../../../utils/response";
import { prisma } from "../../../config/prisma";
const getAvailableServices = async (req, res) => {
    try {
        const services = await prisma.services.findMany({
            include: {
                categories: true
            }
        });
        return successResponse(res, services, 'Layanan tersedia berhasil diambil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const getAvailablePricingTypes = async (req, res) => {
    try {
        const pricingTypes = await prisma.pricing_types.findMany({
            include: {
                categories: true
            }
        });
        return successResponse(res, pricingTypes, 'Tipe pricing tersedia berhasil diambil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const getProviderServices = async (req, res) => {
    try {
        const userId = req.user?.userId;
        if (!userId) {
            return errorResponse(res, 'Anda harus login terlebih dahulu', 401);
        }
        const providerServices = new ProviderServicesService();
        const result = await providerServices.getProviderServices(userId);
        return successResponse(res, result, 'Layanan provider berhasil diambil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const updateProviderService = async (req, res) => {
    try {
        const userId = req.user?.userId;
        if (!userId) {
            return errorResponse(res, 'Anda harus login terlebih dahulu', 401);
        }
        const { serviceId, description, prices } = req.body;
        // Tambahkan validasi input seperti pada fungsi POST
        if (!serviceId || !description || !prices) {
            return errorResponse(res, 'serviceId, description, dan prices harus diisi', 400);
        }
        const providerService = new ProviderServicesService();
        const result = await providerService.updateProviderService(userId, serviceId, description, prices);
        return successResponse(res, result, 'Layanan berhasil diperbarui');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
export { getAvailableServices, getAvailablePricingTypes, getProviderServices, updateProviderService };
