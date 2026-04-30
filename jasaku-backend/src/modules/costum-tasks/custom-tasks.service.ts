// src/modules/custom-tasks/custom-tasks.service.ts
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
    // Cek task masih open
    const task = await prisma.custom_tasks.findUnique({ where: { id: taskId } });
    if (!task || task.status !== 'open') throw new Error('Task tidak tersedia');

    // Cek provider sudah verified
    const profile = await prisma.provider_profiles.findUnique({
      where: { user_id: providerId }
    });
    if (!profile?.is_verified) throw new Error('Akun Anda belum terverifikasi');

    return prisma.custom_task_offers.create({
      data: { task_id: taskId, provider_id: providerId, ...payload, status: 'pending' }
    });
  }

  async acceptOffer(customerId: string, offerId: string) {
    return prisma.$transaction(async (tx) => {
      const offer = await tx.custom_task_offers.findUnique({
        where: { id: offerId },
        include: { custom_tasks: true }
      });
      if (!offer || offer.custom_tasks.customer_id !== customerId) {
        throw new Error('Tidak bisa menerima offer ini');
      }

      // Tandai offer terpilih, tolak yang lain
      await tx.custom_task_offers.update({
        where: { id: offerId },
        data: { status: 'accepted' }
      });
      await tx.custom_task_offers.updateMany({
        where: { task_id: offer.task_id, id: { not: offerId } },
        data: { status: 'rejected' }
      });

      // Tutup task
      await tx.custom_tasks.update({
        where: { id: offer.task_id },
        data: { status: 'assigned' }
      });

      // Buat order dari offer terpilih
      return tx.orders.create({
        data: {
          customer_id: customerId,
          provider_id: offer.provider_id,
          custom_task_id: offer.task_id,
          total_price: offer.offered_price,
          status: 'pending'
        }
      });
    });
  }
}