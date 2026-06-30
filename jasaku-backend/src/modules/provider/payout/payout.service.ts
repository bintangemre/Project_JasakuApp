import {prisma} from '../../../config/prisma';

export class ProviderPayoutService {
    async getPayoutMethods(providerId: string) {
        return await prisma.provider_payout_methods.findMany({
            where: { provider_id: providerId },
            orderBy: { created_at: 'asc' }
        });
    }

    async createPayoutMethod(providerId: string, data: {
        type: string;
        provider_name: string;
        account_number: string;
        account_name: string;
    }) {
        return await prisma.provider_payout_methods.create({
            data: {
                provider_id: providerId,
                ...data
            }
        });
    }

    async updatePayoutMethod(id: string, providerId: string, data: {
        type?: string;
        provider_name?: string;
        account_number?: string;
        account_name?: string;
    }) {
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

    async deletePayoutMethod(id: string, providerId: string) {
        const existing = await prisma.provider_payout_methods.findUnique({
            where: { id }
        });
        if (!existing || existing.provider_id !== providerId) {
            throw new Error('Metode payout tidak ditemukan');
        }
        return await prisma.provider_payout_methods.delete({ where: { id } });
    }
}
