import { Response } from "express";
import { ProviderPayoutService } from "./payout.service";
import { AuthRequest } from "../../../middleware/auth.middleware";
import { prisma } from "../../../config/prisma";
import { successResponse, errorResponse } from "../../../utils/response";

const getPayoutMethods = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) return errorResponse(res, "Anda harus login terlebih dahulu", 401);

    const provider = await prisma.users.findUnique({
      where: { id: userId },
      select: { provider_profiles: { select: { id: true } } },
    });
    const profileId = provider?.provider_profiles?.id;
    if (!profileId) return errorResponse(res, "Profil provider tidak ditemukan", 404);

    const result = await new ProviderPayoutService().getPayoutMethods(profileId);
    return successResponse(res, result, "Metode payout berhasil diambil");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const createPayoutMethod = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) return errorResponse(res, "Anda harus login terlebih dahulu", 401);

    const provider = await prisma.users.findUnique({
      where: { id: userId },
      select: { provider_profiles: { select: { id: true } } },
    });
    const profileId = provider?.provider_profiles?.id;
    if (!profileId) return errorResponse(res, "Profil provider tidak ditemukan", 404);

    const { type, provider_name, account_number, account_name } = req.body;
    if (!type || !provider_name || !account_number || !account_name) {
      return errorResponse(res, "type, provider_name, account_number, account_name wajib diisi", 400);
    }
    if (!['bank', 'ewallet'].includes(type)) {
      return errorResponse(res, "type harus 'bank' atau 'ewallet'", 400);
    }

    const result = await new ProviderPayoutService().createPayoutMethod(profileId, {
      type, provider_name, account_number, account_name
    });
    return successResponse(res, result, "Metode payout berhasil ditambahkan", 201);
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const updatePayoutMethod = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) return errorResponse(res, "Anda harus login terlebih dahulu", 401);

    const provider = await prisma.users.findUnique({
      where: { id: userId },
      select: { provider_profiles: { select: { id: true } } },
    });
    const profileId = provider?.provider_profiles?.id;
    if (!profileId) return errorResponse(res, "Profil provider tidak ditemukan", 404);

    const id = String(req.params.id);
    const { type, provider_name, account_number, account_name } = req.body;
    const result = await new ProviderPayoutService().updatePayoutMethod(id, profileId, {
      type, provider_name, account_number, account_name
    });
    return successResponse(res, result, "Metode payout berhasil diupdate");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const deletePayoutMethod = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) return errorResponse(res, "Anda harus login terlebih dahulu", 401);

    const provider = await prisma.users.findUnique({
      where: { id: userId },
      select: { provider_profiles: { select: { id: true } } },
    });
    const profileId = provider?.provider_profiles?.id;
    if (!profileId) return errorResponse(res, "Profil provider tidak ditemukan", 404);

    const id = String(req.params.id);
    await new ProviderPayoutService().deletePayoutMethod(id, profileId);
    return successResponse(res, null, "Metode payout berhasil dihapus");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export { getPayoutMethods, createPayoutMethod, updatePayoutMethod, deletePayoutMethod };
