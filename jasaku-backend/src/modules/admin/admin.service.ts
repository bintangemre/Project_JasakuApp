import {prisma} from '../../config/prisma';
import { NotificationService } from '../notifications/notifications.service';

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

    async verifyProvider(providerId: string, status: 'verified' | 'rejected', notes?: string, checklist?: Array<{ item: string; status: 'passed' | 'failed'; note?: string }>) {
        const data: any = {
            is_verified: status === 'verified',
            verification_status: status,
            is_active: status === 'verified',
        };
        if (status === 'rejected' && checklist && checklist.length > 0) {
            data.verification_notes = JSON.stringify({ checklist, notes: notes || '' });
        } else if (notes !== undefined) {
            data.verification_notes = notes;
        } else if (status === 'verified') {
            data.verification_notes = null;
        }
        const updated = await prisma.provider_profiles.update({
            where: { id: providerId },
            data,
        });

        const profile = await prisma.provider_profiles.findUnique({
            where: { id: providerId },
            select: { user_id: true }
        });
        if (profile) {
            const title = status === 'verified' ? 'Akun Terverifikasi' : 'Akun Ditolak';
            const body = status === 'verified'
                ? 'Selamat! Akun Mitra Anda telah diverifikasi. Silakan mulai menerima pesanan.'
                : 'Maaf, akun Mitra Anda ditolak. Silakan periksa detail di aplikasi.';
            NotificationService.sendToUser(
                profile.user_id, title, body,
                { type: status === 'verified' ? 'PROVIDER_VERIFIED' : 'PROVIDER_REJECTED' }
            ).catch(() => {});
        }

        return updated;
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
        const result = await prisma.users.update({
            where: { id: userId },
            data: { status: 'banned' }
        });
        NotificationService.sendToUser(
            userId,
            'Akun Diblokir',
            'Akun Anda telah diblokir oleh admin. Hubungi CS untuk informasi lebih lanjut.',
            { type: 'ACCOUNT_BANNED' }
        ).catch(() => {});
        return result;
    }

    async unbanUser(userId: string) {
        const result = await prisma.users.update({
            where: { id: userId },
            data: { status: 'active' }
        });
        NotificationService.sendToUser(
            userId,
            'Akun Diaktifkan',
            'Akun Anda telah diaktifkan kembali. Anda bisa login sekarang.',
            { type: 'ACCOUNT_UNBANNED' }
        ).catch(() => {});
        return result;
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
                provider_profiles: {
                    select: { id: true, full_name: true }
                },
                payments: {
                    select: { id: true, method: true, amount: true, status: true, created_at: true }
                }
            }
        });
    }

    // All orders for admin monitoring (regular orders only, custom tasks have their own page)
    async getAllOrders() {
        const orders = await prisma.orders.findMany({
            where: { task_provider_id: null },
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
                provider_profiles: {
                    select: { id: true, full_name: true }
                },
                payments: {
                    select: { id: true, method: true, amount: true, status: true, created_at: true, payment_proof: true }
                }
            }
        });

        const providerIds = [...new Set(orders.map(o => o.provider_profiles?.id).filter(Boolean))];
        let payoutMethods: any[] = [];
        if (providerIds.length > 0) {
            payoutMethods = await prisma.$queryRaw<Array<{
                id: string; provider_id: string; type: string;
                provider_name: string; account_number: string; account_name: string;
            }>>`
                SELECT ppm.id, ppm.provider_id, ppm.type, ppm.provider_name, ppm.account_number, ppm.account_name
                FROM provider_payout_methods ppm
                WHERE ppm.provider_id = ANY(${providerIds}::uuid[])
            `;
        }

        const payoutByProviderId = Object.fromEntries(
            payoutMethods.map(pm => [pm.provider_id, pm])
        );

        return orders.map(o => ({
            ...o,
            provider_payout: o.provider_profiles?.id
                ? (payoutByProviderId[o.provider_profiles.id] ?? null)
                : null,
        }));
    }

    // Payment Accounts (Rekber Admin)
    async getPaymentAccounts() {
        const [banks, ewallets, qris] = await Promise.all([
            prisma.admin_bank_accounts.findMany({ orderBy: { created_at: 'asc' } }),
            prisma.admin_ewallet_accounts.findMany({ orderBy: { created_at: 'asc' } }),
            prisma.admin_qris_accounts.findMany({ orderBy: { created_at: 'asc' } }),
        ]);
        return [
            ...banks.map(a => ({ ...a, type: 'bank_transfer', account_number: a.account_number, account_name: a.account_name, qris_image_url: null })),
            ...ewallets.map(a => ({ ...a, type: 'e_wallet', account_number: a.account_number, account_name: a.account_name, qris_image_url: null })),
            ...qris.map(a => ({ ...a, type: 'qris', account_number: null, account_name: null, qris_image_url: a.qris_image_url })),
        ];
    }

    async createPaymentAccount(data: {
        type: string;
        account_name: string;
        account_number: string;
        provider_name: string;
        qris_image_url?: string;
    }) {
        if (data.type === 'bank_transfer') {
            return await prisma.admin_bank_accounts.create({
                data: { provider_name: data.provider_name, account_number: data.account_number, account_name: data.account_name }
            });
        }
        if (data.type === 'e_wallet') {
            return await prisma.admin_ewallet_accounts.create({
                data: { provider_name: data.provider_name, account_number: data.account_number, account_name: data.account_name }
            });
        }
        if (data.type === 'qris') {
            return await prisma.admin_qris_accounts.create({
                data: { provider_name: data.provider_name, qris_image_url: data.qris_image_url ?? '' }
            });
        }
        throw new Error('Tipe rekber tidak valid');
    }

    async updatePaymentAccount(id: string, data: {
        type?: string;
        account_name?: string;
        account_number?: string;
        provider_name?: string;
        qris_image_url?: string;
        is_active?: boolean;
    }) {
        const bank = await prisma.admin_bank_accounts.findUnique({ where: { id } });
        if (bank) {
            return await prisma.admin_bank_accounts.update({ where: { id }, data: { provider_name: data.provider_name, account_number: data.account_number, account_name: data.account_name, is_active: data.is_active } });
        }
        const ewallet = await prisma.admin_ewallet_accounts.findUnique({ where: { id } });
        if (ewallet) {
            return await prisma.admin_ewallet_accounts.update({ where: { id }, data: { provider_name: data.provider_name, account_number: data.account_number, account_name: data.account_name, is_active: data.is_active } });
        }
        const qris = await prisma.admin_qris_accounts.findUnique({ where: { id } });
        if (qris) {
            return await prisma.admin_qris_accounts.update({ where: { id }, data: { provider_name: data.provider_name, qris_image_url: data.qris_image_url, is_active: data.is_active } });
        }
        throw new Error('Rekber tidak ditemukan');
    }

    async deletePaymentAccount(id: string) {
        const bank = await prisma.admin_bank_accounts.findUnique({ where: { id } });
        if (bank) { await prisma.admin_bank_accounts.delete({ where: { id } }); return; }
        const ewallet = await prisma.admin_ewallet_accounts.findUnique({ where: { id } });
        if (ewallet) { await prisma.admin_ewallet_accounts.delete({ where: { id } }); return; }
        const qris = await prisma.admin_qris_accounts.findUnique({ where: { id } });
        if (qris) { await prisma.admin_qris_accounts.delete({ where: { id } }); return; }
        throw new Error('Rekber tidak ditemukan');
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
        const report = await prisma.reports.findUnique({
            where: { id: reportId },
            include: { users: { select: { email: true } } }
        });
        if (!report) throw new Error('Laporan tidak ditemukan');

        const updated = await prisma.reports.update({
            where: { id: reportId },
            data: {
                status,
                admin_response: response,
                resolved_at: new Date(),
            }
        });

        // Kirim notifikasi ke pelapor
        const statusLabel = status === 'resolved' ? 'terselesaikan' : 'ditutup';
        NotificationService.sendToUser(
            report.reporter_id,
            `Laporan ${statusLabel}`,
            `Laporan "${report.subject}" telah ${statusLabel} oleh admin. Respon: ${response}`,
            { reportId, type: 'REPORT_RESPONDED' }
        ).catch(() => {});

        return updated;
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

    async getAllExtensions() {
        return await prisma.order_extensions.findMany({
            orderBy: { created_at: 'desc' },
            include: {
                orders: {
                    select: {
                        id: true,
                        total_price: true,
                        description: true,
                        work_date: true,
                        platform_fee: true,
                        additional_fee: true,
                        provider_profiles: { select: { full_name: true } },
                        profiles_customer: { select: { full_name: true } }
                    }
                }
            }
        });
    }

    async getPendingPaymentExtensions() {
        return await prisma.order_extensions.findMany({
            where: { status: 'pending_payment' },
            orderBy: { created_at: 'desc' },
            include: {
                orders: {
                    select: {
                        id: true,
                        total_price: true,
                        description: true,
                        work_date: true,
                        platform_fee: true,
                        additional_fee: true,
                        provider_profiles: { select: { full_name: true } },
                        profiles_customer: { select: { full_name: true } }
                    }
                }
            }
        });
    }

    // All completed orders (regular orders only) — shows both pending and confirmed payouts
    async getCompletedOrdersPendingPayout() {
        const orders = await prisma.orders.findMany({
            where: {
                status: 'completed',
                task_provider_id: null, // regular orders only, not custom tasks
            },
            orderBy: [{ payout_confirmed: 'asc' }, { created_at: 'desc' }],
            select: {
                id: true,
                total_price: true,
                platform_fee: true,
                work_date: true,
                status: true,
                payout_confirmed: true,
                created_at: true,
                profiles_customer: {
                    select: { id: true, full_name: true, nickname: true }
                },
                provider_profiles: {
                    select: { id: true, full_name: true }
                },
                payments: {
                    select: { id: true, method: true, status: true }
                }
            }
        });

        const providerIds = [...new Set(orders.map(o => o.provider_profiles?.id).filter(Boolean))];
        let payoutMethods: any[] = [];
        if (providerIds.length > 0) {
            payoutMethods = await prisma.$queryRaw<Array<{
                id: string; provider_id: string; type: string;
                provider_name: string; account_number: string; account_name: string;
            }>>`
                SELECT ppm.id, ppm.provider_id, ppm.type, ppm.provider_name, ppm.account_number, ppm.account_name
                FROM provider_payout_methods ppm
                WHERE ppm.provider_id = ANY(${providerIds}::uuid[])
            `;
        }

        const payoutByProviderId = Object.fromEntries(
            payoutMethods.map(pm => [pm.provider_id, pm])
        );

        return orders.map(o => ({
            ...o,
            provider_payout: o.provider_profiles?.id
                ? (payoutByProviderId[o.provider_profiles.id] ?? null)
                : null,
        }));
    }

    async confirmOrderPayout(orderId: string) {
        const order = await prisma.orders.findUnique({
            where: { id: orderId },
            select: { id: true, status: true, payout_confirmed: true, provider_id: true }
        });
        if (!order) throw new Error('Order tidak ditemukan');
        if (order.status !== 'completed') throw new Error('Order belum selesai');
        if (order.payout_confirmed) throw new Error('Payout sudah dikonfirmasi sebelumnya');

        const updated = await prisma.orders.update({
            where: { id: orderId },
            data: { payout_confirmed: true, payout_at: new Date() }
        });

        // Get provider user_id for notification
        const profile = await prisma.provider_profiles.findUnique({
            where: { id: order.provider_id },
            select: { user_id: true, full_name: true }
        });
        if (profile) {
            NotificationService.sendToUser(
                profile.user_id,
                'Pencairan Dana Berhasil',
                'Dana untuk pesanan telah dikirim ke rekening Anda. Terima kasih atas kerja kerasnya!',
                { orderId, type: 'ORDER_PAYOUT_CONFIRMED' }
            ).catch(() => {});
        }

        return updated;
    }

    async getNotificationCounts() {
        const [
            pendingPayments,
            pendingExtensions,
            pendingTaskPayments,
            pendingTaskPayouts,
            pendingOrderPayouts,
            pendingProviders,
            openReports,
        ] = await Promise.all([
            // Regular orders pending payment confirmation
            prisma.orders.count({
                where: { status: 'pending_payment', task_provider_id: null }
            }),
            // Order extensions pending payment
            prisma.order_extensions.count({ where: { status: 'pending_payment' } }),
            // Custom task orders pending payment confirmation by admin
            prisma.$queryRaw<[{count: bigint}]>`
                SELECT COUNT(*) as count FROM orders o
                JOIN task_providers tp ON o.task_provider_id = tp.id
                WHERE o.status = 'pending_payment'
            `.then(r => Number(r[0]?.count || 0)),
            // Custom task payouts pending release
            prisma.task_providers.count({
                where: {
                    status: 'completed',
                    payout_confirmed: false,
                }
            }),
            // Regular orders completed, pending payout to provider
            prisma.orders.count({
                where: { status: 'completed', payout_confirmed: false, task_provider_id: null }
            }),
            // Provider verifications pending
            prisma.provider_profiles.count({ where: { verification_status: 'pending' } }),
            // Open reports
            prisma.reports.count({ where: { status: 'open' } }),
        ]);

        return {
            pendingPayments,
            pendingExtensions,
            pendingTaskPayments,
            pendingTaskPayouts,
            pendingOrderPayouts,
            pendingProviders,
            openReports,
            total: pendingPayments + pendingExtensions + pendingTaskPayments + pendingOrderPayouts + pendingProviders + openReports,
        };
    }
}
