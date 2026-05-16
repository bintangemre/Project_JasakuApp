import { prisma } from "../../config/prisma";

// Service untuk kategori dan layanan pada sudut pandang customer (hanya untuk user yang login)
export class CategoriesService {
    // Validasi bahwa user adalah customer yang login
    private validateCustomerAccess(userId: string) {
        if (!userId) {
            throw new Error('Akses ditolak: User harus login terlebih dahulu');
        }
    }

    //ini buat di tampilin di dashbord depan dari sisi customer
    async getallCategories(userId: string) {
        this.validateCustomerAccess(userId);
        const categories = await prisma.categories.findMany();
        return categories;
    }

    //ini ketika customer klik salah satu kategori, maka akan muncul layanan yang ada di dalam kategori tersebut
    async getCategoriesById(id: string, userId: string) {
        this.validateCustomerAccess(userId);
        const category = await prisma.categories.findUnique({
            where: { id },
            include: {
                services: true,
            },
        });
        if (!category) throw new Error('Kategori tidak ditemukan');
        return category;
    }

async getPricingTypesByCategoryId(categoryId: string, userId: string) {
    this.validateCustomerAccess(userId);
    const pricingTypes = await prisma.pricing_types.findMany({
        where: {
            category_id: categoryId,
        },
    });
    return pricingTypes;
}

async getServicePricingTypes(serviceId: string, userId: string) {
    this.validateCustomerAccess(userId);
    const service = await prisma.services.findUnique({
        where: { id: serviceId },
        include: {
            categories: {
                include: {
                    pricing_types: true,
                },
            },
        },
    });
    if (!service) throw new Error('Layanan tidak ditemukan');
    return service.categories?.pricing_types ?? [];
}

async getServiceOptions(providerId: string, serviceId: string) {
    return await prisma.provider_services.findFirst({
        where: { 
            provider_id: providerId, 
            service_id: serviceId 
        },
        include: {
            services: {
                include: {
                    categories: {
                        include: {
                            pricing_types: true,
                        },
                    },
                },
            },
            provider_service_prices: {
                include: {
                    pricing_types: true 
                }
            }
        }
    });
}

    // Tambahkan di CategoriesService
async getProvidersByService(serviceId: string, lat: number, lng: number) {
    const providers = await prisma.$queryRaw`
        SELECT 
            p.id as provider_id, 
            u.full_name,
            u.avatar_url,
            pl.address,
            ST_Distance(
                pl.location, 
                ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)
            ) * 111319.9 as distance_meters,
            ps.description,
            (SELECT MIN(price) FROM provider_service_prices WHERE provider_service_id = ps.id) as min_price
        FROM provider_services ps
        JOIN users u ON ps.provider_id = u.id
        JOIN provider_locations pl ON u.id = pl.provider_id
        WHERE ps.service_id = ${serviceId}::uuid
        ORDER BY distance_meters ASC
    `;
    return providers;
}
}


