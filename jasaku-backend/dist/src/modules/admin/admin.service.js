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
    // Provider detail
    async getProviderDetail(providerId) {
        const profile = await prisma.provider_profiles.findUnique({
            where: { id: providerId },
            include: {
                users: {
                    select: { id: true, email: true, phone: true, status: true, created_at: true }
                },
                provider_documents: {
                    orderBy: { created_at: 'desc' }
                }
            }
        });
        if (!profile)
            throw new Error('Provider tidak ditemukan');
        const services = await prisma.provider_services.findMany({
            where: { provider_id: providerId },
            include: {
                services: { select: { id: true, name: true } },
                provider_service_prices: {
                    include: { pricing_types: { select: { id: true, name: true, default_unit: true } } }
                }
            }
        });
        return { ...profile, provider_services: services };
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
        const data = {
            is_verified: status === 'verified',
            verification_status: status,
        };
        if (notes !== undefined) {
            data.verification_notes = notes;
        }
        return await prisma.provider_profiles.update({
            where: { id: providerId },
            data,
        });
    }
    async unverifyProvider(providerId) {
        return await prisma.provider_profiles.update({
            where: { id: providerId },
            data: { is_verified: false, verification_status: 'pending' }
        });
    }
    // Categories
    async getAllCategories() {
        return await prisma.categories.findMany({ orderBy: { name: 'asc' } });
    }
    async getServicesByCategory(categoryId) {
        return await prisma.services.findMany({
            where: { category_id: categoryId },
            orderBy: { name: 'asc' }
        });
    }
    async getPricingTypesByCategory(categoryId) {
        return await prisma.pricing_types.findMany({
            where: { category_id: categoryId },
            orderBy: { name: 'asc' }
        });
    }
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
            include: { users: { select: { email: true, phone: true, status: true, created_at: true } } },
            orderBy: { created_at: 'desc' }
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
    // Orders pending payment (rekber)
    async getPendingPaymentOrders() {
        return await prisma.orders.findMany({
            where: { status: 'pending_payment' },
            orderBy: { created_at: 'desc' },
            select: {
                id: true,
                total_price: true,
                description: true,
                work_date: true,
                status: true,
                created_at: true,
                profiles_customer: {
                    select: { id: true, full_name: true, nickname: true }
                },
                payments: {
                    select: { id: true, method: true, amount: true, status: true, created_at: true }
                }
            }
        });
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
    async getOpenReports() {
        return await prisma.reports.findMany({
            where: { status: 'open' },
            orderBy: { created_at: 'desc' },
            include: {
                users: { select: { id: true, email: true } }
            }
        });
    }
    async respondToReport(reportId, response, status) {
        const report = await prisma.reports.findUnique({ where: { id: reportId } });
        if (!report)
            throw new Error('Laporan tidak ditemukan');
        return await prisma.reports.update({
            where: { id: reportId },
            data: {
                status,
                admin_response: response,
                resolved_at: new Date(),
            }
        });
    }
    async getPendingTasks() {
        return await prisma.custom_tasks.findMany({
            where: { status: 'open' },
            orderBy: { created_at: 'desc' },
            select: {
                id: true,
                title: true,
                description: true,
                budget_min: true,
                budget_max: true,
                address: true,
                deadline: true,
                status: true,
                created_at: true,
                users: {
                    select: {
                        profiles_customer: { select: { full_name: true } }
                    }
                }
            }
        });
    }
    async getPendingExtensions() {
        return await prisma.order_extensions.findMany({
            where: { status: 'pending' },
            orderBy: { created_at: 'desc' },
            include: {
                orders: {
                    select: {
                        id: true,
                        total_price: true,
                        description: true,
                        work_date: true,
                        platform_fee: true,
                        provider_profiles: { select: { full_name: true } },
                        profiles_customer: { select: { full_name: true } }
                    }
                }
            }
        });
    }
}
