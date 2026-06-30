import { prisma } from '../../config/prisma';
export class AdminService {
    // Dashboard metrics
    async getDashboardMetrics() {
        const [totalUsers, totalProviders, totalCustomers, totalServices, totalOrders, pendingVerifications, totalCategories] = await Promise.all([
            prisma.users.count(),
            prisma.provider_profiles.count(),
            prisma.profiles_customer.count(),
            prisma.services.count(),
            prisma.orders.count(),
            prisma.provider_profiles.count({ where: { verification_status: 'pending' } }),
            prisma.categories.count(),
        ]);
        return {
            totalUsers,
            totalProviders,
            totalCustomers,
            totalServices,
            totalOrders,
            pendingVerifications,
            totalCategories
        };
    }
    // Provider verification
    async getPendingProviders() {
        return await prisma.provider_profiles.findMany({
            where: { verification_status: 'pending' },
            include: {
                users: { select: { id: true, email: true, phone: true, created_at: true } }
            }
        });
    }
    async verifyProvider(providerId, status, notes) {
        return await prisma.provider_profiles.update({
            where: { user_id: providerId },
            data: {
                is_verified: status === 'verified',
                verification_status: status,
            }
        });
    }
    // CRUD Categories
    async createCategory(name, description, iconUrl) {
        return await prisma.categories.create({
            data: { name, description, icon_url: iconUrl }
        });
    }
    async updateCategory(id, data) {
        return await prisma.categories.update({ where: { id }, data });
    }
    async deleteCategory(id) {
        const servicesCount = await prisma.services.count({ where: { category_id: id } });
        if (servicesCount > 0)
            throw new Error('Kategori memiliki layanan aktif. Hapus layanan terlebih dahulu.');
        return await prisma.categories.delete({ where: { id } });
    }
    // CRUD Services
    async createService(categoryId, name, description) {
        return await prisma.services.create({
            data: { category_id: categoryId, name, description }
        });
    }
    async updateService(id, data) {
        return await prisma.services.update({ where: { id }, data });
    }
    async deleteService(id) {
        return await prisma.services.delete({ where: { id } });
    }
    // Customer management
    async banUser(userId) {
        return await prisma.users.update({
            where: { id: userId },
            data: { status: 'banned' }
        });
    }
    async unbanUser(userId) {
        return await prisma.users.update({
            where: { id: userId },
            data: { status: 'active' }
        });
    }
    async warnProvider(providerId) {
        // Gunakan field notes atau buat catatan di provider_profiles
        return await prisma.provider_profiles.update({
            where: { user_id: providerId },
            data: { /* is_active bisa jadi indikator, atau tambah field warning_count */}
        });
    }
    // List users
    async getAllProviders() {
        return await prisma.provider_profiles.findMany({
            include: { users: { select: { email: true, phone: true, status: true, created_at: true } } }
        });
    }
    async getAllCustomers() {
        return await prisma.profiles_customer.findMany({
            include: { users: { select: { email: true, phone: true, status: true, created_at: true } } }
        });
    }
    // CRUD Pricing Types
    async createPricingType(categoryId, name, description, defaultUnit) {
        return await prisma.pricing_types.create({
            data: { category_id: categoryId, name, description, default_unit: defaultUnit }
        });
    }
    async deletePricingType(id) {
        return await prisma.pricing_types.delete({ where: { id } });
    }
    // Payment Accounts (Rekber Admin)
    async getPaymentAccounts() {
        return await prisma.admin_payment_accounts.findMany({
            orderBy: { created_at: 'asc' }
        });
    }
    async createPaymentAccount(data) {
        return await prisma.admin_payment_accounts.create({ data });
    }
    async updatePaymentAccount(id, data) {
        return await prisma.admin_payment_accounts.update({
            where: { id },
            data
        });
    }
    async deletePaymentAccount(id) {
        return await prisma.admin_payment_accounts.delete({ where: { id } });
    }
}
