import { prisma } from "../../config/prisma";
import { NotificationService } from "../notifications/notifications.service";
import { LocationService } from "../locations/locations.service";
import { canOrderNow, isSameWitaDate, canTransitionWorkflow, canCompleteWork, getTodayWitaDate } from "../../utils/operating-hours";

// State machine: status transisi yang valid
const VALID_TRANSITIONS: Record<string, string[]> = {
    pending_payment: ['pending', 'cancelled'], // admin konfirmasi atau customer cancel
    pending:         ['accepted', 'rejected', 'cancelled'],
    accepted:        ['on_the_way', 'cancelled'],
    on_the_way:      ['arrived', 'cancelled'],
    arrived:         ['in_progress', 'cancelled'],
    in_progress:     ['completed'],
    completed:       [],
    rejected:        [],
    cancelled:       [],
};

// Interface Payload yang Lebih Ketat
interface CreateOrderDto {
    customerId: string;
    providerId: string;
    serviceId: string;
    pricingTypeId: string;
    quantity: number;
    description: string;
    workDate: string;
    address: string;
    lat: number;   // Wajibkan untuk akurasi data
    lng: number; // Wajibkan untuk akurasi data
    attachments: string[];
}

export class OrdersService {
    async findNearbyProviders(serviceId: string, customerLat: number, customerLng: number, maxDistanceMeters = 50000) {
        return await prisma.$queryRaw`
            SELECT 
                u.id, 
                pp.full_name as provider_name, 
                s.name as service_name,
                pl.address,
                ST_DistanceSphere(
                    pl.location, 
                    ST_SetSRID(ST_MakePoint(${customerLng}, ${customerLat}), 4326)
                ) as distance_meters
            FROM users u
            JOIN roles r ON u.role_id = r.id
            JOIN provider_profiles pp ON u.id = pp.user_id
            JOIN provider_locations pl ON u.id = pl.provider_id
            JOIN provider_services ps ON u.id = ps.provider_id
            JOIN services s ON ps.service_id = s.id
            WHERE ps.service_id = ${serviceId}::uuid
              AND r.name = 'provider'
              AND pp.is_active = true
              AND ST_DWithin(
                    pl.location, 
                    ST_SetSRID(ST_MakePoint(${customerLng}, ${customerLat}), 4326), 
                    ${maxDistanceMeters} / 111319.9
                  )
            ORDER BY distance_meters ASC
            LIMIT 10;
        `;
    }

    async createOrder(data: CreateOrderDto) {
        // System per-hari: quantity always 1
        if (data.quantity <= 0) {
            throw new Error("Kuantitas pesanan harus lebih dari 0");
        }

        const parsedDate = new Date(data.workDate + 'T00:00:00');
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        if (isNaN(parsedDate.getTime()) || parsedDate < today) {
            throw new Error("Tanggal pekerjaan tidak valid atau tidak boleh di masa lalu");
        }

        const customerProfile = await prisma.profiles_customer.findUnique({
            where: { user_id: data.customerId }
        });
        if (!customerProfile) throw new Error("Profil customer tidak ditemukan");

        const providerProfile = await prisma.provider_profiles.findUnique({
            where: { id: data.providerId }
        });
        if (!providerProfile) throw new Error("Profil provider tidak ditemukan");

        // Validasi jam operasional untuk order hari ini
        let orderWarning: string | undefined;
        if (isSameWitaDate(parsedDate)) {
            const orderCheck = canOrderNow();
            if (!orderCheck.allowed) {
                throw new Error(orderCheck.warning!);
            }
            if (orderCheck.warning) {
                orderWarning = orderCheck.warning;
            }
        }

        const order = await prisma.$transaction(async (tx) => {
            const providerService = await tx.provider_services.findFirst({
                where: { provider_id: data.providerId, service_id: data.serviceId },
                select: {
                    provider_service_prices: {
                        where: { pricing_type_id: data.pricingTypeId }
                    }
                }
            });
            if (!providerService || providerService.provider_service_prices.length === 0) {
                throw new Error("Layanan tidak tersedia atau harga tidak tersedia pada provider ini");
            }

            const pricePerUnit = providerService.provider_service_prices[0].price;
            const totalPrice = Number(pricePerUnit) * data.quantity;

            // Cek apakah provider sudah punya order aktif di tanggal tsb
            const activeOrder = await tx.orders.findFirst({
                where: {
                    provider_id: providerProfile.id,
                    work_date: parsedDate,
                    status: { in: ['pending_payment', 'pending', 'accepted', 'on_the_way', 'arrived', 'in_progress'] }
                }
            });
            if (activeOrder) {
                throw new Error("Ups, Jasa ini udah punya pesanan di tanggal ini. Coba pilih tanggal lain.");
            }

            // Cek schedule sebagai fallback
            const existingSchedule = await tx.provider_schedules.findUnique({
                where: {
                    provider_id_work_date: {
                        provider_id: providerProfile.id,
                        work_date: parsedDate,
                    }
                }
            });
            if (existingSchedule?.is_booked) {
                throw new Error("Ups, Jasa ini udah punya pesanan di tanggal ini. Coba pilih tanggal lain.");
            }

            const order = await tx.orders.create({
                data: {
                    customer_id: customerProfile.id,
                    provider_id: providerProfile.id,
                    total_price: totalPrice,
                    platform_fee: 2000,
                    description: data.description,
                    work_date: parsedDate,
                    end_date: parsedDate,
                    status: 'pending_payment',
                }
            });

            await tx.order_items.create({
                data: {
                    order_id: order.id,
                    service_id: data.serviceId,
                    pricing_type_id: data.pricingTypeId,
                    quantity: data.quantity,
                    price: pricePerUnit,
                    subtotal: totalPrice
                }
            });

            await tx.$executeRaw`
                INSERT INTO order_locations (id, order_id, address, location)
                VALUES (
                    uuid_generate_v4(),
                    ${order.id}::uuid,
                    ${data.address},
                    ST_SetSRID(ST_MakePoint(${data.lng}, ${data.lat}), 4326)
                )
            `;

            if (data.attachments && data.attachments.length > 5) {
                throw new Error("Maksimal 5 lampiran.");
            }

            if (data.attachments && data.attachments.length > 0) {
                await tx.order_attachments.createMany({
                    data: data.attachments.map((url) => ({
                        order_id: order.id,
                        file_url: url,
                    })),
                });
            }

            return order;
        });

        return { order, warning: orderWarning };
    }


