import { prisma } from '../../config/prisma';
export class PaymentsService {
    async getPaymentMethods() {
        const [banks, ewallets, qris] = await Promise.all([
            prisma.admin_bank_accounts.findMany({ where: { is_active: true }, orderBy: { created_at: 'asc' } }),
            prisma.admin_ewallet_accounts.findMany({ where: { is_active: true }, orderBy: { created_at: 'asc' } }),
            prisma.admin_qris_accounts.findMany({ where: { is_active: true }, orderBy: { created_at: 'asc' } }),
        ]);
        return [
            ...banks.map(a => ({
                id: `transfer_${a.id}`,
                type: 'Transfer Bank',
                description: `${a.provider_name} - ${a.account_name}`,
                account_name: a.account_name,
                account_number: a.account_number,
                provider_name: a.provider_name,
                qris_image_url: null,
                icon: 'account_balance',
            })),
            ...ewallets.map(a => ({
                id: `ewallet_${a.id}`,
                type: 'E-Wallet',
                description: `${a.provider_name} - ${a.account_name}`,
                account_name: a.account_name,
                account_number: a.account_number,
                provider_name: a.provider_name,
                qris_image_url: null,
                icon: 'wallet',
            })),
            ...qris.map(a => ({
                id: `qris_${a.id}`,
                type: 'QRIS',
                description: a.provider_name,
                account_name: null,
                account_number: null,
                provider_name: a.provider_name,
                qris_image_url: a.qris_image_url,
                icon: 'qr_code',
            })),
        ];
    }
    async createPayment(orderId, method, amount) {
        return await prisma.payments.create({
            data: {
                order_id: orderId,
                method,
                amount,
                status: 'pending'
            }
        });
    }
    async updatePaymentStatus(paymentId, status) {
        const data = { status };
        if (status === 'paid')
            data.paid_at = new Date();
        return await prisma.payments.update({
            where: { id: paymentId },
            data
        });
    }
    async getPaymentByOrder(orderId) {
        return await prisma.payments.findFirst({
            where: { order_id: orderId }
        });
    }
}
