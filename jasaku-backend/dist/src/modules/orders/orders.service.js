import { prisma } from "../../config/prisma";
import { NotificationService } from "../notifications/notifications.service";
import { LocationService } from "../locations/locations.service";
// State machine: status transisi yang valid
const VALID_TRANSITIONS = {
    pending: ['accepted', 'rejected', 'cancelled'],
    accepted: ['on_the_way', 'cancelled'],
    on_the_way: ['arrived', 'cancelled'],
    arrived: ['in_progress', 'cancelled'],
    in_progress: ['completed'],
    completed: [],
    rejected: [],
    cancelled: [],
};
export class OrdersService {
    async findNearbyProviders(serviceId, customerLat, customerLng, maxDistanceMeters = 50000) {
        return await prisma.$queryRaw `
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
    async createOrder(data) {
        if (data.quantity <= 0) {
            throw new Error("Kuantitas pesanan harus lebih dari 0");
        }
        const parsedDate = new Date(data.workDate);
        if (isNaN(parsedDate.getTime()) || parsedDate < new Date()) {
            throw new Error("Tanggal pekerjaan tidak valid atau tidak boleh di masa lalu");
        }
        // orders.customer_id → profiles_customer.id, orders.provider_id → provider_profiles.id
        const customerProfile = await prisma.profiles_customer.findUnique({
            where: { user_id: data.customerId }
        });
        if (!customerProfile)
            throw new Error("Profil customer tidak ditemukan");
        const providerProfile = await prisma.provider_profiles.findUnique({
            where: { user_id: data.providerId }
        });
        if (!providerProfile)
            throw new Error("Profil provider tidak ditemukan");
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
            const activeOrder = await tx.orders.findFirst({
                where: {
                    provider_id: providerProfile.id,
                    status: { in: ["accepted", "on_the_way", "arrived", "in_progress"] }
                }
            });
            if (activeOrder) {
                throw new Error("Provider sedang menangani order aktif. Selesaikan order aktif terlebih dahulu.");
            }
            const order = await tx.orders.create({
                data: {
                    customer_id: customerProfile.id,
                    provider_id: providerProfile.id,
                    total_price: totalPrice,
                    description: data.description,
                    work_date: parsedDate,
                    status: 'pending',
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
            await tx.$executeRaw `
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
        try {
            await NotificationService.sendToUser(data.providerId, "Pesanan Baru Masuk!", "Ada pesanan baru untuk Anda. Cek detailnya sekarang!", { orderId: order.id, type: "NEW_ORDER" });
        }
        catch (_) { }
        return order;
    }
    async getOrderDetails(orderId) {
        return await prisma.orders.findUnique({
            where: { id: orderId },
            select: {
                id: true,
                total_price: true,
                description: true,
                work_date: true,
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
    async getOrderTracking(orderId) {
        const order = await prisma.orders.findUnique({
            where: { id: orderId },
            select: {
                id: true,
                status: true,
                customer_id: true,
                provider_id: true,
                order_locations: {
                    select: { address: true }
                }
            }
        });
        if (!order)
            return null;
        const providerProfile = await prisma.provider_profiles.findUnique({
            where: { id: order.provider_id },
            select: { user_id: true, full_name: true }
        });
        if (!providerProfile)
            return null;
        const locationService = new LocationService();
        const providerLocation = await locationService.getProviderLocation(providerProfile.user_id);
        const orderLocation = await prisma.$queryRaw `
            SELECT 
                ST_Y(location::geometry) as lat,
                ST_X(location::geometry) as lng
            FROM order_locations
            WHERE order_id = ${orderId}::uuid
            LIMIT 1
        `;
        return {
            orderId: order.id,
            status: order.status,
            providerName: providerProfile.full_name,
            providerLocation: providerLocation
                ? { lat: providerLocation.lat, lng: providerLocation.lng, address: providerLocation.address, updatedAt: providerLocation.updated_at }
                : null,
            orderLocation: orderLocation.length > 0
                ? { lat: orderLocation[0].lat, lng: orderLocation[0].lng, address: order.order_locations[0]?.address }
                : null,
        };
    }
    async getCustomerOrders(userId) {
        const profile = await prisma.profiles_customer.findUnique({
            where: { user_id: userId },
            select: { id: true }
        });
        if (!profile)
            return [];
        return await prisma.orders.findMany({
            where: { customer_id: profile.id },
            orderBy: { created_at: "desc" },
            select: {
                id: true,
                work_date: true,
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
    async getProviderOrders(userId, statusFilter) {
        const profile = await prisma.provider_profiles.findUnique({
            where: { user_id: userId },
            select: { id: true }
        });
        if (!profile)
            return [];
        const whereClause = { provider_id: profile.id };
        if (statusFilter) {
            whereClause.status = statusFilter;
        }
        return await prisma.orders.findMany({
            where: whereClause,
            select: {
                id: true,
                total_price: true,
                description: true,
                work_date: true,
                status: true,
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
    }
    async getProviderRequests(userId) {
        const profile = await prisma.provider_profiles.findUnique({
            where: { user_id: userId },
            select: { id: true }
        });
        if (!profile)
            return [];
        const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
        const expiredOrders = await prisma.orders.findMany({
            where: {
                provider_id: profile.id,
                status: 'pending',
                created_at: { lt: fiveMinutesAgo }
            },
            select: {
                id: true,
                customer_id: true,
                profiles_customer: { select: { user_id: true } }
            }
        });
        for (const order of expiredOrders) {
            await prisma.orders.update({
                where: { id: order.id },
                data: { status: 'cancelled' }
            });
            try {
                await NotificationService.sendToUser(order.profiles_customer.user_id, "Pesanan Dibatalkan", "Pesanan dibatalkan karena tidak diterima dalam 5 menit.", { orderId: order.id, type: "ORDER_CANCELLED" });
            }
            catch (_) { }
        }
        return await prisma.orders.findMany({
            where: {
                provider_id: profile.id,
                status: 'pending',
                created_at: { gte: fiveMinutesAgo }
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
    }
    async receiveOrderStatus(userId, orderId, status) {
        const order = await prisma.orders.findUnique({
            where: { id: orderId }
        });
        if (!order)
            throw new Error("Order tidak ditemukan");
        // orders.provider_id → provider_profiles.id; userId → users.id
        const profile = await prisma.provider_profiles.findUnique({
            where: { user_id: userId },
            select: { id: true }
        });
        if (!profile || order.provider_id !== profile.id) {
            throw new Error("Anda tidak berhak mengubah order ini");
        }
        const current = order.status || 'pending';
        const allowed = VALID_TRANSITIONS[current] || [];
        if (!allowed.includes(status)) {
            throw new Error(`Status ${current} tidak bisa berubah ke ${status}`);
        }
        if (status === "accepted") {
            const activeOrder = await prisma.orders.findFirst({
                where: {
                    provider_id: profile.id,
                    status: { in: ["accepted", "on_the_way", "arrived", "in_progress"] },
                    NOT: { id: orderId }
                }
            });
            if (activeOrder)
                throw new Error("Selesaikan pekerjaan aktif terlebih dahulu.");
        }
        const updateData = { status };
        if (status === 'accepted') {
            updateData.start_date = new Date();
        }
        const updated = await prisma.orders.update({
            where: { id: orderId },
            data: updateData
        });
        // increment total_jobs saat order selesai
        if (status === 'completed') {
            await prisma.provider_profiles.update({
                where: { id: order.provider_id },
                data: { total_jobs: { increment: 1 } }
            });
        }
        // Notifikasi — order.customer_id = profiles_customer.id, need users.id
        try {
            const customerProfile = await prisma.profiles_customer.findUnique({
                where: { id: order.customer_id },
                select: { user_id: true }
            });
            const customerUserId = customerProfile?.user_id;
            if (customerUserId) {
                if (status === 'accepted') {
                    await NotificationService.sendToUser(customerUserId, "Pesanan Diterima", "Provider telah menerima pesanan Anda.", { orderId, type: "ORDER_ACCEPTED" });
                }
                else if (status === 'rejected') {
                    await NotificationService.sendToUser(customerUserId, "Pesanan Ditolak", "Maaf, provider menolak pesanan Anda.", { orderId, type: "ORDER_REJECTED" });
                }
                else if (status === 'on_the_way') {
                    await NotificationService.sendToUser(customerUserId, "Provider Berangkat", "Provider sedang menuju lokasi Anda.", { orderId, type: "ON_THE_WAY" });
                }
                else if (status === 'arrived') {
                    await NotificationService.sendToUser(customerUserId, "Provider Tiba", "Provider sudah sampai di lokasi.", { orderId, type: "ARRIVED" });
                }
                else if (status === 'in_progress') {
                    await NotificationService.sendToUser(customerUserId, "Pekerjaan Dimulai", "Provider mulai mengerjakan pesanan Anda.", { orderId, type: "IN_PROGRESS" });
                }
                else if (status === 'completed') {
                    await NotificationService.sendToUser(customerUserId, "Pekerjaan Selesai", "Pesanan Anda telah selesai. Silakan beri rating.", { orderId, type: "COMPLETED" });
                }
            }
        }
        catch (_) { }
        return updated;
    }
    async getTodayOrders(userId) {
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const tomorrow = new Date(today);
        tomorrow.setDate(tomorrow.getDate() + 1);
        const profile = await prisma.provider_profiles.findUnique({
            where: { user_id: userId },
            select: { id: true }
        });
        if (!profile)
            return [];
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
    async cancelOrder(userId, orderId) {
        const order = await prisma.orders.findUnique({ where: { id: orderId } });
        if (!order)
            throw new Error("Order tidak ditemukan");
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
        try {
            const providerProfile = await prisma.provider_profiles.findUnique({
                where: { id: order.provider_id },
                select: { user_id: true }
            });
            if (providerProfile) {
                await NotificationService.sendToUser(providerProfile.user_id, "Pesanan Dibatalkan", "Customer telah membatalkan pesanan.", { orderId, type: "ORDER_CANCELLED" });
            }
        }
        catch (_) { }
        return { message: "Order berhasil dibatalkan" };
    }
}
