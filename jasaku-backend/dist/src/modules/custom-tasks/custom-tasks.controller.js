import { CustomTasksService } from './custom-tasks.service';
import { successResponse, errorResponse } from '../../utils/response';
import { prisma } from '../../config/prisma';
import { NotificationService } from '../notifications/notifications.service';
const customTasksService = new CustomTasksService();
const postTask = async (req, res) => {
    try {
        const customerId = req.user?.userId;
        if (!customerId)
            return errorResponse(res, 'Anda harus login terlebih dahulu', 401);
        const { title, description, budget, address, lat, lng, deadline } = req.body;
        const result = await customTasksService.postTask(customerId, {
            title,
            description,
            budget,
            address,
            lat,
            lng,
            deadline,
        });
        return successResponse(res, result, 'Task berhasil dibuat', 201);
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const getAvailableTasks = async (req, res) => {
    try {
        const { lat, lng, radius } = req.query;
        const result = await customTasksService.getAvailableTasks(lat ? Number(lat) : undefined, lng ? Number(lng) : undefined, radius ? Number(radius) : undefined);
        return successResponse(res, result, 'Daftar task tersedia berhasil diambil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const getMyTasks = async (req, res) => {
    try {
        const customerId = req.user?.userId;
        if (!customerId)
            return errorResponse(res, 'Anda harus login terlebih dahulu', 401);
        const result = await customTasksService.getMyTasks(customerId);
        return successResponse(res, result, 'Daftar task Anda berhasil diambil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const getTaskDetail = async (req, res) => {
    try {
        const taskId = req.params.taskId;
        const result = await customTasksService.getTaskDetail(taskId);
        if (!result)
            return errorResponse(res, 'Task tidak ditemukan', 404);
        return successResponse(res, result, 'Detail task berhasil diambil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const acceptTask = async (req, res) => {
    try {
        const providerId = req.user?.userId;
        if (!providerId)
            return errorResponse(res, 'Anda harus login terlebih dahulu', 401);
        const taskId = req.params.taskId;
        const result = await customTasksService.acceptTask(providerId, taskId);
        return successResponse(res, result, 'Task diterima, silakan lanjutkan pembayaran', 201);
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const confirmTaskByAdmin = async (req, res) => {
    try {
        const taskId = req.params.taskId;
        const { status } = req.body; // 'confirmed' | 'rejected'
        const task = await customTasksService.getTaskDetail(taskId);
        if (!task)
            return errorResponse(res, 'Task tidak ditemukan', 404);
        await prisma.custom_tasks.update({
            where: { id: taskId },
            data: { status }
        });
        try {
            await NotificationService.sendToUser(task.customer_id, status === 'confirmed' ? 'Task Disetujui' : 'Task Ditolak', status === 'confirmed'
                ? `Task "${task.title}" telah disetujui admin. Provider dapat menerima task ini.`
                : `Maaf, task "${task.title}" ditolak oleh admin.`, { taskId, type: status === 'confirmed' ? 'TASK_CONFIRMED' : 'TASK_REJECTED' });
        }
        catch (_) { }
        return successResponse(res, null, status === 'confirmed' ? 'Task disetujui' : 'Task ditolak');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
export { postTask, getAvailableTasks, getMyTasks, getTaskDetail, acceptTask, confirmTaskByAdmin, };
