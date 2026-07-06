import { Response } from 'express';
import { CustomTasksService } from './custom-tasks.service';
import { AuthRequest } from '../../middleware/auth.middleware';
import { successResponse, errorResponse } from '../../utils/response';

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
