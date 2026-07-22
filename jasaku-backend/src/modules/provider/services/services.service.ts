import { prisma } from "../../../config/prisma";    


export class ProviderServicesService {
    // Helper untuk validasi logika bisnis harga (Reusable untuk Add & Update)
    private async validatePriceLogic(tx: any, serviceId: string, prices: { pricingUnitId: string; contractTypeId?: string }[]) {
        // 1. Ambil data layanan & kategorinya
        const service = await tx.services.findUnique({
            where: { id: serviceId },
            include: { categories: true }
        });

        if (!service) throw new Error('Layanan tidak ditemukan');

        // 2. Ambil semua master pricing units
        const masterPricingUnits = await tx.pricing_units.findMany();

        for (const p of prices) {
            const unitInfo = masterPricingUnits.find((t: any) => t.id === p.pricingUnitId);
            if (!unitInfo) throw new Error('Unit harga tidak valid');

            // Validasi: jika ada contractTypeId, pastikan ada di contract_types
            if (p.contractTypeId) {
                const contractType = await tx.contract_types.findUnique({ where: { id: p.contractTypeId } });
                if (!contractType) throw new Error('Tipe kontrak tidak valid');
            }
        }

        return { service, masterPricingUnits };
    }
    
    async getProviderServices(userId: string) {
        const profile = await prisma.provider_profiles.findUnique({
            where: { user_id: userId }
        });
        if (!profile) throw new Error('Profile tidak ditemukan');

        return await prisma.provider_services.findMany({
            where: { provider_id: profile.id },
            include: {
                services: true,
                provider_service_prices: {
                    include: {
                        pricing_units: true,
                        contract_types: true
                    }
                }
            }
        });
    }

    async updateProviderService(userId: string, serviceId: string, description: string, prices: { pricingUnitId: string; contractTypeId?: string; price: number; priceWithMaterial?: number; plusMaterial?: boolean }[]) {
        const profile = await prisma.provider_profiles.findUnique({
            where: { user_id: userId }
        });
        if (!profile) throw new Error('Profile tidak ditemukan');

        return await prisma.$transaction(async (tx) => {
            // 1. Validasi Akses & Logika Bisnis
            const { masterPricingUnits } = await this.validatePriceLogic(tx, serviceId, prices);

            const existingService = await tx.provider_services.findFirst({
                where: { provider_id: profile.id, service_id: serviceId }
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
                const unitInfo = masterPricingUnits.find((t: any) => t.id === p.pricingUnitId);
                return {
                    provider_service_id: existingService.id,
                    pricing_unit_id: p.pricingUnitId,
                    contract_type_id: p.contractTypeId || null,
                    price: p.price,
                    price_with_material: p.priceWithMaterial || null,
                    plus_material: p.plusMaterial || false,
                    unit: unitInfo?.unit || null
                };
            });

            if (newPrices.length > 0) {
              await tx.provider_service_prices.createMany({ data: newPrices });
            }

            return { message: "Layanan berhasil diperbarui dengan penyesuaian unit otomatis" };
        });
    }

    // fitur: aktif dan non aktif atau siap kerja atau tidak siap kerja jika siap maka atifkan jika tidak siap maka non aktifkan fitur ini digunakan untuk menandai apakah provider siap menerima orderan atau tidak, jika tidak siap maka provider tidak akan muncul di pencarian pelanggan
    async setProviderAvailability(providerId: string, isActive: boolean) {
        return await prisma.provider_profiles.update({
            where: { user_id: providerId },
            data: { is_active: isActive }
        });
    }
}
