import { Response } from "express";
import { ProviderServicesService } from "./services.service";
import { successResponse, errorResponse } from "../../../utils/response";
import { AuthRequest } from "../../../middleware/auth.middleware";
import { prisma } from "../../../config/prisma";

const getAvailableServices = async (req: any, res: Response) => {
    try {
        const services = await prisma.services.findMany({
            include: {
                categories: true
            }
        });
        return successResponse(res, services, 'Layanan tersedia berhasil diambil');
    } catch (err: any) {
        return errorResponse(res, err.message);
    }
};

const getAvailablePricingUnits = async (req: any, res: Response) => {
    try {
        const pricingUnits = await prisma.pricing_units.findMany({
            include: {
                categories: true
            }
        });
        return successResponse(res, pricingUnits, 'Unit harga tersedia berhasil diambil');
    } catch (err: any) {
        return errorResponse(res, err.message);
    }
};

const getAvailableContractTypes = async (req: any, res: Response) => {
    try {
        const contractTypes = await prisma.contract_types.findMany();
        return successResponse(res, contractTypes, 'Tipe kontrak tersedia berhasil diambil');
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

export { getAvailableServices, getAvailablePricingUnits, getAvailableContractTypes, getProviderServices, updateProviderService };
