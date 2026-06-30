import { prisma } from '../../../config/prisma';
export class ProviderPayoutService {
    async getPayoutMethods(providerId) {
        return await prisma.provider_payout_methods.findMany({
            where: { provider_id: providerId },
            orderBy: { created_at: 'asc' }
        });
    }
    async createPayoutMethod(providerId, data) {
        return await prisma.provider_payout_methods.create({
            data: {
                provider_id: providerId,
                ...data
            }
        });
    }
    async updatePayoutMethod(id, providerId, data) {
        const existing = await prisma.provider_payout_methods.findUnique({
            where: { id }
        });
        if (!existing || existing.provider_id !== providerId) {
            throw new Error('Metode payout tidak ditemukan');
        }
        return await prisma.provider_payout_methods.update({
            where: { id },
            data
        });
    }
    async deletePayoutMethod(id, providerId) {
        const existing = await prisma.provider_payout_methods.findUnique({
            where: { id }
        });
        if (!existing || existing.provider_id !== providerId) {
            throw new Error('Metode payout tidak ditemukan');
        }
        return await prisma.provider_payout_methods.delete({ where: { id } });
    }
}
