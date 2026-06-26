import { prisma } from '../../config/prisma';
export class AdminService {
    async getDashboardMetrics() {
        const totalUsers = await prisma.users.count();
        const totalProviders = await prisma.provider_profiles.count();
        const totalServices = await prisma.services.count();
        const totalOrders = await prisma.orders.count();
        return {
            totalUsers,
            totalProviders,
            totalServices,
            totalOrders
        };
    }
}
