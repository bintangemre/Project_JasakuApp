import { prisma } from '../../config/prisma';

export class ReportsService {
  async createReport(
    reporterId: string,
    reporterRole: string,
    subject: string,
    description: string,
    orderId?: string,
    attachments?: string[]
  ) {
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

  async getMyReports(userId: string) {
    return await prisma.reports.findMany({
      where: { reporter_id: userId },
      orderBy: { created_at: 'desc' }
    });
  }
}
