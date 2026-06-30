import { prisma } from '../../config/prisma';

export class CustomTasksService {
  async postTask(customerId: string, payload: {
    title: string;
    description: string;
    budget_min: number;
    budget_max: number;
    location: string;
    deadline: Date;
  }) {
    return prisma.custom_tasks.create({
      data: { ...payload, customer_id: customerId, status: 'open' }
    });
  }

  async submitBid(providerId: string, taskId: string, payload: {
    offered_price: number;
    message: string;
    estimated_days: number;
  }) {
    const task = await prisma.custom_tasks.findUnique({ where: { id: taskId } });
    if (!task || task.status !== 'open') throw new Error('Task tidak tersedia');

    const profile = await prisma.provider_profiles.findUnique({
      where: { user_id: providerId }
    });
    if (!profile?.is_verified) throw new Error('Akun Anda belum terverifikasi');

    return prisma.custom_task_proposals.create({
      data: {
        task_id: taskId,
        provider_id: providerId,
        price: payload.offered_price,
        message: payload.message,
        status: 'pending'
      }
    });
  }

  async acceptOffer(customerId: string, offerId: string) {
    return prisma.$transaction(async (tx) => {
      const offer = await tx.custom_task_proposals.findUnique({
        where: { id: offerId },
        include: { custom_tasks: true }
      });
      if (!offer || offer.custom_tasks?.customer_id !== customerId) {
        throw new Error('Tidak bisa menerima offer ini');
      }

      await tx.custom_task_proposals.update({
        where: { id: offerId },
        data: { status: 'accepted' }
      });
      await tx.custom_task_proposals.updateMany({
        where: { task_id: offer.task_id, id: { not: offerId } },
        data: { status: 'rejected' }
      });

      await tx.custom_tasks.update({
        where: { id: offer.task_id! },
        data: { status: 'assigned' }
      });

      return tx.orders.create({
        data: {
          customer_id: customerId,
          provider_id: offer.provider_id!,
          total_price: offer.price,
          status: 'pending'
        }
      });
    });
  }
}
