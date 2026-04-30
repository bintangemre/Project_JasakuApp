import { prisma } from "../../config/prisma";

// Service untuk kategori dan layanan pada sudut pandang customer (hanya untuk user yang login)
export class CategoriesService {
    // Validasi bahwa user adalah customer yang login
    private validateCustomerAccess(userId: string) {
        if (!userId) {
            throw new Error('Akses ditolak: User harus login terlebih dahulu');
        }
    }

    async getallCategories(userId: string) {
        this.validateCustomerAccess(userId);
        const categories = await prisma.categories.findMany();
        return categories;
    }

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

    async getServicesByid(id: string, userId: string) {
        this.validateCustomerAccess(userId);
        const service = await prisma.services.findUnique({
            where: { id },
        });
        if (!service) throw new Error('Layanan tidak ditemukan');
        return service;
    }

    async getServicesByCategoryId(categoryId: string, userId: string) {
        this.validateCustomerAccess(userId);
        const services = await prisma.services.findMany({
            where: { category_id: categoryId },
        });
        return services;
    }
}