    async getOrderExtensions(orderId: string) {
        return await prisma.order_extensions.findMany({
            where: { order_id: orderId },
            orderBy: { created_at: 'desc' },
            select: {
                id: true,
                extension_count: true,
                additional_cost: true,
                platform_fee_rate: true,
                status: true,
                response_note: true,
                created_at: true,
                provider_id: true,
                customer_id: true,
                orders: {
                    select: {
                        id: true,
                        total_price: true,
                        platform_fee: true,
                        work_date: true,
                        provider_profiles: { select: { full_name: true } },
                        profiles_customer: { select: { full_name: true } }
                    }
                }
            }
        });
    }

    async getOrderDetails(orderId: string) {
        return await prisma.orders.findUnique({
            where: { id: orderId },
            select: {
                id: true,
                total_price: true,
                additional_fee: true,
                description: true,
                work_date: true,
                end_date: true,
                status: true,
                created_at: true,
                profiles_customer: {
                    select: {
                        id: true,
                        full_name: true,
                        nickname: true,
                        created_at: true
                    }
                },
                provider_profiles: {
                    select: {
                        id: true,
                        full_name: true,
                        nickname: true,
                        created_at: true
                    }
                },
                order_attachments: {
                    select: {
                        id: true,
                        file_url: true,
                        created_at: true
                    }
                },

                order_items: {
                    select: {
                        id: true,
                        quantity: true,
                        price: true,
                        subtotal: true,
                        services: {
                            select: {
                                id: true,
                                name: true,
                                created_at: true
                            }
                        },
                    }
                },
                order_locations: {
                    select: {
                        address: true
                    }
                }
            }
        });
    }

    async getOrderTracking(orderId: string) {
        const order = await prisma.orders.findUnique({
            where: { id: orderId },
            select: {
                id: true,
                status: true,
                customer_id: true,
                provider_id: true,
                assignment_type: true,
                custom_task_id: true,
                order_locations: {
                    select: { address: true }
                }
            }
        });
        if (!order) return null;

        const providerProfile = await prisma.provider_profiles.findUnique({
            where: { id: order.provider_id },
            select: { user_id: true, full_name: true }
        });
        if (!providerProfile) return null;

        const locationService = new LocationService();
        const providerLocation = await locationService.getProviderLocation(providerProfile.user_id);

        let customerLat: number | null = null;
        let customerLng: number | null = null;
        let customerAddress: string | null = null;

        // Coba ambil dari order_locations dulu
        const orderLocation = await prisma.$queryRaw<Array<{ lat: number; lng: number }>>`
            SELECT 
                ST_Y(location::geometry) as lat,
                ST_X(location::geometry) as lng
            FROM order_locations
            WHERE order_id = ${orderId}::uuid
            LIMIT 1
        `;

        if (orderLocation.length > 0) {
            customerLat = orderLocation[0].lat;
            customerLng = orderLocation[0].lng;
            customerAddress = order.order_locations[0]?.address ?? null;
        } else if (order.custom_task_id) {
            // Custom task: ambil lokasi dari custom_tasks
            const ctLoc = await prisma.$queryRaw<Array<{ lat: number; lng: number; address: string | null }>>`
                SELECT 
                    ST_Y(location::geometry) as lat,
                    ST_X(location::geometry) as lng,
                    address
                FROM custom_tasks
                WHERE id = ${order.custom_task_id}::uuid
                LIMIT 1
            `;
            if (ctLoc.length > 0) {
                customerLat = ctLoc[0].lat;
                customerLng = ctLoc[0].lng;
                customerAddress = ctLoc[0].address;
            }
        }

        return {
            orderId: order.id,
            status: order.status,
            providerName: providerProfile.full_name,
            providerLocation: providerLocation
                ? { lat: providerLocation.lat, lng: providerLocation.lng, address: providerLocation.address }
                : null,
            orderLocation: customerLat != null && customerLng != null
                ? { lat: customerLat, lng: customerLng, address: customerAddress }
                : null,
        };
    }

