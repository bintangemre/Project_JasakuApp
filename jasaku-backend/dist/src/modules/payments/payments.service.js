import { prisma } from '../../config/prisma';
export class PaymentsService {
    // Fitur: pilihan motode pembayaran untuk pelanggan, bisa COD atau menggunakan dompet digital seperti OVO, GoPay, Dana, atau transfer bank. Fitur ini digunakan untuk memudahkan pelanggan dalam melakukan pembayaran sesuai dengan preferensi mereka.
    async getPaymentMethods() {
        return await prisma.customer_payment_methods.findMany({
            select: {
                id: true,
                name: true,
                description: true
            }
        });
    }
}
