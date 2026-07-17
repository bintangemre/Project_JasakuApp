import { OrdersService } from "./orders.service";
import { AdminService } from "../admin/admin.service";
import { successResponse, errorResponse } from "../../utils/response";
const createOrder = async (req, res) => {
    try {
        const { providerId, serviceId, pricingTypeId, quantity, description, workDate, address, lat, lng, attachments } = req.body;
        const customerId = req.user.userId;
        const ordersService = new OrdersService();
        const { order, warning } = await ordersService.createOrder({
            customerId,
            providerId,
            serviceId,
            pricingTypeId,
            quantity,
            description,
            workDate,
            address,
            lat,
            lng,
            attachments: attachments || [],
        });
        return successResponse(res, { order, warning: warning || null }, 'Order berhasil dibuat', 201);
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const getOrderDetails = async (req, res) => {
    try {
        const { orderId } = req.params;
        const ordersService = new OrdersService();
        const result = await ordersService.getOrderDetails(orderId);
        if (!result) {
            return errorResponse(res, 'Order tidak ditemukan', 404);
        }
        return successResponse(res, result, 'Detail order berhasil diambil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const getOrderExtensions = async (req, res) => {
    try {
        const { orderId } = req.params;
        const ordersService = new OrdersService();
        const result = await ordersService.getOrderExtensions(orderId);
        return successResponse(res, result, 'Ekstensi order berhasil diambil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const getOrderTracking = async (req, res) => {
    try {
        const { orderId } = req.params;
        const ordersService = new OrdersService();
        const result = await ordersService.getOrderTracking(orderId);
        if (!result) {
            return errorResponse(res, 'Order tidak ditemukan', 404);
        }
        return successResponse(res, result, 'Data tracking berhasil diambil');
    }
    catch (err) {
        console.error('[TRACKING ERROR]', { orderId: req.params.orderId, message: err.message, stack: err.stack });
        return errorResponse(res, err.message);
    }
};
const getCustomerOrders = async (req, res) => {
    try {
        const customerId = req.user.userId;
        const statusFilter = req.query.status;
        const ordersService = new OrdersService();
        const result = await ordersService.getCustomerOrders(customerId, statusFilter);
        return successResponse(res, result, 'Daftar order customer berhasil diambil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const getProviderOrders = async (req, res) => {
    try {
        const providerId = req.user.userId;
        const statusFilter = req.query.status;
        const scope = req.query.scope;
        const ordersService = new OrdersService();
        const result = await ordersService.getProviderOrders(providerId, statusFilter, scope);
        return successResponse(res, result, 'Daftar order provider berhasil diambil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const getProviderRequests = async (req, res) => {
    try {
        const providerId = req.user.userId;
        const ordersService = new OrdersService();
        const result = await ordersService.getProviderRequests(providerId);
        return successResponse(res, result, 'Daftar permintaan berhasil diambil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const receiveOrderStatus = async (req, res) => {
    try {
        const { orderId } = req.params;
        const { status } = req.body;
        const providerId = req.user.userId;
        const ordersService = new OrdersService();
        await ordersService.receiveOrderStatus(providerId, orderId, status);
        return successResponse(res, null, `Order berhasil ${status}`);
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const cancelOrder = async (req, res) => {
    try {
        const { orderId } = req.params;
        const customerId = req.user.userId;
        const ordersService = new OrdersService();
        const result = await ordersService.cancelOrder(customerId, orderId);
        return successResponse(res, result, 'Order berhasil dibatalkan');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const getTodayOrders = async (req, res) => {
    try {
        const providerId = req.user.userId;
        const ordersService = new OrdersService();
        const result = await ordersService.getTodayOrders(providerId);
        return successResponse(res, result, 'Jadwal hari ini berhasil diambil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const getProviderSchedule = async (req, res) => {
    try {
        const providerId = req.user.userId;
        const { startDate, endDate } = req.query;
        const ordersService = new OrdersService();
        const result = await ordersService.getProviderSchedule(providerId, startDate, endDate);
        return successResponse(res, result, 'Jadwal berhasil diambil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const getPublicProviderStatus = async (req, res) => {
    try {
        const { providerId } = req.params;
        const ordersService = new OrdersService();
        const result = await ordersService.getPublicProviderStatus(providerId);
        return successResponse(res, result, 'Status mitra berhasil diambil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const getPublicProviderSchedule = async (req, res) => {
    try {
        const { providerId } = req.params;
        const { startDate, endDate } = req.query;
        const ordersService = new OrdersService();
        const result = await ordersService.getPublicProviderSchedule(providerId, startDate, endDate);
        return successResponse(res, result, 'Jadwal mitra berhasil diambil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const confirmPaymentByAdmin = async (req, res) => {
    try {
        const { orderId } = req.params;
        const ordersService = new OrdersService();
        const result = await ordersService.confirmPaymentByAdmin(orderId);
        return successResponse(res, result, 'Pembayaran berhasil dikonfirmasi');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const requestExtension = async (req, res) => {
    try {
        const { orderId } = req.params;
        const { additionalDays } = req.body;
        const userId = req.user.userId;
        const ordersService = new OrdersService();
        const result = await ordersService.requestExtension(userId, orderId, additionalDays);
        return successResponse(res, result, 'Request ekstensi diajukan');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const approveExtension = async (req, res) => {
    try {
        const { extensionId } = req.params;
        const { status } = req.body;
        const ordersService = new OrdersService();
        const result = await ordersService.approveExtension(extensionId, status);
        return successResponse(res, result, `Ekstensi ${status === 'approved' ? 'disetujui' : 'ditolak'}`);
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const respondToExtension = async (req, res) => {
    try {
        const { extensionId } = req.params;
        const { action, note } = req.body;
        const userId = req.user.userId;
        const ordersService = new OrdersService();
        const result = await ordersService.respondToExtension(extensionId, userId, action, note);
        return successResponse(res, result, action === 'approved' ? 'Ekstensi disetujui, lanjut pembayaran' : 'Ekstensi ditolak');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const activateExtension = async (req, res) => {
    try {
        const { extensionId } = req.params;
        const ordersService = new OrdersService();
        const result = await ordersService.activateExtension(extensionId);
        return successResponse(res, result, 'Ekstensi berhasil diaktifkan');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const getPaymentAccounts = async (req, res) => {
    try {
        const result = await new AdminService().getPaymentAccounts();
        return successResponse(res, result, 'Akun pembayaran berhasil diambil');
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
export { createOrder, getOrderDetails, getOrderExtensions, getCustomerOrders, getProviderOrders, receiveOrderStatus, cancelOrder, getTodayOrders, getProviderSchedule, getProviderRequests, getOrderTracking, confirmPaymentByAdmin, requestExtension, approveExtension, respondToExtension, activateExtension, getPaymentAccounts, getPublicProviderStatus, getPublicProviderSchedule };
