import { Response } from "express";
import { prisma } from "../../../config/prisma";
import { AuthRequest } from "../../../middleware/auth.middleware";
import { successResponse, errorResponse } from "../../../utils/response";
import { ProfileService } from "./profile.service";

const getProfile = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return errorResponse(res, "Anda harus login terlebih dahulu", 401);
    }

    const provider = await prisma.users.findUnique({
      where: { id: userId },
      select: {
        provider_profiles: { select: { id: true } },
      },
    });

    const profileId = provider?.provider_profiles?.id;
    if (!profileId) {
      return errorResponse(res, "Profil provider tidak ditemukan", 404);
    }

    const [completedJobs, ratingAgg] = await Promise.all([
      prisma.orders.count({
        where: { provider_id: profileId, status: "completed" },
      }),
      prisma.reviews.aggregate({
        where: { provider_id: userId },
        _avg: { rating: true },
        _count: true,
      }),
    ]);

    await prisma.provider_profiles.update({
      where: { id: profileId },
      data: {
        total_jobs: completedJobs,
        total_reviews: ratingAgg._count,
        rating: ratingAgg._avg.rating ?? 0,
      },
    });

    const profile = await prisma.provider_profiles.findUnique({
      where: { id: profileId },
      select: {
        full_name: true,
        nickname: true,
        profile_photo: true,
        rating: true,
        total_jobs: true,
        total_reviews: true,
        is_active: true,
      },
    });

    const servicesCount = await prisma.provider_services.count({
      where: { provider_id: userId },
    });

    return successResponse(res, {
      ...profile,
      rating: profile!.rating ? Number(profile!.rating) : 0,
      services_count: servicesCount,
    }, "Profil provider berhasil diambil");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const toggleAvailability = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return errorResponse(res, "Anda harus login terlebih dahulu", 401);
    }

    const profile = await prisma.provider_profiles.findUnique({
      where: { user_id: userId },
      select: { is_active: true },
    });

    if (!profile) {
      return errorResponse(res, "Profil provider tidak ditemukan", 404);
    }

    const newStatus = !profile.is_active;

    await prisma.provider_profiles.update({
      where: { user_id: userId },
      data: { is_active: newStatus },
    });

    return successResponse(res, { is_active: newStatus }, newStatus ? "Siap menerima pesanan" : "Sedang tidak menerima pesanan");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const completeOnboarding = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return errorResponse(res, "Anda harus login terlebih dahulu", 401);
    }

    const profile = await prisma.provider_profiles.findUnique({
      where: { user_id: userId },
      select: { id: true, onboarding_completed: true },
    });

    if (!profile) {
      return errorResponse(res, "Profil provider tidak ditemukan", 404);
    }

    if (profile.onboarding_completed) {
      return successResponse(res, null, "Profil sudah lengkap");
    }

    const files = req.files as { [fieldname: string]: Express.Multer.File[] } | undefined;
    const profilePhoto = files?.['profile_photo']?.[0]?.path;

    let services: any = req.body.services;
    if (typeof services === 'string') {
      services = JSON.parse(services);
    }

    let payoutMethod: any = req.body.payoutMethod;
    if (typeof payoutMethod === 'string') {
      payoutMethod = JSON.parse(payoutMethod);
    }

    await new ProfileService().completeOnboarding(userId, {
      profile_photo: profilePhoto,
      services,
      payoutMethod,
    });

    return successResponse(res, null, "Profil berhasil dilengkapi");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export { getProfile, toggleAvailability, completeOnboarding };
