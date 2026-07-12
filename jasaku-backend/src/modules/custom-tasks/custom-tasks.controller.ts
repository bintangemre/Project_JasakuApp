import { Response } from 'express';
import { CustomTasksService } from './custom-tasks.service';
import { AuthRequest } from '../../middleware/auth.middleware';
import { successResponse, errorResponse } from '../../utils/response';
import { uploadToStorage } from '../../services/storage.service';

const service = new CustomTasksService();

export const createTask = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) return errorResponse(res, 'Anda harus login', 401);

    const result = await service.createTask(userId, req.body);
    return successResponse(res, result, 'Task berhasil dibuat', 201);
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export const getAvailableTasks = async (req: AuthRequest, res: Response) => {
  try {
    const { lat, lng, radius } = req.query;
    const result = await service.getAvailableTasks(
      lat ? Number(lat) : undefined,
      lng ? Number(lng) : undefined,
      radius ? Number(radius) : undefined,
    );
    return successResponse(res, result, 'Daftar task tersedia');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export const getMyTasks = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) return errorResponse(res, 'Anda harus login', 401);

    const result = await service.getMyTasks(userId);
    return successResponse(res, result, 'Daftar task Anda');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export const getMyAcceptedTasks = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) return errorResponse(res, 'Anda harus login', 401);

    const result = await service.getMyAcceptedTasks(userId);
    return successResponse(res, result, 'Daftar task yang diterima');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export const getTaskDetail = async (req: AuthRequest, res: Response) => {
  try {
    const taskId = String(req.params.taskId);
    const result = await service.getTaskDetail(taskId);
    if (!result) return errorResponse(res, 'Task tidak ditemukan', 404);
    return successResponse(res, result, 'Detail task');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export const acceptTask = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) return errorResponse(res, 'Anda harus login', 401);

    const taskId = String(req.params.taskId);
    const result = await service.acceptTask(userId, taskId);
    return successResponse(res, result, 'Task diterima!');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export const completeTask = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) return errorResponse(res, 'Anda harus login', 401);

    const taskId = String(req.params.taskId);
    const result = await service.completeTask(userId, taskId);
    return successResponse(res, result, 'Task selesai');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export const updateWorkStatus = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) return errorResponse(res, 'Anda harus login', 401);

    const taskId = String(req.params.taskId);
    const { work_status } = req.body;
    if (!work_status) return errorResponse(res, 'work_status wajib diisi', 400);

    const result = await service.updateWorkStatus(userId, taskId, work_status);
    return successResponse(res, result, 'Status kerja diperbarui');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export const getMyActiveTasks = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) return errorResponse(res, 'Anda harus login', 401);

    const result = await service.getMyActiveTasks(userId);
    return successResponse(res, result, 'Daftar task aktif');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export const republishTask = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) return errorResponse(res, 'Anda harus login', 401);

    const taskId = String(req.params.taskId);
    const result = await service.republishTask(userId, taskId);
    return successResponse(res, result, 'Task berhasil dipublikasi ulang');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export const getPaymentDetail = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) return errorResponse(res, 'Anda harus login', 401);

    const taskId = String(req.params.taskId);
    const result = await service.getPaymentDetail(taskId, userId);
    return successResponse(res, result, 'Detail pembayaran');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export const uploadPaymentProof = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) return errorResponse(res, 'Anda harus login', 401);

    const taskId = String(req.params.taskId);
    const file = req.file;
    if (!file) return errorResponse(res, 'Upload bukti pembayaran terlebih dahulu', 400);

    const fileUrl = await uploadToStorage(file.buffer, 'payment-proofs', file.originalname);
    const result = await service.uploadPaymentProof(taskId, userId, fileUrl);
    return successResponse(res, result, 'Bukti pembayaran berhasil diupload');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export const deleteTask = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) return errorResponse(res, 'Anda harus login', 401);

    const taskId = String(req.params.taskId);
    const result = await service.deleteTask(userId, taskId);
    return successResponse(res, result, 'Task berhasil dihapus');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export const getTaskTracking = async (req: AuthRequest, res: Response) => {
  try {
    const taskId = String(req.params.taskId);
    const result = await service.getTaskTracking(taskId);
    if (!result) return errorResponse(res, 'Task tidak ditemukan', 404);
    return successResponse(res, result, 'Data tracking berhasil diambil');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export const cancelTask = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) return errorResponse(res, 'Anda harus login', 401);

    const taskId = String(req.params.taskId);
    const result = await service.cancelTask(userId, taskId);
    return successResponse(res, result, 'Task dibatalkan');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

// Admin endpoints
export const getPendingPaymentTasks = async (req: AuthRequest, res: Response) => {
  try {
    const result = await service.getPendingPaymentTasks();
    return successResponse(res, result, 'Daftar task pending payment');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export const getPendingPayoutTasks = async (req: AuthRequest, res: Response) => {
  try {
    const result = await service.getPendingPayoutTasks();
    return successResponse(res, result, 'Daftar task pending payout');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export const confirmTaskPayment = async (req: AuthRequest, res: Response) => {
  try {
    const tpId = String(req.params.tpId);
    const result = await service.confirmTaskPayment(tpId);
    return successResponse(res, result, 'Pembayaran dikonfirmasi');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export const confirmTaskPayout = async (req: AuthRequest, res: Response) => {
  try {
    const tpId = String(req.params.tpId);
    const result = await service.confirmTaskPayout(tpId);
    return successResponse(res, result, 'Pembayaran ke provider dikonfirmasi');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};
