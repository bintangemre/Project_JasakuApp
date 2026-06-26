import { text } from "node:stream/consumers";
import { prisma } from "../../config/prisma";
import { NotificationService } from "../notifications/notifications.service";


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
        // OPTIMASI: Menggunakan ST_DWithin agar memanfaatkan indeks GiST pada database (Menghindari Full Table Scan)
        // FIX: Gunakan tabel `users` dengan role='provider', bukan tabel `providers` yang tidak ada
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
            JOIN provider_profiles pp ON u.id = pp.user_id
            JOIN provider_locations pl ON u.id = pl.provider_id
            JOIN provider_services ps ON u.id = ps.provider_id
            JOIN services s ON ps.service_id = s.id
            WHERE ps.service_id = ${serviceId}::uuid
              AND u.role = 'provider'
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
        // 1. VALIDASI LOGIKA (Fail-Fast Principle)
        if (data.quantity <= 0) {
            throw new Error("Kuantitas pesanan harus lebih dari 0");
        }

        const parsedDate = new Date(data.workDate);
        if (isNaN(parsedDate.getTime()) || parsedDate < new Date()) {
            throw new Error("Tanggal pekerjaan tidak valid atau tidak boleh di masa lalu");
        }

        // Jalankan transaksi ACID
        const order = await prisma.$transaction(async (tx) => {
            // 2. AMBIL HARGA ASLI & VERIFIKASI AKTIFNYA LAYANAN
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
                    provider_id: data.providerId,
                    status: {
                        in: ["accepted", "on_progress"]
                    }
                }
            });

            if (activeOrder) {
                throw new Error("Provider sedang menangani order aktif. Selesaikan order aktif terlebih dahulu.");
            }

            // 3. PEMBUATAN HEADER ORDER
            const order = await tx.orders.create({
                data: {
                    customer_id: data.customerId,
                    provider_id: data.providerId,
                    total_price: totalPrice,
                    description: data.description,
                    work_date: parsedDate,
                    status: 'pending',
                }
            });

            // 4. PEMBUATAN DETAIL ORDER ITEMS
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

            // 5. PENYIMPANAN LOKASI - FIX: Gunakan Prisma client, bukan raw SQL
            await tx.order_locations.create({
                data: {
                    order_id: order.id,
                    address: data.address,
                    location: {
                        type: "Point",
                        coordinates: [data.lng, data.lat]
                    }
                }
            });

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

        // Contoh integrasi di dalam OrdersService saat Customer membuat order baru
        // (Taruh di akhir fungsi setelah transaksi database sukses)
        await NotificationService.sendToUser(
            data.providerId,
            "Pesanan Baru Masuk!",
            `Customer membutuhkan layanan ${data.serviceId}. Cek detailnya sekarang!`,
            { orderId: order.id, type: "NEW_ORDER" }
        );

        return order;
    }


    async getOrderDetails(orderId: string) {
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
                        service: {
                            select: {
                                id: true,
                                name: true,
                                created_at: true
                            }
                        },
                        pricing_type: {
                            select: {
                                id: true,
                                name: true,
                                created_at: true
                            }
                        }
                    }
                },
                order_locations: {
                    select: {
                        address: true,
                        location: true,
                        created_at: true
                    }
                }
            }
        });
    }

    // untuk menampilkan pesanan di aplikasi customer
    async getCustomerOrders(customerId: string) {
    return await prisma.orders.findMany({
        where: {
            customer_id: customerId
        },
        orderBy: {
            created_at: "desc"
        },
        select: {
            id: true,
            work_date: true,
            status: true,
            total_price: true,
            description: true,
            provider_profiles: {
                select: {
                    id: true,
                    full_name: true
                }
            }
        }
    });
}

    // menampilkan orderan yang masuk ke provider, bisa ditampilkan di halaman dashboard provider, fitur ini digunakan untuk memudahkan provider dalam melihat orderan yang masuk dan memprosesnya dengan cepat
    async getProviderOrders(providerId: string) {
        return await prisma.orders.findMany({
            where: { provider_id: providerId },
            select: {
                id: true,
                total_price: true,
                description: true,
                work_date: true,
                status: true,
                profiles_customer: {
                    select: {
                        id: true,
                        full_name: true,
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
                        service: {
                            select: {
                                id: true,
                                name: true,
                                created_at: true
                            }
                        },
                        pricing_type: {
                            select: {
                                id: true,
                                name: true,
                                created_at: true
                            }
                        }
                    }
                },
                order_locations: {
                    select: {
                        address: true,
                        location: true,
                        created_at: true
                    }
                }
            },
            orderBy: { created_at: 'desc' }
        });
    }
   


    // menerima status yang masuk dari provider (diterima atau ditolak)
    // FIX: Tambah verifikasi bahwa provider yang update adalah pemilik order
    async receiveOrderStatus(providerId: string, orderId: string, status: 'accepted' | 'rejected') {
        // 1. Verifikasi bahwa order milik provider yang membuat request
        const order = await prisma.orders.findUnique({
            where: { id: orderId }
        });

        if (!order) {
            throw new Error("Order tidak ditemukan");
        }

        if (order.provider_id !== providerId) {
            throw new Error("Anda tidak berhak mengubah order ini");
        }

        if (status === "accepted") {
        const activeOrder = await prisma.orders.findFirst({
        where: {
            provider_id: providerId,
            status: {
                in: ["accepted", "on_progress"]
            },
            NOT: {
                id: orderId
            }
        }
    });

    if (activeOrder) {
        throw new Error(
            "Selesaikan pekerjaan aktif terlebih dahulu sebelum menerima order baru."
        );
    }
}
        // 2. Update status order
        return await prisma.orders.update({
            where: { id: orderId },
            data: { status }
        });
    }
}