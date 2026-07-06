import { prisma } from '../../config/prisma';
export class PaymentsService {
    async getPaymentMethods() {
        const accounts = await prisma.admin_payment_accounts.findMany({
            where: { is_active: true },
            orderBy: { created_at: 'asc' }
        });
        return accounts.map(a => ({
            id: a.type === 'bank' ? `transfer_${a.id}` : a.type === 'qris' ? `qris_${a.id}` : `ewallet_${a.id}`,
            type: a.type === 'bank' ? 'Transfer Bank' : a.type === 'qris' ? 'QRIS' : 'E-Wallet',
            description: `${a.provider_name} - ${a.account_name}`,
            account_name: a.account_name,
            account_number: a.account_number,
            provider_name: a.provider_name,
            qris_image_url: a.qris_image_url,
            icon: a.type === 'bank' ? 'account_balance' : a.type === 'qris' ? 'qr_code' : 'wallet',
        }));
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
