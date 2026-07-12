import { Response } from "express";
import { prisma } from "../../../config/prisma";
import { AuthRequest } from "../../../middleware/auth.middleware";
import { successResponse, errorResponse } from "../../../utils/response";
import { ProfileService } from "./profile.service";
import { uploadToStorage } from "../../../services/storage.service";

function normalizePath(p: string | null | undefined): string | null {
  if (!p) return null;
  if (p.startsWith('http://') || p.startsWith('https://')) return p;
  return p.startsWith('/') ? p : `/${p}`;
}

function normalizePaths(profile: any) {
  return {
    profile_photo: normalizePath(profile.profile_photo),
    ktp_photo: normalizePath(profile.ktp_photo),
    selfie_photo: normalizePath(profile.selfie_photo),
    portfolios: (profile.portfolios || []).map((p: string) => normalizePath(p)),
  };
}

const getProfile = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return errorResponse(res, "Anda harus login terlebih dahulu", 401);
    }

    const [completedJobs, ratingAgg] = await Promise.all([
      prisma.orders.count({
        where: {
          provider_profiles: { user_id: userId },
          status: "completed",
        },
      }),
      prisma.reviews.aggregate({
        where: { provider_id: userId },
        _avg: { rating: true },
        _count: true,
      }),
    ]);

    await prisma.provider_profiles.update({
      where: { user_id: userId },
      data: {
        total_jobs: completedJobs,
        total_reviews: ratingAgg._count,
        rating: ratingAgg._avg.rating ?? 0,
      },
    });

    const result = await new ProfileService().getFullProfile(userId);
    const { profile, services, payoutMethods } = result;

    if (!profile) {
      return errorResponse(res, "Profil provider tidak ditemukan", 404);
    }

    const user = await prisma.users.findUnique({
      where: { id: userId },
      select: { email: true },
    });

    const paths = normalizePaths(profile);

    return successResponse(res, {
      id: profile.id,
      user_id: profile.user_id,
      full_name: profile.full_name,
      nickname: profile.nickname,
      gender: profile.gender,
      birth_date: profile.birth_date,
      phone: profile.phone,
      address: profile.address,
      domicile: profile.domicile,
      profile_photo: paths.profile_photo,
      ktp_photo: paths.ktp_photo,
      selfie_photo: paths.selfie_photo,
      portfolios: paths.portfolios,
      is_verified: profile.is_verified,
      verification_status: profile.verification_status,
      verification_notes: profile.verification_notes,
      is_active: profile.is_active,
      task_available: profile.task_available,
      onboarding_completed: profile.onboarding_completed,
      rating: profile.rating ? Number(profile.rating) : 0,
      total_jobs: profile.total_jobs,
      total_reviews: profile.total_reviews,
      email: user?.email || null,
      services_count: services.length,
      services: services.map((s: any) => ({
        id: s.id,
        service_id: s.service_id,
        name: s.services?.name || '',
        description: s.description,
        prices: s.provider_service_prices?.map((p: any) => ({
          id: p.id,
          pricing_type_id: p.pricing_type_id,
          pricing_type_name: p.pricing_types?.name || '',
          price: p.price ? Number(p.price) : 0,
          unit: p.unit || p.pricing_types?.default_unit || '',
        })) || [],
      })),
      payout_methods: payoutMethods.map((pm: any) => ({
        id: pm.id,
        type: pm.type,
        provider_name: pm.provider_name,
        account_number: pm.account_number,
        account_name: pm.account_name,
      })),
    }, "Profil provider berhasil diambil");
  } catch (err: any) {
    console.error("[getProfile]", err);
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
    console.error("[toggleAvailability]", err);
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
    const profilePhotoFile = files?.['profile_photo']?.[0];
    const profilePhoto = profilePhotoFile
      ? await uploadToStorage(profilePhotoFile.buffer, 'provider/profile-photo', profilePhotoFile.originalname)
      : undefined;

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
    console.error("[completeOnboarding]", err);
    return errorResponse(res, err.message);
  }
};

