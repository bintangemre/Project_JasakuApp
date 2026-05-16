import { Response } from "express";
import { CategoriesService } from "./services.service";
import { successResponse, errorResponse } from "../../utils/response";
import { AuthRequest } from "../../middleware/auth.middleware";

const getAllCategories = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return errorResponse(res, 'Anda harus login terlebih dahulu', 401);
    }
    const categoriesService = new CategoriesService();
    const result = await categoriesService.getallCategories(userId);
    return successResponse(res, result, 'Kategori berhasil diambil');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const getCategoriesById = async (req: AuthRequest & { params: { id: string } }, res: Response) => {
  try {
    const userId = req.user?.userId;
    const { id } = req.params;
    if (!userId) {
      return errorResponse(res, 'Anda harus login terlebih dahulu', 401);
    }
    const categoriesService = new CategoriesService();
    const result = await categoriesService.getCategoriesById(id, userId);
    return successResponse(res, result, 'Kategori berhasil diambil');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const getNearbyProviders = async (req: AuthRequest, res: Response) => {
    try {
        const { serviceId } = req.params;
        const { lat, lng } = req.query; // Ambil lat/lng dari query params di Flutter
        const userId = req.user?.userId;

        if (!lat || !lng) return errorResponse(res, 'Lokasi Anda diperlukan untuk mencari tukang terdekat', 400);

        const categoriesService = new CategoriesService();
        const result = await categoriesService.getProvidersByService(
        serviceId as string, // Tambahkan 'as string' di sini
        parseFloat(lat as string),
        parseFloat(lng as string)
);
        return successResponse(res, result, 'Daftar provider terdekat berhasil diambil');
    } catch (err: any) {
        return errorResponse(res, err.message);
    }
};

const getServiceOptions = async (req: AuthRequest & { params: { providerId: string, serviceId: string } }, res: Response) => {
  try {
    const userId = req.user?.userId;
    const { providerId, serviceId } = req.params;
    if (!userId) {
      return errorResponse(res, 'Anda harus login terlebih dahulu', 401);
    }
    const categoriesService = new CategoriesService();
    const result = await categoriesService.getServiceOptions(providerId, serviceId);
    return successResponse(res, result, 'Opsi layanan berhasil diambil');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const getServicePricingTypes = async (req: AuthRequest & { params: { serviceId: string } }, res: Response) => {
  try {
    const userId = req.user?.userId;
    const { serviceId } = req.params;
    if (!userId) {
      return errorResponse(res, 'Anda harus login terlebih dahulu', 401);
    }
    const categoriesService = new CategoriesService();
    const result = await categoriesService.getServicePricingTypes(serviceId, userId);
    return successResponse(res, result, 'Metode pengerjaan berhasil diambil');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export { getAllCategories, getCategoriesById, getNearbyProviders, getServiceOptions, getServicePricingTypes };