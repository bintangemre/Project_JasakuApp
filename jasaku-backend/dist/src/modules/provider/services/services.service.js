import { prisma } from "../../../config/prisma";
export class ProviderServicesService {
    // Validasi bahwa user adalah provider yang login
    async validateProviderAccess(userId) {
        if (!userId) {
            throw new Error('Akses ditolak: User harus login terlebih dahulu');
        }
        const user = await prisma.users.findUnique({
            where: { id: userId },
            include: { roles: true }
        });
        if (!user || user.roles.name !== 'provider') {
            throw new Error('Akses ditolak: Hanya Provider yang dapat mengakses fitur ini');
        }
    }
    // Helper untuk validasi logika bisnis harga (Reusable untuk Add & Update)
    async validatePriceLogic(tx, serviceId, prices) {
        // 1. Ambil data layanan & kategorinya
        const service = await tx.services.findUnique({
            where: { id: serviceId },
            include: { categories: true } // Pastikan relasi di schema benar
        });
        if (!service)
            throw new Error('Layanan tidak ditemukan');
        // 2. Ambil semua master pricing types
        const masterPricingTypes = await tx.pricing_types.findMany();
        for (const p of prices) {
            const typeInfo = masterPricingTypes.find((t) => t.id === p.pricingTypeId);
            if (!typeInfo)
                throw new Error('Metode pengerjaan tidak valid');
            // Logika Khusus Plus Material (Hanya untuk Kelistrikan)
            if (typeInfo.name === 'plus_material') {
                if (service.categories.name !== 'Kelistrikan') {
                    throw new Error('Metode Plus Material (Paket Terima Beres) hanya tersedia untuk kategori Kelistrikan');
                }
            }
            // Kamu bisa menambah pengecekan kategori lain di sini jika diperlukan
        }
        return { service, masterPricingTypes };
    }
    // 
    async addProviderService(providerId, serviceId, description, prices) {
        await this.validateProviderAccess(providerId);
        return await prisma.$transaction(async (tx) => {
            // Validasi Logika Bisnis
            const { masterPricingTypes } = await this.validatePriceLogic(tx, serviceId, prices);
            const existingService = await tx.provider_services.findFirst({
                where: { provider_id: providerId, service_id: serviceId }
            });
            let providerServiceId;
            if (existingService) {
                providerServiceId = existingService.id;
            }
            else {
                const newService = await tx.provider_services.create({
                    data: {
                        provider_id: providerId,
                        service_id: serviceId,
                        description: description
                    }
                });
                providerServiceId = newService.id;
            }
            // Map data harga dengan unit otomatis dari pricing_types
            const priceData = prices.map(p => {
                const typeInfo = masterPricingTypes.find((t) => t.id === p.pricingTypeId);
                return {
                    provider_service_id: providerServiceId,
                    pricing_type_id: p.pricingTypeId,
                    price: p.price,
                    unit: typeInfo?.default_unit || null // Mengisi unit otomatis dari master data
                };
            });
            await tx.provider_service_prices.createMany({ data: priceData });
            return { message: "Layanan dan harga berhasil ditambahkan" };
        });
    }
    async getProviderServices(providerId) {
        await this.validateProviderAccess(providerId);
        return await prisma.provider_services.findMany({
            where: { provider_id: providerId },
            include: {
                services: true,
                provider_service_prices: {
                    include: {
                        pricing_types: true
                    }
                }
            }
        });
    }
    async updateProviderService(providerId, serviceId, description, prices) {
        await this.validateProviderAccess(providerId);
        return await prisma.$transaction(async (tx) => {
            // 1. Validasi Akses & Logika Bisnis
            const { masterPricingTypes } = await this.validatePriceLogic(tx, serviceId, prices);
            const existingService = await tx.provider_services.findFirst({
                where: { provider_id: providerId, service_id: serviceId }
            });
            if (!existingService) {
                throw new Error('Layanan tidak ditemukan atau Anda tidak memiliki akses');
            }
            // 2. Update deskripsi
            await tx.provider_services.update({
                where: { id: existingService.id },
                data: { description }
            });
            // 3. Hapus harga lama (Sync Strategy)
            await tx.provider_service_prices.deleteMany({
                where: { provider_service_id: existingService.id }
            });
            // 4. Masukkan harga baru dengan unit otomatis
            const newPrices = prices.map(p => {
                const typeInfo = masterPricingTypes.find((t) => t.id === p.pricingTypeId);
                return {
                    provider_service_id: existingService.id,
                    pricing_type_id: p.pricingTypeId,
                    price: p.price,
                    unit: typeInfo?.default_unit || null
                };
            });
            await tx.provider_service_prices.createMany({ data: newPrices });
            return { message: "Layanan berhasil diperbarui dengan penyesuaian unit otomatis" };
        });
    }
    // fitur: aktif dan non aktif atau siap kerja atau tidak siap kerja jika siap maka atifkan jika tidak siap maka non aktifkan fitur ini digunakan untuk menandai apakah provider siap menerima orderan atau tidak, jika tidak siap maka provider tidak akan muncul di pencarian pelanggan
    async setProviderAvailability(providerId, isAvailable) {
        await this.validateProviderAccess(providerId);
        return await prisma.provider_profiles.update({
            where: { provider_id: providerId },
            data: { is_available: isAvailable }
        });
    }
}
