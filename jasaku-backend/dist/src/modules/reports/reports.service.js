import { prisma } from '../../config/prisma';
export class ReportsService {
    async createReport(reporterId, reporterRole, subject, description, orderId, attachments) {
        return await prisma.reports.create({
            data: {
                reporter_id: reporterId,
                reporter_role: reporterRole,
                subject,
                description,
                order_id: orderId || null,
                attachments: attachments || [],
                status: 'open',
            }
        });
    }
    async getMyReports(userId) {
        return await prisma.reports.findMany({
            where: { reporter_id: userId },
            orderBy: { created_at: 'desc' }
        });
    }
}
