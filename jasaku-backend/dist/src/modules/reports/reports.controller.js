import { ReportsService } from './reports.service';
import { successResponse, errorResponse } from '../../utils/response';
const reportsService = new ReportsService();
const createReport = async (req, res) => {
    try {
        const userId = req.user?.userId;
        if (!userId)
            return errorResponse(res, 'Anda harus login terlebih dahulu', 401);
        const { subject, description, orderId, attachments } = req.body;
        if (!subject || !description) {
            return errorResponse(res, 'Subject dan deskripsi wajib diisi', 400);
        }
        const role = req.user?.role || 'customer';
        const reporterRole = role === 'provider' ? 'provider' : 'customer';
        const result = await reportsService.createReport(userId, reporterRole, subject, description, orderId, attachments);
        return successResponse(res, result, 'Laporan berhasil dikirim', 201);
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const getMyReports = async (req, res) => {
    try {
        const userId = req.user?.userId;
        if (!userId)
            return errorResponse(res, 'Anda harus login terlebih dahulu', 401);
        const result = await reportsService.getMyReports(userId);
        return successResponse(res, result, 'Daftar laporan berhasil diambil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
export { createReport, getMyReports };
