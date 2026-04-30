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

export { getAllCategories, getCategoriesById };