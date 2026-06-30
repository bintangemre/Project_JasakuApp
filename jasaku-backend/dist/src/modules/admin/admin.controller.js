import { AdminService } from "./admin.service";
import { successResponse, errorResponse } from "../../utils/response";
const getDashboardMetrics = async (req, res) => {
    try {
        const result = await new AdminService().getDashboardMetrics();
        return successResponse(res, result, "Data dashboard berhasil diambil");
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const getPendingProviders = async (req, res) => {
    try {
        const result = await new AdminService().getPendingProviders();
        return successResponse(res, result, "Daftar provider pending berhasil diambil");
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const verifyProvider = async (req, res) => {
    try {
        const providerId = String(req.params.providerId);
        const { status } = req.body;
        if (!['verified', 'rejected'].includes(status)) {
            return errorResponse(res, "Status harus 'verified' atau 'rejected'", 400);
        }
        const result = await new AdminService().verifyProvider(providerId, status);
        return successResponse(res, result, `Provider berhasil ${status === 'verified' ? 'diverifikasi' : 'ditolak'}`);
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
// Categories
const createCategory = async (req, res) => {
    try {
        const { name, description, iconUrl } = req.body;
        if (!name)
            return errorResponse(res, "Nama kategori wajib diisi", 400);
        const result = await new AdminService().createCategory(name, description, iconUrl);
        return successResponse(res, result, "Kategori berhasil dibuat", 201);
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const updateCategory = async (req, res) => {
    try {
        const id = String(req.params.id);
        const { name, description, iconUrl } = req.body;
        const result = await new AdminService().updateCategory(id, { name, description, icon_url: iconUrl });
        return successResponse(res, result, "Kategori berhasil diupdate");
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const deleteCategory = async (req, res) => {
    try {
        const id = String(req.params.id);
        await new AdminService().deleteCategory(id);
        return successResponse(res, null, "Kategori berhasil dihapus");
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
// Services
const createService = async (req, res) => {
    try {
        const { categoryId, name, description } = req.body;
        if (!categoryId || !name)
            return errorResponse(res, "categoryId dan name wajib diisi", 400);
        const result = await new AdminService().createService(categoryId, name, description);
        return successResponse(res, result, "Layanan berhasil dibuat", 201);
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const updateService = async (req, res) => {
    try {
        const id = String(req.params.id);
        const { name, description } = req.body;
        const result = await new AdminService().updateService(id, { name, description });
        return successResponse(res, result, "Layanan berhasil diupdate");
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const deleteService = async (req, res) => {
    try {
        const id = String(req.params.id);
        await new AdminService().deleteService(id);
        return successResponse(res, null, "Layanan berhasil dihapus");
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
// Users
const getAllProviders = async (req, res) => {
    try {
        const result = await new AdminService().getAllProviders();
        return successResponse(res, result, "Daftar provider berhasil diambil");
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const getAllCustomers = async (req, res) => {
    try {
        const result = await new AdminService().getAllCustomers();
        return successResponse(res, result, "Daftar customer berhasil diambil");
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const banUser = async (req, res) => {
    try {
        const userId = String(req.params.userId);
        await new AdminService().banUser(userId);
        return successResponse(res, null, "User berhasil dibanned");
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const unbanUser = async (req, res) => {
    try {
        const userId = String(req.params.userId);
        await new AdminService().unbanUser(userId);
        return successResponse(res, null, "User berhasil diunbanned");
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
// Pricing Types
const createPricingType = async (req, res) => {
    try {
        const { categoryId, name, description, defaultUnit } = req.body;
        if (!categoryId || !name)
            return errorResponse(res, "categoryId dan name wajib diisi", 400);
        const result = await new AdminService().createPricingType(categoryId, name, description, defaultUnit);
        return successResponse(res, result, "Tipe harga berhasil dibuat", 201);
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const deletePricingType = async (req, res) => {
    try {
        const id = String(req.params.id);
        await new AdminService().deletePricingType(id);
        return successResponse(res, null, "Tipe harga berhasil dihapus");
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
// Payment Accounts (Rekber Admin)
const getPaymentAccounts = async (req, res) => {
    try {
        const result = await new AdminService().getPaymentAccounts();
        return successResponse(res, result, "Daftar rekber berhasil diambil");
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const createPaymentAccount = async (req, res) => {
    try {
        const { type, account_name, account_number, provider_name, qris_image_url } = req.body;
        if (!type || !account_name || !account_number || !provider_name) {
            return errorResponse(res, "type, account_name, account_number, provider_name wajib diisi", 400);
        }
        if (!['bank', 'ewallet', 'qris'].includes(type)) {
            return errorResponse(res, "type harus 'bank', 'ewallet', atau 'qris'", 400);
        }
        const result = await new AdminService().createPaymentAccount({ type, account_name, account_number, provider_name, qris_image_url });
        return successResponse(res, result, "Rekber berhasil ditambahkan", 201);
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const updatePaymentAccount = async (req, res) => {
    try {
        const id = String(req.params.id);
        const { type, account_name, account_number, provider_name, qris_image_url, is_active } = req.body;
        const result = await new AdminService().updatePaymentAccount(id, { type, account_name, account_number, provider_name, qris_image_url, is_active });
        return successResponse(res, result, "Rekber berhasil diupdate");
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const deletePaymentAccount = async (req, res) => {
    try {
        const id = String(req.params.id);
        await new AdminService().deletePaymentAccount(id);
        return successResponse(res, null, "Rekber berhasil dihapus");
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
const uploadQrisImage = async (req, res) => {
    try {
        const id = String(req.params.id);
        if (!req.file) {
            return errorResponse(res, "File gambar QRIS wajib diupload", 400);
        }
        const qrisImageUrl = `/uploads/${req.file.filename}`;
        await new AdminService().updatePaymentAccount(id, { qris_image_url: qrisImageUrl });
        return successResponse(res, { qris_image_url: qrisImageUrl }, "QRIS berhasil diupload");
    }
    catch (err) {
        return errorResponse(res, err.message);
    }
};
export { getDashboardMetrics, getPendingProviders, verifyProvider, createCategory, updateCategory, deleteCategory, createService, updateService, deleteService, getAllProviders, getAllCustomers, banUser, unbanUser, createPricingType, deletePricingType, getPaymentAccounts, createPaymentAccount, updatePaymentAccount, deletePaymentAccount, uploadQrisImage };
