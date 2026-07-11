import { CustomTasksService } from './custom-tasks.service';
import { successResponse, errorResponse } from '../../utils/response';
const service = new CustomTasksService();
export const createTask = async (req, res) => {
    try {
        const userId = req.user?.userId;
        if (!userId)
            return errorResponse(res, 'Anda harus login', 401);
        const result = await service.createTask(userId, req.body);
        return successResponse(res, result, 'Task berhasil dibuat', 201);
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
export const getAvailableTasks = async (req, res) => {
    try {
        const { lat, lng, radius } = req.query;
        const result = await service.getAvailableTasks(lat ? Number(lat) : undefined, lng ? Number(lng) : undefined, radius ? Number(radius) : undefined);
        return successResponse(res, result, 'Daftar task tersedia');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
export const getMyTasks = async (req, res) => {
    try {
        const userId = req.user?.userId;
        if (!userId)
            return errorResponse(res, 'Anda harus login', 401);
        const result = await service.getMyTasks(userId);
        return successResponse(res, result, 'Daftar task Anda');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
export const getMyAcceptedTasks = async (req, res) => {
    try {
        const userId = req.user?.userId;
        if (!userId)
            return errorResponse(res, 'Anda harus login', 401);
        const result = await service.getMyAcceptedTasks(userId);
        return successResponse(res, result, 'Daftar task yang diterima');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
export const getTaskDetail = async (req, res) => {
    try {
        const taskId = String(req.params.taskId);
        const result = await service.getTaskDetail(taskId);
        if (!result)
            return errorResponse(res, 'Task tidak ditemukan', 404);
        return successResponse(res, result, 'Detail task');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
export const acceptTask = async (req, res) => {
    try {
        const userId = req.user?.userId;
        if (!userId)
            return errorResponse(res, 'Anda harus login', 401);
        const taskId = String(req.params.taskId);
        const result = await service.acceptTask(userId, taskId);
        return successResponse(res, result, 'Task diterima!');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
export const completeTask = async (req, res) => {
    try {
        const userId = req.user?.userId;
        if (!userId)
            return errorResponse(res, 'Anda harus login', 401);
        const taskId = String(req.params.taskId);
        const result = await service.completeTask(userId, taskId);
        return successResponse(res, result, 'Task selesai');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
export const republishTask = async (req, res) => {
    try {
        const userId = req.user?.userId;
        if (!userId)
            return errorResponse(res, 'Anda harus login', 401);
        const taskId = String(req.params.taskId);
        const result = await service.republishTask(userId, taskId);
        return successResponse(res, result, 'Task berhasil dipublikasi ulang');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
export const getPaymentDetail = async (req, res) => {
    try {
        const userId = req.user?.userId;
        if (!userId)
            return errorResponse(res, 'Anda harus login', 401);
        const taskId = String(req.params.taskId);
        const result = await service.getPaymentDetail(taskId, userId);
        return successResponse(res, result, 'Detail pembayaran');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
export const uploadPaymentProof = async (req, res) => {
    try {
        const userId = req.user?.userId;
        if (!userId)
            return errorResponse(res, 'Anda harus login', 401);
        const taskId = String(req.params.taskId);
        const file = req.file;
        if (!file)
            return errorResponse(res, 'Upload bukti pembayaran terlebih dahulu', 400);
        const fileUrl = `/uploads/payment-proofs/${file.filename}`;
        const result = await service.uploadPaymentProof(taskId, userId, fileUrl);
        return successResponse(res, result, 'Bukti pembayaran berhasil diupload');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
export const cancelTask = async (req, res) => {
    try {
        const userId = req.user?.userId;
        if (!userId)
            return errorResponse(res, 'Anda harus login', 401);
        const taskId = String(req.params.taskId);
        const result = await service.cancelTask(userId, taskId);
        return successResponse(res, result, 'Task dibatalkan');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
// Admin endpoints
export const getPendingPaymentTasks = async (req, res) => {
    try {
        const result = await service.getPendingPaymentTasks();
        return successResponse(res, result, 'Daftar task pending payment');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
export const getPendingPayoutTasks = async (req, res) => {
    try {
        const result = await service.getPendingPayoutTasks();
        return successResponse(res, result, 'Daftar task pending payout');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
export const confirmTaskPayment = async (req, res) => {
    try {
        const tpId = String(req.params.tpId);
        const result = await service.confirmTaskPayment(tpId);
        return successResponse(res, result, 'Pembayaran dikonfirmasi');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
export const confirmTaskPayout = async (req, res) => {
    try {
        const tpId = String(req.params.tpId);
        const result = await service.confirmTaskPayout(tpId);
        return successResponse(res, result, 'Pembayaran ke provider dikonfirmasi');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
