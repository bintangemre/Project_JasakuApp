import { Response } from "express";
import { ReviewsService } from "./reviews.service";
import { AuthRequest } from "../../middleware/auth.middleware";
import { successResponse, errorResponse } from "../../utils/response";

const createReview = async (req: AuthRequest, res: Response) => {
  try {
    const customerId = req.user?.userId;
    if (!customerId) return errorResponse(res, "Anda harus login terlebih dahulu", 401);

    const { orderId, providerId, rating, review } = req.body;
    if (!orderId || !providerId || !rating) {
      return errorResponse(res, "orderId, providerId, dan rating wajib diisi", 400);
    }
    if (rating < 1 || rating > 5) {
      return errorResponse(res, "Rating harus antara 1-5", 400);
    }

    // Cek apakah sudah pernah review
    const existing = await new ReviewsService().getReviewByOrder(orderId);
    if (existing) {
      return errorResponse(res, "Order ini sudah pernah direview", 409);
    }

    const result = await new ReviewsService().createReview(customerId, orderId, providerId, rating, review);
    return successResponse(res, result, "Review berhasil dikirim", 201);
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const getProviderReviews = async (req: AuthRequest, res: Response) => {
  try {
    const providerId = String(req.params.providerId);
    const result = await new ReviewsService().getProviderReviews(providerId);
    return successResponse(res, result, "Daftar review berhasil diambil");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export { createReview, getProviderReviews };
