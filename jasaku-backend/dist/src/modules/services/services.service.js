import { prisma } from "../../config/prisma";
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
    async getCategoriesById(id) {
        const category = await prisma.categories.findUnique({
            where: { id },
            include: {
                services: {
                    select: { id: true, name: true, description: true }
                },
            },
        });
        if (!category)
            throw new Error('Kategori tidak ditemukan');
        return category;
    }
    // menampilkan daftar provider beserta penawaran layanan dari provider berdasarkan layanan yang dipilih pelanggan dan meletakkan provider yang terdekat di paling atas berdasarkan lokasi pelanggan dan lokasi provider 
    async getProvidersByService(params) {
        const { serviceId, lat, lng, radiusInMeters = 25000, limit = 10, page = 1 } = params;
        const offset = (page - 1) * limit;
        const providers = await prisma.$queryRaw `
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
              AND pp.verification_status = 'verified'
              AND pp.is_active = true
            GROUP BY u.id, pp.id, pl.id, ps.id
            HAVING ST_DistanceSphere(pl.location, ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)) <= ${radiusInMeters}
            ORDER BY distance_meters ASC
            LIMIT ${limit} OFFSET ${offset}
        `;
        return providers;
    }
    async getProvidersByServiceWithoutDistance(serviceId) {
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
        const profileIds = providerServices.map((ps) => ps.provider_id);
        const profiles = await prisma.provider_profiles.findMany({
            where: { id: { in: profileIds }, verification_status: 'verified' },
            select: {
                id: true,
                user_id: true,
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
        });
        const userIds = profiles.map(p => p.user_id);
        const locations = userIds.length > 0
            ? await prisma.$queryRaw `
                SELECT 
                    pl.provider_id,
                    ST_Y(pl.location::geometry) as lat,
                    ST_X(pl.location::geometry) as lng,
                    pl.address
                FROM provider_locations pl
                WHERE pl.provider_id = ANY(${userIds}::uuid[])
              `
            : [];
        const locationByUserId = Object.fromEntries(locations.map((loc) => [loc.provider_id, { lat: loc.lat, lng: loc.lng, address: loc.address }]));
        const profileById = Object.fromEntries(profiles.map(p => [p.id, p]));
        return providerServices.map((service) => {
            const profile = profileById[service.provider_id];
            const loc = profile ? locationByUserId[profile.user_id] : null;
            return {
                ...service,
                provider_profiles: profile
                    ? [
                        {
                            provider_id: service.provider_id,
                            rating: profile.rating ?? null,
                            total_jobs: profile.total_jobs ?? null,
                            total_reviews: profile.total_reviews ?? null,
                            portfolios: profile.portfolios ?? [],
                            is_active: profile.is_active ?? true,
                            users: {
                                full_name: profile.full_name ?? null,
                                profile_photo: profile.profile_photo ?? null,
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
    async getServicePricingTypes(serviceId) {
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
        if (!service)
            throw new Error('Layanan tidak ditemukan');
        return service.categories?.pricing_types ?? [];
    }
    async getServiceOptions(providerId, serviceId) {
        // PERBAIKAN: Membatasi select data, menghindari deep nested join yang tidak perlu
        const options = await prisma.provider_services.findFirst({
            where: { provider_id: providerId, service_id: serviceId },
            include: {
                provider_service_prices: {
                    include: { pricing_types: true }
                }
            }
        });
        if (!options)
            throw new Error('Opsi layanan provider tidak ditemukan');
        return options;
    }
    async searchServices(query) {
        const [categories, services] = await Promise.all([
            prisma.categories.findMany({
                where: { name: { contains: query, mode: 'insensitive' } },
                select: { id: true, name: true, icon_url: true }
            }),
            prisma.services.findMany({
                where: {
                    OR: [
                        { name: { contains: query, mode: 'insensitive' } },
                        { description: { contains: query, mode: 'insensitive' } },
                        { categories: { name: { contains: query, mode: 'insensitive' } } }
                    ]
                },
                select: {
                    id: true,
                    name: true,
                    description: true,
                    category_id: true,
                    categories: { select: { name: true } }
                },
                take: 20
            })
        ]);
        return { categories, services };
    }
}
