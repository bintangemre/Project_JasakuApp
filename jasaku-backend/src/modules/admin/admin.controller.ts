import { Response } from "express";
import { AdminService } from "./admin.service";
import { AuthRequest } from "../../middleware/auth.middleware";
import { successResponse, errorResponse } from "../../utils/response";
import { prisma } from "../../config/prisma";
import { NotificationService } from "../notifications/notifications.service";
import { uploadToStorage } from "../../services/storage.service";

const getDashboardMetrics = async (req: AuthRequest, res: Response) => {
  try {
    const result = await new AdminService().getDashboardMetrics();
    return successResponse(res, result, "Data dashboard berhasil diambil");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const getPendingProviders = async (req: AuthRequest, res: Response) => {
  try {
    const result = await new AdminService().getPendingProviders();
    return successResponse(res, result, "Daftar provider pending berhasil diambil");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const verifyProvider = async (req: AuthRequest, res: Response) => {
  try {
    const providerId = String(req.params.providerId);
    const status = req.body?.status || 'verified';
    const notes = req.body?.notes;
    const checklist = req.body?.checklist;
    if (!['verified', 'rejected'].includes(status)) {
      return errorResponse(res, "Status harus 'verified' atau 'rejected'", 400);
    }
    const result = await new AdminService().verifyProvider(providerId, status, notes, checklist);
    return successResponse(res, result, `Provider berhasil ${status === 'verified' ? 'diverifikasi' : 'ditolak'}`);
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const unverifyProvider = async (req: AuthRequest, res: Response) => {
  try {
    const providerId = String(req.params.providerId);
    await new AdminService().unverifyProvider(providerId);
    return successResponse(res, null, "Provider berhasil dikembalikan ke pending");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

// Categories
const getCategories = async (req: AuthRequest, res: Response) => {
  try {
    const result = await new AdminService().getAllCategories();
    return successResponse(res, result, "Daftar kategori berhasil diambil");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const getServicesByCategory = async (req: AuthRequest, res: Response) => {
  try {
    const categoryId = String(req.params.id);
    const result = await new AdminService().getServicesByCategory(categoryId);
    return successResponse(res, result, "Daftar layanan berhasil diambil");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const getPricingTypesByCategory = async (req: AuthRequest, res: Response) => {
  try {
    const categoryId = String(req.params.id);
    const result = await new AdminService().getPricingTypesByCategory(categoryId);
    return successResponse(res, result, "Daftar tipe harga berhasil diambil");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const createCategory = async (req: AuthRequest, res: Response) => {
  try {
    const { name, description, iconUrl } = req.body;
    if (!name) return errorResponse(res, "Nama kategori wajib diisi", 400);
    const result = await new AdminService().createCategory(name, description, iconUrl);
    return successResponse(res, result, "Kategori berhasil dibuat", 201);
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const updateCategory = async (req: AuthRequest, res: Response) => {
  try {
    const id = String(req.params.id);
    const { name, description, iconUrl } = req.body;
    const result = await new AdminService().updateCategory(id, { name, description, icon_url: iconUrl });
    return successResponse(res, result, "Kategori berhasil diupdate");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const deleteCategory = async (req: AuthRequest, res: Response) => {
  try {
    const id = String(req.params.id);
    await new AdminService().deleteCategory(id);
    return successResponse(res, null, "Kategori berhasil dihapus");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

// Services
const createService = async (req: AuthRequest, res: Response) => {
  try {
    const { categoryId, name, description } = req.body;
    if (!categoryId || !name) return errorResponse(res, "categoryId dan name wajib diisi", 400);
    const result = await new AdminService().createService(categoryId, name, description);
    return successResponse(res, result, "Layanan berhasil dibuat", 201);
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const updateService = async (req: AuthRequest, res: Response) => {
  try {
    const id = String(req.params.id);
    const { name, description } = req.body;
    const result = await new AdminService().updateService(id, { name, description });
    return successResponse(res, result, "Layanan berhasil diupdate");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const deleteService = async (req: AuthRequest, res: Response) => {
  try {
    const id = String(req.params.id);
    await new AdminService().deleteService(id);
    return successResponse(res, null, "Layanan berhasil dihapus");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const getProviderDetail = async (req: AuthRequest, res: Response) => {
  try {
    const providerId = String(req.params.providerId);
    const result = await new AdminService().getProviderDetail(providerId);
    return successResponse(res, result, "Detail provider berhasil diambil");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

// Users
const getAllProviders = async (req: AuthRequest, res: Response) => {
  try {
    const pending = req.query.pending === 'true';
    const result = pending ? await new AdminService().getPendingProviders() : await new AdminService().getAllProviders();
    return successResponse(res, result, "Daftar provider berhasil diambil");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const getAllCustomers = async (req: AuthRequest, res: Response) => {
  try {
    const result = await new AdminService().getAllCustomers();
    return successResponse(res, result, "Daftar customer berhasil diambil");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const banUser = async (req: AuthRequest, res: Response) => {
  try {
    const userId = String(req.params.userId);
    await new AdminService().banUser(userId);
    return successResponse(res, null, "User berhasil dibanned");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const unbanUser = async (req: AuthRequest, res: Response) => {
  try {
    const userId = String(req.params.userId);
    await new AdminService().unbanUser(userId);
    return successResponse(res, null, "User berhasil diunbanned");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

// Pricing Types
const createPricingType = async (req: AuthRequest, res: Response) => {
  try {
    const { categoryId, name, description, defaultUnit } = req.body;
    if (!categoryId || !name) return errorResponse(res, "categoryId dan name wajib diisi", 400);
    const result = await new AdminService().createPricingType(categoryId, name, description, defaultUnit);
    return successResponse(res, result, "Tipe harga berhasil dibuat", 201);
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const deletePricingType = async (req: AuthRequest, res: Response) => {
  try {
    const id = String(req.params.id);
    await new AdminService().deletePricingType(id);
    return successResponse(res, null, "Tipe harga berhasil dihapus");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

// Payment Accounts (Rekber Admin)
const getPaymentAccounts = async (req: AuthRequest, res: Response) => {
  try {
    const result = await new AdminService().getPaymentAccounts();
    return successResponse(res, result, "Daftar rekber berhasil diambil");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const createPaymentAccount = async (req: AuthRequest, res: Response) => {
  try {
    const { type, account_name, account_number, provider_name, qris_image_url } = req.body;
    if (!type || !provider_name) {
      return errorResponse(res, "type dan provider_name wajib diisi", 400);
    }
    if (type !== 'qris' && (!account_name || !account_number)) {
      return errorResponse(res, "account_name dan account_number wajib diisi untuk bank/e-wallet", 400);
    }
    if (!['bank_transfer', 'e_wallet', 'qris'].includes(type)) {
      return errorResponse(res, "type harus 'bank_transfer', 'e_wallet', atau 'qris'", 400);
    }
    const result = await new AdminService().createPaymentAccount({ type, account_name, account_number, provider_name, qris_image_url });
    return successResponse(res, result, "Rekber berhasil ditambahkan", 201);
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const updatePaymentAccount = async (req: AuthRequest, res: Response) => {
  try {
    const id = String(req.params.id);
    const { type, account_name, account_number, provider_name, qris_image_url, is_active } = req.body;
    const result = await new AdminService().updatePaymentAccount(id, { type, account_name, account_number, provider_name, qris_image_url, is_active });
    return successResponse(res, result, "Rekber berhasil diupdate");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const deletePaymentAccount = async (req: AuthRequest, res: Response) => {
  try {
    const id = String(req.params.id);
    await new AdminService().deletePaymentAccount(id);
    return successResponse(res, null, "Rekber berhasil dihapus");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const uploadQrisImage = async (req: AuthRequest, res: Response) => {
  try {
    const id = String(req.params.id);
    if (!req.file) {
      return errorResponse(res, "File gambar QRIS wajib diupload", 400);
    }
    const qrisImageUrl = await uploadToStorage(req.file.buffer, 'admin/qris', req.file.originalname);
    await new AdminService().updatePaymentAccount(id, { qris_image_url: qrisImageUrl });
    return successResponse(res, { qris_image_url: qrisImageUrl }, "QRIS berhasil diupload");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

// Payment Confirmation (Rekber)
const getPendingPaymentOrders = async (req: AuthRequest, res: Response) => {
  try {
    const result = await new AdminService().getPendingPaymentOrders();
    return successResponse(res, result, "Daftar order pending payment berhasil diambil");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const getAllOrders = async (req: AuthRequest, res: Response) => {
  try {
    const result = await new AdminService().getAllOrders();
    return successResponse(res, result, "Daftar semua order berhasil diambil");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

// Extensions
const getPendingExtensions = async (req: AuthRequest, res: Response) => {
  try {
    const result = await new AdminService().getPendingExtensions();
    return successResponse(res, result, "Daftar request ekstensi berhasil diambil");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const getAllExtensions = async (req: AuthRequest, res: Response) => {
  try {
    const result = await new AdminService().getAllExtensions();
    return successResponse(res, result, "Daftar semua ekstensi berhasil diambil");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const getPendingPaymentExtensions = async (req: AuthRequest, res: Response) => {
  try {
    const result = await new AdminService().getPendingPaymentExtensions();
    return successResponse(res, result, "Daftar ekstensi menunggu pembayaran berhasil diambil");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

// Reports
const getOpenReports = async (req: AuthRequest, res: Response) => {
  try {
    const result = await new AdminService().getOpenReports();
    return successResponse(res, result, "Daftar laporan berhasil diambil");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const respondToReport = async (req: AuthRequest, res: Response) => {
  try {
    const reportId = String(req.params.reportId);
    const { response, status } = req.body;
    if (!response || !status) {
      return errorResponse(res, 'Response dan status wajib diisi', 400);
    }
    const result = await new AdminService().respondToReport(reportId, response, status);
    return successResponse(res, result, 'Laporan berhasil ditindaklanjuti');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const getNotificationCounts = async (req: AuthRequest, res: Response) => {
  try {
    const result = await new AdminService().getNotificationCounts();
    return successResponse(res, result, "Notification counts berhasil diambil");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

// Custom Tasks
import { CustomTasksService } from '../custom-tasks/custom-tasks.service';
const customTasksService = new CustomTasksService();

const getPendingTaskPayments = async (req: AuthRequest, res: Response) => {
  try {
    const result = await customTasksService.getPendingPaymentTasks();
    return successResponse(res, result, "Daftar task pending payment");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const getPendingTaskPaymentsByTask = async (req: AuthRequest, res: Response) => {
  try {
    const result = await customTasksService.getPendingPaymentTasksByTask();
    return successResponse(res, result, "Daftar task pending payment (grup per task)");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const confirmTaskPaymentByTask = async (req: AuthRequest, res: Response) => {
  try {
    const taskId = String(req.params.taskId);
    const result = await customTasksService.adminConfirmTaskPayment(taskId);
    return successResponse(res, result, "Pembayaran seluruh task dikonfirmasi");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};
const getPendingTaskPayouts = async (req: AuthRequest, res: Response) => {
  try {
    const result = await customTasksService.getPendingPayoutTasks();
    return successResponse(res, result, "Daftar task pending payout");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const confirmTaskPayment = async (req: AuthRequest, res: Response) => {
  try {
    const tpId = String(req.params.tpId);
    const result = await customTasksService.confirmTaskPayment(tpId);
    return successResponse(res, result, "Pembayaran dikonfirmasi");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const confirmTaskPayout = async (req: AuthRequest, res: Response) => {
  try {
    const tpId = String(req.params.tpId);
    const result = await customTasksService.confirmTaskPayout(tpId);
    return successResponse(res, result, "Pembayaran ke provider dikonfirmasi");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const getCompletedOrdersPendingPayout = async (req: AuthRequest, res: Response) => {
  try {
    const result = await new AdminService().getCompletedOrdersPendingPayout();
    return successResponse(res, result, "Daftar order selesai menunggu pencairan");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

const confirmOrderPayout = async (req: AuthRequest, res: Response) => {
  try {
    const orderId = String(req.params.orderId);
    const result = await new AdminService().confirmOrderPayout(orderId);
    return successResponse(res, result, "Pencairan dana dikonfirmasi");
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export {
  getDashboardMetrics, getPendingProviders, verifyProvider, unverifyProvider, getProviderDetail,
  getCategories, getServicesByCategory, getPricingTypesByCategory,
  createCategory, updateCategory, deleteCategory,
  createService, updateService, deleteService,
  getAllProviders, getAllCustomers, banUser, unbanUser,
  createPricingType, deletePricingType,
  getPaymentAccounts, createPaymentAccount, updatePaymentAccount, deletePaymentAccount,
  uploadQrisImage,
  getPendingPaymentOrders,
  getAllOrders,
  getPendingExtensions,
  getAllExtensions,
  getPendingPaymentExtensions,
  getPendingTaskPayments,
  getPendingTaskPaymentsByTask,
  getPendingTaskPayouts,
  confirmTaskPayment,
  confirmTaskPaymentByTask,
  confirmTaskPayout,
  getOpenReports,
  respondToReport,
  getNotificationCounts,
  getCompletedOrdersPendingPayout,
  confirmOrderPayout
};
