import { PaymentsService } from "./payments.service";
import { successResponse, errorResponse } from "../../utils/response";
import { NotificationService } from "../notifications/notifications.service";
import { prisma } from "../../config/prisma";
const getPaymentMethods = async (req, res) => {
    try {
        const result = await new PaymentsService().getPaymentMethods();
        return successResponse(res, result, "Metode pembayaran berhasil diambil");
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const createPayment = async (req, res) => {
    try {
        const { orderId, method, amount } = req.body;
        if (!orderId || !method || !amount) {
            return errorResponse(res, "orderId, method, dan amount wajib diisi", 400);
        }
        const result = await new PaymentsService().createPayment(orderId, method, amount);
        return successResponse(res, result, "Pembayaran berhasil dibuat", 201);
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const getPaymentByOrder = async (req, res) => {
    try {
        const orderId = String(req.params.orderId);
        const result = await new PaymentsService().getPaymentByOrder(orderId);
        if (!result)
            return errorResponse(res, "Pembayaran tidak ditemukan", 404);
        return successResponse(res, result, "Detail pembayaran berhasil diambil");
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const updatePaymentStatus = async (req, res) => {
    try {
        const paymentId = String(req.params.paymentId);
        const { status } = req.body;
        if (!['paid', 'failed', 'pending'].includes(status)) {
            return errorResponse(res, "Status harus 'paid', 'failed', atau 'pending'", 400);
        }
        const payment = await new PaymentsService().updatePaymentStatus(paymentId, status);
        if (!payment)
            return errorResponse(res, "Pembayaran tidak ditemukan", 404);
        // Notifikasi
        const order = await prisma.orders.findUnique({ where: { id: payment.order_id } });
        if (order) {
            if (status === 'paid') {
                await NotificationService.sendToUser(order.customer_id, "Pembayaran Berhasil", "Pembayaran Anda telah dikonfirmasi. Terima kasih!", { orderId: order.id, type: "PAYMENT_SUCCESS" });
                await NotificationService.sendToUser(order.provider_id, "Pembayaran Diterima", "Pembayaran untuk pesanan telah diterima.", { orderId: order.id, type: "PAYMENT_RECEIVED" });
            }
            else if (status === 'failed') {
                await NotificationService.sendToUser(order.customer_id, "Pembayaran Gagal", "Pembayaran Anda gagal. Silakan coba lagi.", { orderId: order.id, type: "PAYMENT_FAILED" });
            }
        }
        return successResponse(res, payment, `Status pembayaran berhasil diubah ke ${status}`);
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
export { getPaymentMethods, createPayment, getPaymentByOrder, updatePaymentStatus };
