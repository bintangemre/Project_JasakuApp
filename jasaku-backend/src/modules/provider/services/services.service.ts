import { prisma } from "../../../config/prisma";    


export class ProviderServicesService {
    // Helper untuk validasi logika bisnis harga (Reusable untuk Add & Update)
    private async validatePriceLogic(tx: any, serviceId: string, prices: { pricingUnitId: string; contractTypeId?: string }[]) {
        const service = await tx.services.findUnique({
            where: { id: serviceId },
        });
        if (!service) throw new Error('Layanan tidak ditemukan');

        // Ambil pricing units & contract types yang valid untuk layanan ini
        const allowedPricingUnits = await tx.service_pricing_units.findMany({
            where: { service_id: serviceId },
            include: { pricing_units: true }
        });
        const allowedPricingUnitIds = allowedPricingUnits.map((spu: any) => spu.pricing_unit_id);

        const allowedContractTypes = await tx.service_contract_types.findMany({
            where: { service_id: serviceId },
            include: { contract_types: true }
        });
        const allowedContractTypeIds = allowedContractTypes.map((sct: any) => sct.contract_type_id);

        for (const p of prices) {
            if (!allowedPricingUnitIds.includes(p.pricingUnitId)) {
                throw new Error(`Unit harga ${p.pricingUnitId} tidak tersedia untuk layanan ini`);
            }

            if (p.contractTypeId && !allowedContractTypeIds.includes(p.contractTypeId)) {
                throw new Error(`Tipe kontrak ${p.contractTypeId} tidak tersedia untuk layanan ini`);
            }
        }

        return { service };
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
            await this.validatePriceLogic(tx, serviceId, prices);

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

            // 4. Ambil unit info dari pricing_units
            const pricingUnitIds = prices.map(p => p.pricingUnitId);
            const pricingUnits = await tx.pricing_units.findMany({
                where: { id: { in: pricingUnitIds } }
            });
            const unitMap = new Map(pricingUnits.map((pu: any) => [pu.id, pu.unit]));

            // 5. Masukkan harga baru
            const newPrices = prices.map(p => ({
                provider_service_id: existingService.id,
                pricing_unit_id: p.pricingUnitId,
                contract_type_id: p.contractTypeId || null,
                price: p.price,
                price_with_material: p.priceWithMaterial || null,
                plus_material: p.plusMaterial || false,
                unit: unitMap.get(p.pricingUnitId) || null
            }));

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
