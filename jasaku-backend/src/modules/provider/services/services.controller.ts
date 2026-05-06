import { Response } from "express";
import { ProviderServicesService } from "./services.service";
import { successResponse, errorResponse } from "../../../utils/response";
import { AuthRequest } from "../../../middleware/auth.middleware";


const postProviderService = async (req: AuthRequest, res: Response) => {
    try {
        const userId = req.user?.userId;
        if (!userId) {
            return errorResponse(res, 'Anda harus login terlebih dahulu', 401);
        }   
        const { serviceId, description, prices } = req.body;
        if (!serviceId || !description || !prices) {
            return errorResponse(res, 'serviceId, description, dan prices harus diisi', 400);
        }
        const providerServices = new ProviderServicesService();
        const result = await providerServices.addProviderService(userId, serviceId, description, prices);
        return successResponse(res, result, 'Layanan berhasil ditambahkan');
    } catch (err: any) {
        return errorResponse(res, err.message);
    }
};

const getProviderServices = async (req: AuthRequest, res: Response) => {    
    try {
        const userId = req.user?.userId;
        if (!userId) {
            return errorResponse(res, 'Anda harus login terlebih dahulu', 401);
        }
        const providerServices = new ProviderServicesService();
        const result = await providerServices.getProviderServices(userId);
        return successResponse(res, result, 'Layanan provider berhasil diambil');
    }
    catch (err: any) {
        return errorResponse(res, err.message);
    }
};

const updateProviderService = async (req: AuthRequest, res: Response) => {
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
        const result = await providerService.updateProviderService(
            userId,
            serviceId,
            description,
            prices
        );

        return successResponse(res, result, 'Layanan berhasil diperbarui');
    } catch (err: any) {
        return errorResponse(res, err.message);
    }
};

export { postProviderService, getProviderServices, updateProviderService };