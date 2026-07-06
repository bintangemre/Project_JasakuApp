import { prisma } from "../../config/prisma";

// Menggunakan Interface untuk DTO (Data Transfer Object) yang lebih strict
interface GetProvidersDto {
    serviceId: string;
    lat: number;
    lng: number;
    radiusInMeters?: number;
    limit?: number;
    page?: number;
}

export class CategoriesService {
    // PERBAIKAN: Fungsi validasi hanya fokus pada validasi bisnis internal jika diperlukan
    // Untuk validasi auth dasar, sebaiknya sudah ditangani oleh HTTP Middleware

    // menampilkan semua kategori 
    async getAllCategories() {
        return prisma.categories.findMany({
            select: { id: true, name: true, icon_url: true } // Optimasi Performa: Ambil yang butuh saja
        });
    }

    // menampilkan kategori beserta layanan yang ada di dalamnya berdasarkan id kategori
    async getCategoriesById(id: string) {
        const category = await prisma.categories.findUnique({
            where: { id },
            include: {
                services: {
                    select: { id: true, name: true, description: true }
                },
            },
        });
        if (!category) throw new Error('Kategori tidak ditemukan');
        return category;
    }

    // menampilkan daftar provider beserta penawaran layanan dari provider berdasarkan layanan yang dipilih pelanggan dan meletakkan provider yang terdekat di paling atas berdasarkan lokasi pelanggan dan lokasi provider 
    async getProvidersByService(params: GetProvidersDto) {
        const { serviceId, lat, lng, radiusInMeters = 25000, limit = 10, page = 1 } = params;
        const offset = (page - 1) * limit;
        const providers = await prisma.$queryRaw`
            SELECT 
                u.id as provider_id,
                pp.full_name,
                pp.profile_photo,
                pl.address,
                ST_DistanceSphere(
                    pl.location, 
                    ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)
                ) as distance_meters,
                ps.description,
                MIN(psp.price) as min_price,
                pp.rating
            FROM provider_services ps
            JOIN users u ON ps.provider_id = u.id
            JOIN roles r ON u.role_id = r.id
            JOIN provider_profiles pp ON u.id = pp.user_id
            JOIN provider_locations pl ON u.id = pl.provider_id
            LEFT JOIN provider_service_prices psp ON psp.provider_service_id = ps.id
            WHERE ps.service_id = ${serviceId}::uuid
              AND r.name = 'provider'
            GROUP BY u.id, pp.id, pl.id, ps.id
            HAVING ST_DistanceSphere(pl.location, ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)) <= ${radiusInMeters}
            ORDER BY distance_meters ASC
            LIMIT ${limit} OFFSET ${offset}
        `;
        return providers;
    }

    async getProvidersByServiceWithoutDistance(serviceId: string) {
        const providerServices = await prisma.provider_services.findMany({
            where: { service_id: serviceId },
            include: {
                services: {
                    select: {
                        name: true,
                        description: true,
                    }
                },
                provider_service_prices: {
                    include: {
                        pricing_types: true
                    }
                }
            }
        });

        if (providerServices.length === 0) {
            return [];
        }

        const providerIds = providerServices.map((ps) => ps.provider_id);
        const users = await prisma.users.findMany({
            where: { id: { in: providerIds } },
            include: {
                provider_profiles: {
                    select: {
                        full_name: true,
                        profile_photo: true,
                        rating: true,
                        total_jobs: true,
                        total_reviews: true,
                        portfolios: true,
                        address: true,
                        domicile: true,
                        is_active: true,
                    }
                },
                provider_locations: {
                    select: {
                        address: true,
                    }
                }
            }
        });

        const locations = providerIds.length > 0
            ? await prisma.$queryRaw<Array<{ provider_id: string; lat: number; lng: number; address: string | null }>>`
                SELECT 
                    pl.provider_id,
                    ST_Y(pl.location::geometry) as lat,
                    ST_X(pl.location::geometry) as lng,
                    pl.address
                FROM provider_locations pl
                WHERE pl.provider_id = ANY(${providerIds}::uuid[])
              `
            : [];

        const locationByProviderId = Object.fromEntries(
            locations.map((loc) => [loc.provider_id, { lat: loc.lat, lng: loc.lng, address: loc.address }])
        );

        const userById = Object.fromEntries(users.map((user) => [user.id, user]));

        return providerServices.map((service) => {
            const user = userById[service.provider_id];
            const loc = locationByProviderId[service.provider_id];
            return {
                ...service,
                provider_profiles: user
                    ? [
                          {
                              provider_id: service.provider_id,
                              rating: user.provider_profiles?.rating ?? null,
                              total_jobs: user.provider_profiles?.total_jobs ?? null,
                              total_reviews: user.provider_profiles?.total_reviews ?? null,
                              portfolios: user.provider_profiles?.portfolios ?? [],
                              is_active: user.provider_profiles?.is_active ?? true,
                              users: {
                                  full_name: user.provider_profiles?.full_name ?? null,
                                  profile_photo: user.provider_profiles?.profile_photo ?? null,
                              },
                              provider_locations: loc
                                  ? [
                                        {
                                            address: loc.address,
                                            lat: loc.lat,
                                            lng: loc.lng,
                                        }
                                    ]
                                  : [],
                              provider_service_prices: service.provider_service_prices,
                          }
                      ]
                    : [],
                services: service.services,
            };
        });
    }

    // menampilkan daftar provider yang menawarkan layanan tertentu  
    // masih belum menampilkan provider beserta data lainnya seperti nama provider, alamat, dan jarak dari pelanggan ke provider
    async getServicePricingTypes(serviceId: string) {
        const service = await prisma.services.findUnique({
            where: { id: serviceId },
            select: {
                // `provider_profiles` is not a relation on `services` model in the Prisma schema.
                // Use `provider_services` (relation defined on `services`) to access provider-specific
                // offerings and related prices. If you need provider profile details, either add a
                // relation in the schema or query profiles separately (see suggestions below).
                provider_services: {
                    select: {
                        id: true,
                        provider_id: true,
                        description: true,
                        provider_service_prices: {
                            select: {
                                price: true,
                                pricing_types: true,
                            }
                        }
                    }
                },
                categories: {
                    select: {
                        pricing_types: true
                    }
                }
            }
        });
        if (!service) throw new Error('Layanan tidak ditemukan');
        return service.categories?.pricing_types ?? [];
    }

    async getServiceOptions(providerId: string, serviceId: string) {
        // PERBAIKAN: Membatasi select data, menghindari deep nested join yang tidak perlu
        const options = await prisma.provider_services.findFirst({
            where: { provider_id: providerId, service_id: serviceId },
            include: {
                provider_service_prices: {
                    include: { pricing_types: true }

                }
            }
        });
        if (!options) throw new Error('Opsi layanan provider tidak ditemukan');
        return options;

    } 
}