    async getCustomerOrders(userId: string, statusFilter?: string) {
        const profile = await prisma.profiles_customer.findUnique({
            where: { user_id: userId },
            select: { id: true }
        });
        if (!profile) return [];

        const terminalStatuses = ["completed", "cancelled", "rejected"];
        const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

        const whereClause: any = { customer_id: profile.id };
        if (statusFilter) {
            if (statusFilter === 'active') {
                whereClause.status = { notIn: terminalStatuses };
            } else {
                whereClause.status = statusFilter;
            }
        }

        whereClause.NOT = {
            status: { in: terminalStatuses },
            created_at: { lt: twentyFourHoursAgo },
        };

        return await prisma.orders.findMany({
            where: whereClause,
            orderBy: { created_at: "desc" },
            select: {
                id: true,
                work_date: true,
                end_date: true,
                additional_fee: true,
                status: true,
                total_price: true,
                description: true,
                created_at: true,
                provider_profiles: {
                    select: { id: true, full_name: true, user_id: true }
                }
            }
        });
    }

    async getProviderOrders(userId: string, statusFilter?: string, scope?: 'today' | 'upcoming' | 'history') {
        const profile = await prisma.provider_profiles.findUnique({
            where: { user_id: userId },
            select: { id: true }
        });
        if (!profile) return [];

        const whereClause: any = { provider_id: profile.id };
        if (statusFilter) {
            whereClause.status = statusFilter;
        }

        const todayStart = getTodayWitaDate();
        const tomorrowStart = new Date(todayStart);
        tomorrowStart.setDate(tomorrowStart.getDate() + 1);

        if (scope === 'today') {
            whereClause.work_date = { gte: todayStart, lt: tomorrowStart };
        } else if (scope === 'upcoming') {
            whereClause.work_date = { gt: todayStart };
        } else if (scope === 'history') {
            whereClause.status = 'completed';
        }

        const orders = await prisma.orders.findMany({
            where: whereClause,
            select: {
                id: true,
                total_price: true,
                platform_fee: true,
                additional_fee: true,
                description: true,
                work_date: true,
                end_date: true,
                status: true,
                assignment_type: true,
                custom_task_id: true,
                created_at: true,
                profiles_customer: {
                    select: { id: true, full_name: true, created_at: true }
                },
                order_attachments: {
                    select: { id: true, file_url: true, created_at: true }
                },
                order_items: {
                    select: {
                        id: true,
                        quantity: true,
                        price: true,
                        subtotal: true,
                        services: { select: { id: true, name: true, created_at: true } }
                    }
                },
                order_locations: { select: { address: true } }
            },
            orderBy: { created_at: 'desc' }
        });

        const orderIds = orders.map(o => o.id);
        if (orderIds.length > 0) {
            const locations = await prisma.$queryRaw<Array<{ order_id: string; lat: number | null; lng: number | null }>>`
                SELECT ol.order_id, ST_Y(ol.location::geometry) as lat, ST_X(ol.location::geometry) as lng
                FROM order_locations ol
                WHERE ol.order_id = ANY(${orderIds}::uuid[])
            `;
            const locMap = new Map(locations.map(l => [l.order_id, l]));
            for (const order of orders) {
                const loc = locMap.get(order.id);
                if (loc && order.order_locations.length > 0) {
                    (order.order_locations[0] as Record<string, unknown>).lat = loc.lat;
                    (order.order_locations[0] as Record<string, unknown>).lng = loc.lng;
                }
            }
        }

        return orders;
    }

    async getProviderRequests(userId: string) {
        const profile = await prisma.provider_profiles.findUnique({
            where: { user_id: userId },
            select: { id: true }
        });
        if (!profile) return [];

        const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
        const todayStart = new Date();
        todayStart.setHours(0, 0, 0, 0);

        const expiredOrders = await prisma.orders.findMany({
            where: {
                provider_id: profile.id,
                status: 'pending',
                work_date: { lte: todayStart },
                OR: [
                    { start_date: null, created_at: { lt: fiveMinutesAgo } },
                    { start_date: { not: null, lt: fiveMinutesAgo } }
                ]
            },
            select: {
                id: true,
                customer_id: true,
                work_date: true,
                profiles_customer: { select: { user_id: true } }
            }
        });

        for (const order of expiredOrders) {
            await prisma.orders.update({
                where: { id: order.id },
                data: { status: 'cancelled' }
            });
            // Bersihkan provider_schedules agar tanggal bisa dipakai order lain
            if (order.work_date) {
                await prisma.provider_schedules.updateMany({
                    where: { provider_id: profile.id, work_date: order.work_date },
                    data: { is_booked: false }
                });
            }
            try {
                await NotificationService.sendToUser(
                    order.profiles_customer.user_id,
                    "Pesanan Dibatalkan",
                    "Pesanan dibatalkan karena tidak diterima dalam 5 menit.",
                    { orderId: order.id, type: "ORDER_CANCELLED" }
                );
            } catch (_) {}
        }

        const orders = await prisma.orders.findMany({
            where: {
                provider_id: profile.id,
                status: 'pending',
                assignment_type: { not: 'custom_task' },
            },
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
                order_attachments: {
                    select: { id: true, file_url: true }
                },
                order_items: {
                    select: {
                        id: true,
                        quantity: true,
                        price: true,
                        subtotal: true,
                        services: { select: { id: true, name: true } }
                    }
                },
                order_locations: { select: { address: true } }
            },
            orderBy: { created_at: 'desc' }
        });

