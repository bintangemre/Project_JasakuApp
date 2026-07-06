import { prisma } from '../../config/prisma';
import { NotificationService } from '../notifications/notifications.service';
export class CustomTasksService {
    async postTask(customerId, payload) {
        const task = await prisma.custom_tasks.create({
            data: {
                customer_id: customerId,
                title: payload.title,
                description: payload.description,
                budget: payload.budget,
                address: payload.address,
                deadline: payload.deadline ? new Date(payload.deadline) : null,
                status: 'open',
            }
        });
        await prisma.$executeRaw `
      UPDATE custom_tasks
      SET location = ST_SetSRID(ST_MakePoint(${payload.lng}, ${payload.lat}), 4326)
      WHERE id = ${task.id}::uuid
    `;
        try {
            const nearbyProviders = await prisma.$queryRaw `
        SELECT u.id as user_id
        FROM users u
        JOIN roles r ON u.role_id = r.id
        JOIN provider_profiles pp ON u.id = pp.user_id
        JOIN provider_locations pl ON u.id = pl.provider_id
        WHERE r.name = 'provider'
          AND pp.is_active = true
          AND pp.is_verified = true
          AND pp.custom_task_enabled = true
          AND ST_DWithin(
                pl.location,
                ST_SetSRID(ST_MakePoint(${payload.lng}, ${payload.lat}), 4326),
                20 / 111.3199
              )
        LIMIT 50
      `;
            for (const provider of nearbyProviders) {
                await NotificationService.sendToUser(provider.user_id, 'Task Baru Tersedia!', `Ada task "${payload.title}" baru di daerah Anda.`, { taskId: task.id, type: 'NEW_CUSTOM_TASK' });
            }
        }
        catch (_) { }
        return task;
    }
    async getAvailableTasks(lat, lng, radius) {
        if (lat && lng && radius) {
            return await prisma.$queryRaw `
        SELECT
          ct.id,
          ct.title,
          ct.description,
          ct.budget,
          ct.address,
          ct.deadline,
          ct.status,
          ct.created_at,
          ct.customer_id,
          pc.full_name as customer_name,
          ST_Y(ct.location::geometry) as lat,
          ST_X(ct.location::geometry) as lng,
          ST_DistanceSphere(
            ct.location,
            ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)
          ) as distance_meters
        FROM custom_tasks ct
        JOIN users u ON ct.customer_id = u.id
        JOIN profiles_customer pc ON u.id = pc.user_id
        WHERE ct.status = 'open'
          AND ct.location IS NOT NULL
          AND ST_DWithin(
                ct.location,
                ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326),
                ${radius} / 111.3199
              )
        ORDER BY distance_meters ASC
        LIMIT 50
      `;
        }
        return await prisma.$queryRaw `
      SELECT
        ct.id,
        ct.title,
        ct.description,
        ct.budget,
        ct.address,
        ct.deadline,
        ct.status,
        ct.created_at,
        ct.customer_id,
        pc.full_name as customer_name,
        ST_Y(ct.location::geometry) as lat,
        ST_X(ct.location::geometry) as lng,
        NULL as distance_meters
      FROM custom_tasks ct
      JOIN users u ON ct.customer_id = u.id
      JOIN profiles_customer pc ON u.id = pc.user_id
      WHERE ct.status = 'open'
      ORDER BY ct.created_at DESC
      LIMIT 50
    `;
    }
    async getMyTasks(customerId) {
        return await prisma.$queryRaw `
      SELECT
        ct.id,
        ct.title,
        ct.description,
        ct.budget,
        ct.address,
        ct.deadline,
        ct.status,
        ct.created_at,
        ct.customer_id,
        ST_Y(ct.location::geometry) as lat,
        ST_X(ct.location::geometry) as lng
      FROM custom_tasks ct
      WHERE ct.customer_id = ${customerId}::uuid
      ORDER BY ct.created_at DESC
      LIMIT 50
    `;
    }
    async acceptTask(providerId, taskId) {
        const task = await prisma.custom_tasks.findUnique({
            where: { id: taskId },
            include: {
                users: {
                    select: {
                        profiles_customer: { select: { id: true } }
                    }
                }
            }
        });
        if (!task)
            throw new Error('Task tidak ditemukan');
        if (task.status !== 'open' && task.status !== 'confirmed') {
            throw new Error('Task ini sudah tidak tersedia');
        }
        const providerProfile = await prisma.provider_profiles.findUnique({
            where: { user_id: providerId }
        });
        if (!providerProfile?.is_verified)
            throw new Error('Akun Anda belum terverifikasi');
        if (!providerProfile.custom_task_enabled)
            throw new Error('Fitur custom task belum diaktifkan');
        const customerProfileId = task.users?.profiles_customer?.id;
        if (!customerProfileId)
            throw new Error('Data customer tidak ditemukan');
        const order = await prisma.$transaction(async (tx) => {
            await tx.custom_tasks.update({
                where: { id: taskId },
                data: { status: 'assigned', provider_id: providerId }
            });
            const price = Number(task.budget) || 0;
            const order = await tx.orders.create({
                data: {
                    customer_id: customerProfileId,
                    provider_id: providerProfile.id,
                    total_price: price,
                    description: task.title,
                    work_date: task.deadline || new Date(),
                    status: 'pending_payment',
                    assignment_type: 'custom_task',
                    custom_task_id: taskId,
                }
            });
            return order;
        });
        try {
            await NotificationService.sendToUser(task.customer_id, 'Task Diterima Provider!', `Provider "${providerProfile.full_name}" telah menerima task "${task.title}". Silakan lakukan pembayaran.`, { taskId, orderId: order.id, type: 'TASK_ACCEPTED' });
        }
        catch (_) { }
        return order;
    }
    async getTaskDetail(taskId) {
        const task = await prisma.custom_tasks.findUnique({
            where: { id: taskId },
            include: {
                users: {
                    select: {
                        profiles_customer: { select: { full_name: true } }
                    }
                },
                orders: {
                    select: { id: true, status: true, total_price: true }
                }
            }
        });
        if (!task)
            return null;
        const location = await prisma.$queryRaw `
      SELECT ST_Y(location::geometry) as lat, ST_X(location::geometry) as lng
      FROM custom_tasks WHERE id = ${taskId}::uuid
    `;
        return { ...task, lat: location[0]?.lat, lng: location[0]?.lng };
    }
}
