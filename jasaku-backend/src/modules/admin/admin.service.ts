import {prisma} from '../../config/prisma';

export class AdminService {
    // Dashboard metrics
    async getDashboardMetrics() {
        const [
            totalUsers,
            totalProviders,
            totalCustomers,
            totalServices,
            totalOrders,
            pendingVerifications,
            totalCategories
        ] = await Promise.all([
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

    async verifyProvider(providerId: string, status: 'verified' | 'rejected', notes?: string) {
        return await prisma.provider_profiles.update({
            where: { id: providerId },
            data: {
                is_verified: status === 'verified',
                verification_status: status,
            }
        });
    }

    async unverifyProvider(providerId: string) {
        return await prisma.provider_profiles.update({
            where: { id: providerId },
            data: { is_verified: false, verification_status: 'pending' }
        });
    }

    // Categories
    async getAllCategories() {
        return await prisma.categories.findMany({ orderBy: { name: 'asc' } });
    }

    async getServicesByCategory(categoryId: string) {
        return await prisma.services.findMany({
            where: { category_id: categoryId },
            orderBy: { name: 'asc' }
        });
    }

    async getPricingTypesByCategory(categoryId: string) {
        return await prisma.pricing_types.findMany({
            where: { category_id: categoryId },
            orderBy: { name: 'asc' }
        });
    }

    async createCategory(name: string, description?: string, iconUrl?: string) {
        return await prisma.categories.create({
            data: { name, description, icon_url: iconUrl }
        });
    }

    async updateCategory(id: string, data: { name?: string; description?: string; icon_url?: string }) {
        return await prisma.categories.update({ where: { id }, data });
    }

    async deleteCategory(id: string) {
        const servicesCount = await prisma.services.count({ where: { category_id: id } });
        if (servicesCount > 0) throw new Error('Kategori memiliki layanan aktif. Hapus layanan terlebih dahulu.');
        return await prisma.categories.delete({ where: { id } });
    }

    // CRUD Services
    async createService(categoryId: string, name: string, description?: string) {
        return await prisma.services.create({
            data: { category_id: categoryId, name, description }
        });
    }

    async updateService(id: string, data: { name?: string; description?: string }) {
        return await prisma.services.update({ where: { id }, data });
    }

    async deleteService(id: string) {
        return await prisma.services.delete({ where: { id } });
    }

    // Customer management
    async banUser(userId: string) {
        return await prisma.users.update({
            where: { id: userId },
            data: { status: 'banned' }
        });
    }

    async unbanUser(userId: string) {
        return await prisma.users.update({
            where: { id: userId },
            data: { status: 'active' }
        });
    }

    async warnProvider(providerId: string) {
        // Gunakan field notes atau buat catatan di provider_profiles
        return await prisma.provider_profiles.update({
            where: { user_id: providerId },
            data: { /* is_active bisa jadi indikator, atau tambah field warning_count */ }
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
    async createPricingType(categoryId: string, name: string, description?: string, defaultUnit?: string) {
        return await prisma.pricing_types.create({
            data: { category_id: categoryId, name, description, default_unit: defaultUnit }
        });
    }

    async deletePricingType(id: string) {
        return await prisma.pricing_types.delete({ where: { id } });
    }

    // Payment Accounts (Rekber Admin)
    async getPaymentAccounts() {
        return await prisma.admin_payment_accounts.findMany({
            orderBy: { created_at: 'asc' }
        });
    }

    async createPaymentAccount(data: {
        type: string;
        account_name: string;
        account_number: string;
        provider_name: string;
        qris_image_url?: string;
    }) {
        return await prisma.admin_payment_accounts.create({ data });
    }

    async updatePaymentAccount(id: string, data: {
        type?: string;
        account_name?: string;
        account_number?: string;
        provider_name?: string;
        qris_image_url?: string;
        is_active?: boolean;
    }) {
        return await prisma.admin_payment_accounts.update({
            where: { id },
            data
        });
    }

    async deletePaymentAccount(id: string) {
        return await prisma.admin_payment_accounts.delete({ where: { id } });
    }
}
