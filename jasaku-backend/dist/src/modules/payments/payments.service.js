import { prisma } from '../../config/prisma';
export class PaymentsService {
    async getPaymentMethods() {
        const accounts = await prisma.admin_payment_accounts.findMany({
            where: { is_active: true },
            orderBy: { created_at: 'asc' }
        });
        return [
            { id: 'cod', type: 'COD', description: 'Bayar setelah selesai pekerjaan', icon: 'money' },
            ...accounts.map(a => ({
                id: a.type === 'bank' ? `transfer_${a.id}` : a.type === 'qris' ? `qris_${a.id}` : `ewallet_${a.id}`,
                type: a.type === 'bank' ? 'Transfer Bank' : a.type === 'qris' ? 'QRIS' : 'E-Wallet',
                description: `${a.provider_name} - ${a.account_name}`,
                account_name: a.account_name,
                account_number: a.account_number,
                provider_name: a.provider_name,
                qris_image_url: a.qris_image_url,
                icon: a.type === 'bank' ? 'account_balance' : a.type === 'qris' ? 'qr_code' : 'wallet',
            }))
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
    // Simpan metode pembayaran customer untuk transaksi berikutnya
    async saveCustomerPaymentMethod(userId, type, accountNumber, accountName, providerName) {
        return await prisma.customer_payment_methods.create({
            data: {
                user_id: userId,
                type,
                account_number: accountNumber,
                account_name: accountName,
                provider_name: providerName || null
            }
        });
    }
    async getCustomerPaymentMethods(userId) {
        return await prisma.customer_payment_methods.findMany({
            where: { user_id: userId }
        });
    }
}
