import { Prisma } from "../../generated/prisma/client";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { prisma } from "../../config/prisma";

export class OrdersService {
    // Validasi bahwa user adalah customer yang login
    private async validateCustomerAccess(userId: string) {
        if (!userId) {
            throw new Error('Akses ditolak: User harus login terlebih dahulu');
        }
    }

    private async validateProviderAndService(providerId: string, serviceId: string) {
        const provider = await prisma.provider_services.findUnique({ where: { id: providerId } });
        const service = await prisma.services.findUnique({ where: { id: serviceId } });

        if (!provider) {
            throw new Error('Provider tidak ditemukan');
        }
        if (!service) {
            throw new Error('Layanan tidak ditemukan');
        }
    }
    async findNearbyProviders(serviceId: string, customerLat: number, customerLng: number) {
    // Karena Prisma tidak mendukung fungsi jarak PostGIS secara native, 
    // kita gunakan query mentah (Raw Query)
    const providers = await prisma.$queryRaw`
        SELECT 
            p.id, 
            p.name, 
            s.name as service_name,
            pl.address,
            ST_Distance(
                pl.location, 
                ST_SetSRID(ST_MakePoint(${customerLng}, ${customerLat}), 4326)
            ) * 111319.9 as distance_meters
        FROM providers p
        JOIN provider_locations pl ON p.id = pl.provider_id
        JOIN provider_services ps ON p.id = ps.provider_id
        JOIN services s ON ps.service_id = s.id
        WHERE ps.service_id = ${serviceId}::uuid
        ORDER BY distance_meters ASC
        LIMIT 10
    `;
    return providers;
}


    async createOrder(data: {
        customerId: string,
        providerId: string,
        serviceId: string,
        pricingTypeId: string,
        quantity: number,
        description: string,
        workDate: string,
        address: string,
        lat?: number,
        lng?: number
    }) {
        return await prisma.$transaction(async (tx) => {
            // 1. Ambil harga asli dari provider_service_prices untuk keamanan
            // (Jangan percaya harga yang dikirim dari frontend/client)
            const providerService = await tx.provider_services.findFirst({
                where: { provider_id: data.providerId, service_id: data.serviceId },
                include: {
                    provider_service_prices: {
                        where: { pricing_type_id: data.pricingTypeId }
                    }
                }
            });

            if (!providerService || providerService.provider_service_prices.length === 0) {
                throw new Error("Metode pengerjaan tidak tersedia untuk provider ini");
            }

            const pricePerUnit = providerService.provider_service_prices[0].price;
            const totalPrice = Number(pricePerUnit) * data.quantity;

            // 2. Insert ke tabel Orders
            const order = await tx.orders.create({
                data: {
                    customer_id: data.customerId,
                    provider_id: data.providerId,
                    total_price: totalPrice,
                    description: data.description,
                    work_date: new Date(data.workDate),
                    status: 'pending',
                }
            });

            // 3. Insert ke tabel Order Items
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

            // 4. Insert ke tabel Order Locations
            // Catatan: Untuk koordinat 'location', karena menggunakan PostGIS (geometry), 
            // kita gunakan query mentah jika npx prisma db push tidak mendukungnya secara native
            await tx.$executeRaw`
                INSERT INTO order_locations (id, order_id, address, location)
                VALUES (uuid_generate_v4(), ${order.id}::uuid, ${data.address}, ST_SetSRID(ST_MakePoint(${data.lng || 0}, ${data.lat || 0}), 4326))
            `;

            return order;
        });
    }
}