const updateProfile = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return errorResponse(res, "Anda harus login terlebih dahulu", 401);
    }

    const profile = await prisma.provider_profiles.findUnique({
      where: { user_id: userId },
      select: { id: true },
    });

    if (!profile) {
      return errorResponse(res, "Profil provider tidak ditemukan", 404);
    }

    const files = req.files as { [fieldname: string]: Express.Multer.File[] } | undefined;

    const uploadFile = async (file: any, folder: string): Promise<string | undefined> => {
      if (!file) return undefined;
      return uploadToStorage(file.buffer, folder, file.originalname);
    };

    const uploadMultiple = async (files: any[], folder: string): Promise<string[]> => {
      if (!files?.length) return [];
      return Promise.all(files.map(f => uploadToStorage(f.buffer, folder, f.originalname)));
    };

    const profilePhoto = await uploadFile(files?.['profile_photo']?.[0], 'provider/profile-photo');
    const ktpPhoto = await uploadFile(files?.['ktp_photo']?.[0], 'provider/ktp');
    const selfiePhoto = await uploadFile(files?.['selfie_photo']?.[0], 'provider/selfie');
    const uploadedDocuments = await uploadMultiple(files?.['documents'] || [], 'provider/documents');

    const existingPortfolios: string[] = req.body.existing_portfolios
      ? (typeof req.body.existing_portfolios === 'string'
          ? JSON.parse(req.body.existing_portfolios)
          : req.body.existing_portfolios)
      : [];
    const uploadedPortfolios = await uploadMultiple(files?.['portfolios'] || [], 'provider/portfolios');
    const portfolios = [...existingPortfolios, ...uploadedPortfolios];

    let birthDate: string | undefined;
    if (req.body.birth_date) {
      birthDate = req.body.birth_date;
    }

    await new ProfileService().updateProfile(userId, {
      full_name: req.body.full_name,
      nickname: req.body.nickname,
      gender: req.body.gender,
      birth_date: birthDate,
      phone: req.body.phone,
      address: req.body.address,
      domicile: req.body.domicile,
      profile_photo: profilePhoto,
      portfolios,
      ktp_photo: ktpPhoto,
      selfie_photo: selfiePhoto,
    });

    const deleteDocIds: string[] = req.body.delete_documents
      ? (typeof req.body.delete_documents === 'string'
          ? JSON.parse(req.body.delete_documents)
          : req.body.delete_documents)
      : [];
    if (deleteDocIds.length > 0) {
      await new ProfileService().deleteProviderDocuments(userId, deleteDocIds);
    }

    if (uploadedDocuments.length > 0) {
      const description = req.body.document_description || 'Dokumen pendukung';
      await prisma.provider_documents.createMany({
        data: uploadedDocuments.map((path) => ({
          provider_id: profile.id,
          type: 'supporting',
          file_url: path,
          description,
        })),
      });
    }

    return successResponse(res, null, "Profil berhasil diperbarui");
  } catch (err: any) {
    console.error("[updateProfile]", err);
    return errorResponse(res, err.message);
  }
};

const toggleTaskAvailability = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) {
      return errorResponse(res, "Anda harus login terlebih dahulu", 401);
    }

    const profile = await prisma.provider_profiles.findUnique({
      where: { user_id: userId },
      select: { task_available: true },
    });

    if (!profile) {
      return errorResponse(res, "Profil provider tidak ditemukan", 404);
    }

    const newStatus = !profile.task_available;

    await prisma.provider_profiles.update({
      where: { user_id: userId },
      data: { task_available: newStatus },
    });

    return successResponse(res, { task_available: newStatus }, newStatus ? "Siap menerima task" : "Sedang tidak menerima task");
  } catch (err: any) {
    console.error("[toggleTaskAvailability]", err);
    return errorResponse(res, err.message);
  }
};

export { getProfile, toggleAvailability, toggleTaskAvailability, completeOnboarding, updateProfile };