        const orderIds = orders.map(o => o.id);
        if (orderIds.length > 0) {
            const locations = await prisma.$queryRaw<Array<{ order_id: string; lat: number | null; lng: number | null }>>`
                SELECT ol.order_id, ST_Y(ol.location::geometry) as lat, ST_X(ol.location::geometry) as lng
                FROM order_locations ol
                WHERE ol.order_id = ANY(${orderIds}::uuid[])
            `;
            const locMap = new Map(locations.map(l => [l.order_id, l]));
            for (const order of orders) {
                const loc = locMap.get(order.id);
                if (loc && order.order_locations.length > 0) {
                    (order.order_locations[0] as Record<string, unknown>).lat = loc.lat;
                    (order.order_locations[0] as Record<string, unknown>).lng = loc.lng;
                }
            }
        }

        return orders;
    }


    async receiveOrderStatus(userId: string, orderId: string, status: string) {
        const profile = await prisma.provider_profiles.findUnique({
            where: { user_id: userId },
            select: { id: true }
        });
        if (!profile) throw new Error("Profile provider tidak ditemukan");

        // Accept path — atomic transaction mencegah race condition (double-accept)
        if (status === 'accepted') {
            return await prisma.$transaction(async (tx) => {
                const order = await tx.orders.findUnique({ where: { id: orderId } });
                if (!order) throw new Error("Order tidak ditemukan");
                if (order.provider_id !== profile.id) throw new Error("Anda tidak berhak mengubah order ini");

                const current = order.status || 'pending';
                const allowed = VALID_TRANSITIONS[current] || [];
                if (!allowed.includes('accepted')) throw new Error(`Status ${current} tidak bisa berubah ke accepted`);

                const activeOrder = await tx.orders.findFirst({
                    where: {
                        provider_id: profile.id,
                        status: { in: ["accepted", "on_the_way", "arrived", "in_progress"] },
                        assignment_type: { not: 'custom_task' },
                        work_date: order.work_date,
                        NOT: { id: orderId }
                    }
                });
                if (activeOrder) throw new Error("Selesaikan pekerjaan aktif terlebih dahulu.");

                // updateMany + filter status pending = atomic: cuma 1 yg berhasil
                const result = await tx.orders.updateMany({
                    where: { id: orderId, status: 'pending' },
                    data: { status: 'accepted', start_date: new Date() }
                });
                if (result.count === 0) throw new Error("Order sudah diambil provider lain");

                const updated = await tx.orders.findUnique({ where: { id: orderId } })!;

                try {
                    const customerProfile = await tx.profiles_customer.findUnique({
                        where: { id: order.customer_id },
                        select: { user_id: true }
                    });
                    if (customerProfile?.user_id) {
                        await NotificationService.sendToUser(customerProfile.user_id, "Pesanan Diterima", "Provider telah menerima pesanan Anda.", { orderId, type: "ORDER_ACCEPTED" });
                    }
                } catch (_) {}

                return updated;
            });
        }

        // Non-accept flows (rejected, on_the_way, arrived, in_progress, completed)
        const order = await prisma.orders.findUnique({ where: { id: orderId } });
        if (!order) throw new Error("Order tidak ditemukan");
        if (order.provider_id !== profile.id) throw new Error("Anda tidak berhak mengubah order ini");

        const current = order.status || 'pending';
        const allowed = VALID_TRANSITIONS[current] || [];
        if (!allowed.includes(status)) throw new Error(`Status ${current} tidak bisa berubah ke ${status}`);

        // Validasi jam operasional untuk transisi kerja hari ini
        if (order.work_date && isSameWitaDate(order.work_date)) {
            if (['on_the_way', 'arrived', 'in_progress'].includes(status)) {
                const check = canTransitionWorkflow();
                if (!check.allowed) throw new Error(check.message!);
            }
            if (status === 'completed') {
                const check = canCompleteWork();
                if (!check.allowed) throw new Error(check.message!);
            }
        }

        const updateData: any = { status };
        const updated = await prisma.orders.update({
            where: { id: orderId },
            data: updateData
        });

        if (status === 'completed') {
            await prisma.provider_profiles.update({
                where: { id: order.provider_id },
                data: { total_jobs: { increment: 1 } }
            });
            if (order.work_date) {
                await prisma.provider_schedules.updateMany({
                    where: { provider_id: order.provider_id, work_date: order.work_date },
                    data: { is_booked: false }
                });
            }
        }

        // Bersihkan provider_schedules saat rejected agar tanggal bisa dipakai order lain
        if (status === 'rejected' && order.work_date) {
            await prisma.provider_schedules.updateMany({
                where: { provider_id: order.provider_id, work_date: order.work_date },
                data: { is_booked: false }
            });
        }

        // Notifikasi untuk non-accept statuses
        try {
            const customerProfile = await prisma.profiles_customer.findUnique({
                where: { id: order.customer_id },
                select: { user_id: true }
            });
            const customerUserId = customerProfile?.user_id;
            if (customerUserId) {
                if (status === 'rejected') {
                    await NotificationService.sendToUser(customerUserId, "Pesanan Ditolak", "Maaf, provider menolak pesanan Anda.", { orderId, type: "ORDER_REJECTED" });
                } else if (status === 'on_the_way') {
                    await NotificationService.sendToUser(customerUserId, "Provider Berangkat", "Provider sedang menuju lokasi Anda.", { orderId, type: "ON_THE_WAY" });
                } else if (status === 'arrived') {
                    await NotificationService.sendToUser(customerUserId, "Provider Tiba", "Provider sudah sampai di lokasi.", { orderId, type: "ARRIVED" });
                } else if (status === 'in_progress') {
                    await NotificationService.sendToUser(customerUserId, "Pekerjaan Dimulai", "Provider mulai mengerjakan pesanan Anda.", { orderId, type: "IN_PROGRESS" });
                } else if (status === 'completed') {
                    await NotificationService.sendToUser(customerUserId, "Pekerjaan Selesai", "Pesanan Anda telah selesai. Silakan beri rating.", { orderId, type: "COMPLETED" });
                }
            }
        } catch (_) {}

        return updated;
    }

    async getProviderSchedule(userId: string, startDate?: string, endDate?: string) {
        const profile = await prisma.provider_profiles.findUnique({
            where: { user_id: userId },
            select: { id: true }
        });
        if (!profile) return [];

        const whereClause: any = { provider_id: profile.id };
        if (startDate && endDate) {
            whereClause.work_date = { gte: new Date(startDate), lte: new Date(endDate) };
        } else if (startDate) {
            whereClause.work_date = { gte: new Date(startDate) };
        } else {
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            whereClause.work_date = { gte: today };
        }

        return await prisma.provider_schedules.findMany({
            where: whereClause,
            orderBy: { work_date: 'asc' },
            include: {
                orders: {
                    select: {
                        id: true,
                        status: true,
                        total_price: true,
                        profiles_customer: { select: { full_name: true } }
                    }
                }
            }
        });
    }

    async getPublicProviderStatus(providerId: string) {
        const profile = await prisma.provider_profiles.findUnique({
            where: { id: providerId },
            select: { id: true, is_active: true, task_available: true }
        });
        if (!profile) return { hasActiveOrder: false, is_active: false, task_available: false };

        const activeOrder = await prisma.orders.findFirst({
            where: {
                provider_id: profile.id,
                status: { in: ['accepted', 'on_the_way', 'arrived', 'in_progress'] },
            },
            select: { id: true }
        });

        return {
            hasActiveOrder: !!activeOrder,
            is_active: profile.is_active,
            task_available: profile.task_available,
        };
    }

    async getPublicProviderSchedule(providerId: string, startDate?: string, endDate?: string) {
        const profile = await prisma.provider_profiles.findUnique({
            where: { id: providerId },
            select: { id: true }
        });
        if (!profile) return [];

        const whereClause: any = { provider_id: profile.id, is_booked: true };

        if (startDate && endDate) {
            whereClause.work_date = { gte: new Date(startDate), lte: new Date(endDate) };
        } else {
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            whereClause.work_date = { gte: today };
        }

        return await prisma.provider_schedules.findMany({
            where: whereClause,
            orderBy: { work_date: 'asc' },
            select: { work_date: true }
        });
    }

    async getTodayOrders(userId: string) {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const tomorrow = new Date(today);
        tomorrow.setDate(tomorrow.getDate() + 1);

        const profile = await prisma.provider_profiles.findUnique({
            where: { user_id: userId },
            select: { id: true }
        });
        if (!profile) return [];

        return await prisma.orders.findMany({
            where: {
                provider_id: profile.id,
                work_date: { gte: today, lt: tomorrow },
                status: { in: ['pending', 'accepted', 'on_the_way', 'arrived'] }
            },
            select: {
                id: true,
                work_date: true,
                status: true,
                total_price: true,
                profiles_customer: {
                    select: { full_name: true, address: true }
                }
            },
            orderBy: { work_date: 'asc' }
        });
    }

    async cancelOrder(userId: string, orderId: string) {
        const order = await prisma.orders.findUnique({ where: { id: orderId } });
        if (!order) throw new Error("Order tidak ditemukan");

        const profile = await prisma.profiles_customer.findUnique({
            where: { user_id: userId },
            select: { id: true }
        });
        if (!profile || order.customer_id !== profile.id) {
            throw new Error("Anda tidak berhak membatalkan order ini");
        }

        const current = order.status || 'pending';
        const allowed = VALID_TRANSITIONS[current] || [];
        if (!allowed.includes('cancelled')) {
            throw new Error(`Order dengan status ${current} tidak dapat dibatalkan`);
        }

        // Jika provider sudah accept, customer hanya punya 10 menit untuk cancel
        if (current === 'accepted' && order.start_date) {
            const elapsed = Date.now() - new Date(order.start_date).getTime();
            if (elapsed > 10 * 60 * 1000) {
                throw new Error("Waktu pembatalan telah habis (batas 10 menit setelah diterima provider)");
            }
        }

        await prisma.orders.update({
            where: { id: orderId },
            data: { status: 'cancelled' }
        });

        // Bersihkan provider_schedules agar tanggal bisa dipakai order lain
        if (order.work_date) {
            await prisma.provider_schedules.updateMany({
                where: { provider_id: order.provider_id, work_date: order.work_date },
                data: { is_booked: false }
            });
        }

        try {
            const providerProfile = await prisma.provider_profiles.findUnique({
                where: { id: order.provider_id },
                select: { user_id: true }
            });
            if (providerProfile) {
                await NotificationService.sendToUser(
                    providerProfile.user_id,
                    "Pesanan Dibatalkan",
                    "Customer telah membatalkan pesanan.",
                    { orderId, type: "ORDER_CANCELLED" }
                );
            }
        } catch (_) {}

        return { message: "Order berhasil dibatalkan" };
    }

    async requestExtension(userId: string, orderId: string, extensionDays: number) {
        if (extensionDays < 1 || extensionDays > 3) {
            throw new Error("Ekstensi minimal 1 hari dan maksimal 3 hari");
        }

        const order = await prisma.orders.findUnique({
            where: { id: orderId },
            include: {
                provider_profiles: { select: { user_id: true, id: true } },
                profiles_customer: { select: { user_id: true } }
            }
        });
        if (!order) throw new Error("Order tidak ditemukan");

        const profile = await prisma.provider_profiles.findUnique({
            where: { user_id: userId },
            select: { id: true }
        });
        if (!profile || order.provider_id !== profile.id) {
            throw new Error("Anda tidak berhak request ekstensi order ini");
        }

        if (order.status !== 'in_progress' && order.status !== 'accepted') {
            throw new Error("Ekstensi hanya bisa diajukan untuk order yang sedang berjalan");
        }

        // Cek total ekstensi yg sudah ada
        const existingExtensions = await prisma.order_extensions.findMany({
            where: { order_id: orderId }
        });
        const totalExistingDays = existingExtensions.reduce((sum, ext) => sum + ext.extension_count, 0);
        const totalRequestedDays = totalExistingDays + extensionDays;
        if (totalRequestedDays > 3) {
            throw new Error(`Total ekstensi maksimal 3 hari. Sudah terpakai ${totalExistingDays} hari`);
        }

        // Cek apakah masih ada ekstensi yang belum selesai
        const pendingExt = existingExtensions.find(e =>
            ['pending_customer', 'pending_payment', 'pending'].includes(e.status)
        );
        if (pendingExt) {
            throw new Error("Sudah ada permintaan ekstensi yang menunggu, selesaikan dulu");
        }

        // Cek apakah provider punya order aktif di hari berikutnya (H+1, H+2, dst)
        const futureOrder = await prisma.orders.findFirst({
            where: {
                provider_id: profile.id,
                work_date: { gt: getTodayWitaDate() },
                status: { notIn: ['completed', 'cancelled', 'rejected'] },
                NOT: { id: orderId }
            }
        });
        if (futureOrder) {
            throw new Error(
                "Anda memiliki orderan untuk hari berikutnya. Tidak bisa mengajukan tambahan waktu. " +
                "Selesaikan order hari ini dan buat order baru nanti."
            );
        }

        // Fee: 2% per hari ekstensi, max 5% total
        const platformFeeRate = Math.min(totalRequestedDays * 2, 5);
        const additionalCost = Number(order.total_price) * platformFeeRate / 100;

        const extension = await prisma.order_extensions.create({
            data: {
                order_id: orderId,
                provider_id: order.provider_profiles.id,
                customer_id: order.customer_id,
                requested_date: new Date(),
                additional_cost: additionalCost,
                platform_fee_rate: platformFeeRate,
                extension_count: extensionDays,
                status: 'pending_customer',
            }
        });

        // Notifikasi ke customer
        try {
            await NotificationService.sendToUser(
                order.profiles_customer.user_id,
                "Request Ekstensi Order",
                `Mitra meminta tambahan ${extensionDays} hari untuk order Anda`,
                { orderId, type: "EXTENSION_REQUEST" }
            );
        } catch (_) {}

        return extension;
    }

    async approveExtension(extensionId: string, status: 'approved' | 'rejected') {
        const ext = await prisma.order_extensions.findUnique({
            where: { id: extensionId },
            include: {
                orders: {
                    include: {
                        provider_profiles: { select: { user_id: true, id: true } },
                        profiles_customer: { select: { user_id: true } }
                    }
                }
            }
        });
        if (!ext) throw new Error("Extension tidak ditemukan");
        if (ext.status !== 'pending') {
            throw new Error(`Extension sudah ${ext.status}`);
        }

        if (status === 'approved' && ext.orders?.work_date) {
            const extDates: Date[] = [];
            for (let i = 1; i <= ext.extension_count; i++) {
                const d = new Date(ext.orders.work_date);
                d.setDate(d.getDate() + i);
                extDates.push(d);
            }

            const conflicts = await prisma.provider_schedules.findMany({
                where: {
                    provider_id: ext.orders.provider_id,
                    work_date: { in: extDates },
                    is_booked: true,
                    order_id: { not: ext.order_id },
                },
                select: { work_date: true }
            });

            if (conflicts.length > 0) {
                const dates = conflicts.map(c =>
                    c.work_date.toISOString().split('T')[0]
                ).join(', ');
                throw new Error(`Tidak dapat approve extension: tanggal ${dates} sudah dibooking oleh customer lain`);
            }
        }

        const updated = await prisma.order_extensions.update({
            where: { id: extensionId },
            data: { status }
        });

        if (status === 'approved') {
            // Update platform_fee di orders
            await prisma.orders.update({
                where: { id: ext.order_id },
                data: {
                    platform_fee: { increment: ext.additional_cost }
                }
            });

            // Buat schedule entry untuk hari ekstensi
            if (ext.orders?.work_date) {
                for (let i = 1; i <= ext.extension_count; i++) {
                    const extDate = new Date(ext.orders.work_date);
                    extDate.setDate(extDate.getDate() + i);
                    await prisma.provider_schedules.upsert({
                        where: {
                            provider_id_work_date: {
                                provider_id: ext.orders.provider_id,
                                work_date: extDate,
                            }
                        },
                        update: { is_booked: true, order_id: ext.order_id },
                        create: {
                            provider_id: ext.orders.provider_id,
                            work_date: extDate,
                            is_booked: true,
                            order_id: ext.order_id,
                        }
                    });
                }
            }
        }

        // Notifikasi provider
        try {
            const msg = status === 'approved'
                ? `Ekstensi ${ext.extension_count} hari disetujui`
                : "Ekstensi ditolak";
            await NotificationService.sendToUser(
                ext.orders.provider_profiles.user_id,
                msg,
                `Request ekstensi order ${ext.order_id} telah ${status}`,
                { orderId: ext.order_id, type: "EXTENSION_" + status.toUpperCase() }
            );
        } catch (_) {}

        return updated;
    }

    async respondToExtension(extensionId: string, userId: string, action: 'approved' | 'rejected', note?: string) {
        const ext = await prisma.order_extensions.findUnique({
            where: { id: extensionId },
            include: {
                orders: {
                    include: {
                        profiles_customer: { select: { user_id: true } },
                        provider_profiles: { select: { user_id: true } }
                    }
                }
            }
        });
        if (!ext) throw new Error("Extension tidak ditemukan");
        if (ext.status !== 'pending_customer') {
            throw new Error("Extension sudah direspon sebelumnya");
        }
        if (ext.orders.profiles_customer.user_id !== userId) {
            throw new Error("Anda bukan customer order ini");
        }

        if (action === 'rejected') {
            const updated = await prisma.order_extensions.update({
                where: { id: extensionId },
                data: { status: 'rejected', response_note: note || null }
            });
            try {
                await NotificationService.sendToUser(
                    ext.orders.provider_profiles.user_id,
                    "Ekstensi Ditolak",
                    `Customer menolak request ekstensi ${ext.extension_count} hari`,
                    { orderId: ext.order_id, type: "EXTENSION_REJECTED" }
                );
            } catch (_) {}
            return updated;
        }

        // Approved: create payment + status pending_payment
        await prisma.payments.create({
            data: {
                order_id: ext.order_id,
                method: 'extension',
                status: 'pending',
                amount: ext.additional_cost,
            }
        });

        const updated = await prisma.order_extensions.update({
            where: { id: extensionId },
            data: { status: 'pending_payment', response_note: note || null }
        });

        try {
            await NotificationService.sendToUser(
                ext.orders.provider_profiles.user_id,
                "Ekstensi Disetujui Customer",
                "Customer menyetujui ekstensi, menunggu pembayaran",
                { orderId: ext.order_id, type: "EXTENSION_APPROVED" }
            );
        } catch (_) {}

        // Notifikasi admin untuk konfirmasi payment
        try {
            const adminUsers = await prisma.users.findMany({
                where: { roles: { name: 'admin' } },
                select: { id: true }
            });
            for (const admin of adminUsers) {
                await NotificationService.sendToUser(
                    admin.id,
                    "Pembayaran Ekstensi",
                    `Customer telah menyetujui ekstensi. Konfirmasi pembayaran Rp ${Number(ext.additional_cost).toLocaleString('id-ID')}`,
                    { orderId: ext.order_id, type: "EXTENSION_PENDING_PAYMENT" }
                );
            }
        } catch (_) {}

        return updated;
    }

    async activateExtension(extensionId: string) {
        const ext = await prisma.order_extensions.findUnique({
            where: { id: extensionId },
            include: {
                orders: {
                    include: {
                        provider_profiles: { select: { user_id: true, id: true } },
                        profiles_customer: { select: { user_id: true } }
                    }
                }
            }
        });
        if (!ext) throw new Error("Extension tidak ditemukan");
        if (ext.status !== 'pending_payment') {
            throw new Error("Extension belum dalam status pembayaran");
        }

        const payment = await prisma.payments.findFirst({
            where: { order_id: ext.order_id, method: 'extension', status: 'pending' }
        });
        if (!payment) throw new Error("Pembayaran tidak ditemukan");

        await prisma.$transaction(async (tx) => {
            await tx.payments.update({
                where: { id: payment.id },
                data: { status: 'paid', paid_at: new Date() }
            });

            await tx.order_extensions.update({
                where: { id: extensionId },
                data: { status: 'active' }
            });

            // Hitung total hari ekstensi (semua yg sudah active + yg baru)
            const allActive = await tx.order_extensions.findMany({
                where: { order_id: ext.order_id, status: 'active' },
                select: { extension_count: true }
            });
            const totalDays = allActive.reduce((sum, e) => sum + e.extension_count, 0);
            const newEndDate = ext.orders.work_date
                ? new Date(ext.orders.work_date.getTime() + totalDays * 86400000)
                : null;

            await tx.orders.update({
                where: { id: ext.order_id },
                data: {
                    additional_fee: { increment: ext.additional_cost },
                    end_date: newEndDate,
                }
            });

            if (ext.orders?.work_date) {
                for (let i = 1; i <= ext.extension_count; i++) {
                    const extDate = new Date(ext.orders.work_date);
                    extDate.setDate(extDate.getDate() + i);
                    await tx.provider_schedules.upsert({
                        where: {
                            provider_id_work_date: {
                                provider_id: ext.orders.provider_id,
                                work_date: extDate,
                            }
                        },
                        update: { is_booked: true, order_id: ext.order_id },
                        create: {
                            provider_id: ext.orders.provider_id,
                            work_date: extDate,
                            is_booked: true,
                            order_id: ext.order_id,
                        }
                    });
                }
            }
        });

        try {
            await NotificationService.sendToUser(
                ext.orders.provider_profiles.user_id,
                "Ekstensi Aktif",
                `Ekstensi ${ext.extension_count} hari telah aktif`,
                { orderId: ext.order_id, type: "EXTENSION_ACTIVATED" }
            );
        } catch (_) {}
        try {
            await NotificationService.sendToUser(
                ext.orders.profiles_customer.user_id,
                "Ekstensi Aktif",
                `Penambahan ${ext.extension_count} hari telah aktif`,
                { orderId: ext.order_id, type: "EXTENSION_ACTIVATED" }
            );
        } catch (_) {}

        return { message: "Ekstensi berhasil diaktifkan" };
    }

    async confirmPaymentByAdmin(orderId: string) {
        const order = await prisma.orders.findUnique({
            where: { id: orderId },
            include: {
                provider_profiles: { select: { user_id: true, id: true } },
                profiles_customer: { select: { user_id: true } }
            }
        });
        if (!order) throw new Error("Order tidak ditemukan");
        if (order.status !== 'pending_payment') {
            throw new Error(`Order dengan status ${order.status} tidak dapat dikonfirmasi pembayarannya`);
        }

        await prisma.$transaction(async (tx) => {
            await tx.orders.update({
                where: { id: orderId },
                data: { status: 'pending', start_date: new Date() }
            });

            await tx.payments.updateMany({
                where: { order_id: orderId },
                data: { status: 'paid', paid_at: new Date() }
            });

            // Buat jadwal provider untuk tanggal kerja (skip untuk custom task)
            if (order.work_date && order.assignment_type !== 'custom_task') {
                await tx.provider_schedules.upsert({
                    where: {
                        provider_id_work_date: {
                            provider_id: order.provider_profiles.id,
                            work_date: order.work_date,
                        }
                    },
                    update: { is_booked: true, order_id: orderId },
                    create: {
                        provider_id: order.provider_profiles.id,
                        work_date: order.work_date,
                        is_booked: true,
                        order_id: orderId,
                    }
                });
            }
        });

        try {
            await NotificationService.sendToUser(
                order.provider_profiles.user_id,
                "Pesanan Baru Masuk!",
                "Pembayaran telah dikonfirmasi. Ada pesanan baru untuk Anda!",
                { orderId: order.id, type: "NEW_ORDER" }
            );
        } catch (_) {}

        try {
            await NotificationService.sendToUser(
                order.profiles_customer.user_id,
                "Pembayaran Dikonfirmasi",
                "Pembayaran Anda telah dikonfirmasi. Pesanan sedang diproses!",
                { orderId: order.id, type: "PAYMENT_CONFIRMED" }
            );
        } catch (_) {}

        return { message: "Pembayaran berhasil dikonfirmasi, pesanan sekarang pending" };
    }
}