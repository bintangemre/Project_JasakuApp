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

    // Provider detail
    async getProviderDetail(providerId: string) {
        const profile = await prisma.provider_profiles.findUnique({
            where: { id: providerId },
            include: {
                users: {
                    select: { id: true, email: true, phone: true, status: true, created_at: true }
                },
                provider_documents: {
                    orderBy: { created_at: 'desc' }
                },
                identity_verifications: true
            }
        });
        if (!profile) throw new Error('Provider tidak ditemukan');

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

    async verifyProvider(providerId: string, status: 'verified' | 'rejected', notes?: string) {
        const data: any = {
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
            include: { users: { select: { email: true, phone: true, status: true, created_at: true } } },
            orderBy: { created_at: 'desc' }
        });
    }

    async getAllCustomers() {
        return await prisma.profiles_customer.findMany({
            include: { users: { select: { id: true, email: true, phone: true, status: true, created_at: true } } }
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

    async getOpenReports() {
        return await prisma.reports.findMany({
            where: { status: 'open' },
            orderBy: { created_at: 'desc' },
            include: {
                users: { select: { id: true, email: true } }
            }
        });
    }

    async respondToReport(reportId: string, response: string, status: 'resolved' | 'dismissed') {
        const report = await prisma.reports.findUnique({ where: { id: reportId } });
        if (!report) throw new Error('Laporan tidak ditemukan');

        return await prisma.reports.update({
            where: { id: reportId },
            data: {
                status,
                admin_response: response,
                resolved_at: new Date(),
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
