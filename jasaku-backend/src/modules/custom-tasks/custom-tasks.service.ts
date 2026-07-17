import { prisma } from '../../config/prisma';
import { NotificationService } from '../notifications/notifications.service';
import { LocationService } from '../locations/locations.service';

interface LocationPoint {
  label?: string;
  address: string;
  lat: number;
  lng: number;
}

interface CreateTaskPayload {
  title: string;
  description?: string | null;
  budget_per_person: number;
  required_people: number;
  address?: string;
  location_detail?: string | null;
  publish_days?: number;
  lat: number;
  lng: number;
  locations: LocationPoint[];
}

export class CustomTasksService {
  private normalizeLocations(rows: any[]): any[] {
    return rows.map(row => ({
      ...row,
      task_locations: typeof row.task_locations === 'string'
        ? JSON.parse(row.task_locations)
        : (row.task_locations ?? [])
    }));
  }
  async createTask(userId: string, payload: CreateTaskPayload) {
    const { title, description, budget_per_person, required_people, address, location_detail, publish_days, lat, lng, locations } = payload;

    const publishDays = publish_days || 1;
    const now = new Date();
    const expiresAt = new Date(now.getTime() + publishDays * 24 * 60 * 60 * 1000);

    const task = await prisma.$transaction(async (tx) => {
      const task = await tx.custom_tasks.create({
        data: {
          customer_id: userId,
          title,
          description,
          budget_per_person,
          required_people,
          accepted_count: 0,
          platform_fee_rate: 5.00,
          address,
          location_detail,
          publish_days: publishDays,
          expires_at: expiresAt,
          status: 'open',
        }
      });

      if (lat != null && lng != null) {
        await tx.$executeRaw`
          UPDATE custom_tasks
          SET location = ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)
          WHERE id = ${task.id}::uuid
        `;
      }

      if (locations.length > 0) {
        for (let i = 0; i < locations.length; i++) {
          const loc = locations[i];
          await tx.$executeRaw`
            INSERT INTO task_locations (id, task_id, label, address, location, stop_order)
            VALUES (
              uuid_generate_v4(),
              ${task.id}::uuid,
              ${loc.label || null},
              ${loc.address},
              ST_SetSRID(ST_MakePoint(${loc.lng}, ${loc.lat}), 4326),
              ${i}
            )
          `;
        }
      }

      return task;
    });

    // Notifikasi ke provider yang task_available — fire & forget, jangan blocking response
    try {
      const nearProviders = await prisma.$queryRaw<Array<{ user_id: string }>>`
        SELECT u.id as user_id
        FROM users u
        JOIN provider_profiles pp ON u.id = pp.user_id
        JOIN provider_locations pl ON u.id = pl.provider_id
        WHERE pp.is_verified = true
          AND pp.is_active = true
          AND pp.task_available = true
          AND ST_DWithin(
                pl.location,
                ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326),
                20 / 111.3199
              )
        LIMIT 50
      `;

      Promise.allSettled(
        nearProviders.map(p =>
          NotificationService.sendToUser(
            p.user_id,
            'Task Baru!',
            `Ada task "${title}" baru, rebutan! Budget Rp ${Number(budget_per_person).toLocaleString('id-ID')}/orang`,
            { taskId: task.id, type: 'NEW_CUSTOM_TASK' }
          )
        )
      );
    } catch (_) {}

    return task;
  }

  async getAvailableTasks(lat?: number, lng?: number, radius?: number) {
    const now = new Date();
    now.setHours(now.getHours() + 8);

    if (lat && lng && radius) {
      const rows = await prisma.$queryRaw<any[]>`
        SELECT
          ct.id, ct.title, ct.description,
          ct.budget_per_person, ct.required_people, ct.accepted_count,
          ct.address, ct.location_detail, ct.publish_days, ct.expires_at,
          ct.status, ct.created_at,
          pc.full_name as customer_name,
          ST_Y(ct.location::geometry) as lat,
          ST_X(ct.location::geometry) as lng,
          ST_DistanceSphere(
            ct.location,
            ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326)
          ) as distance_meters,
          COALESCE(
            (SELECT json_agg(json_build_object(
              'id', tl.id, 'label', tl.label, 'address', tl.address,
              'lat', ST_Y(tl.location::geometry),
              'lng', ST_X(tl.location::geometry),
              'stop_order', tl.stop_order
            ) ORDER BY tl.stop_order)
            FROM task_locations tl WHERE tl.task_id = ct.id),
            '[]'::json
          ) as task_locations
        FROM custom_tasks ct
        JOIN users u ON ct.customer_id = u.id
        JOIN profiles_customer pc ON u.id = pc.user_id
        WHERE ct.status = 'open'
          AND ct.accepted_count < ct.required_people
          AND ct.location IS NOT NULL
          AND (ct.expires_at IS NULL OR ct.expires_at > NOW())
          AND ST_DWithin(
                ct.location,
                ST_SetSRID(ST_MakePoint(${lng}, ${lat}), 4326),
                ${radius} / 111.3199
              )
        ORDER BY distance_meters ASC
        LIMIT 50
      `;
      return this.normalizeLocations(rows);
    }

    const rows = await prisma.$queryRaw<any[]>`
      SELECT
        ct.id, ct.title, ct.description,
        ct.budget_per_person, ct.required_people, ct.accepted_count,
        ct.address, ct.location_detail, ct.publish_days, ct.expires_at,
        ct.status, ct.created_at,
        pc.full_name as customer_name,
        ST_Y(ct.location::geometry) as lat,
        ST_X(ct.location::geometry) as lng,
        NULL as distance_meters,
        COALESCE(
          (SELECT json_agg(json_build_object(
            'id', tl.id, 'label', tl.label, 'address', tl.address,
            'lat', ST_Y(tl.location::geometry),
            'lng', ST_X(tl.location::geometry),
            'stop_order', tl.stop_order
          ) ORDER BY tl.stop_order)
          FROM task_locations tl WHERE tl.task_id = ct.id),
          '[]'::json
        ) as task_locations
      FROM custom_tasks ct
      JOIN users u ON ct.customer_id = u.id
      JOIN profiles_customer pc ON u.id = pc.user_id
      WHERE ct.status = 'open'
        AND ct.accepted_count < ct.required_people
        AND (ct.expires_at IS NULL OR ct.expires_at > NOW())
      ORDER BY ct.created_at DESC
      LIMIT 50
    `;
    return this.normalizeLocations(rows);
  }

  async getMyTasks(customerId: string) {
    const rows = await prisma.$queryRaw<any[]>`
      SELECT
        ct.id, ct.title, ct.description,
        ct.budget_per_person, ct.required_people, ct.accepted_count,
        ct.platform_fee_rate, ct.address, ct.location_detail,
        ct.publish_days, ct.expires_at,
        ct.payment_proof, ct.payment_status,
        ct.status, ct.created_at,
        ST_Y(ct.location::geometry) as lat,
        ST_X(ct.location::geometry) as lng,
        (SELECT COUNT(*)::int FROM task_providers tp WHERE tp.task_id = ct.id AND tp.status = 'completed') as completed_count,
        (SELECT COUNT(*)::int FROM task_providers tp WHERE tp.task_id = ct.id) as total_providers,
        COALESCE(
          (SELECT json_agg(json_build_object(
            'id', tl.id, 'label', tl.label, 'address', tl.address,
            'lat', ST_Y(tl.location::geometry),
            'lng', ST_X(tl.location::geometry),
            'stop_order', tl.stop_order
          ) ORDER BY tl.stop_order)
          FROM task_locations tl WHERE tl.task_id = ct.id),
          '[]'::json
        ) as task_locations
      FROM custom_tasks ct
      WHERE ct.customer_id = ${customerId}::uuid
      ORDER BY ct.created_at DESC
      LIMIT 50
    `;
    return this.normalizeLocations(rows);
  }

  async getMyAcceptedTasks(providerUserId: string) {
    const profile = await prisma.provider_profiles.findUnique({
      where: { user_id: providerUserId },
      select: { id: true }
    });
    if (!profile) return [];

    const rows = await prisma.$queryRaw<any[]>`
      SELECT
        ct.id as task_id, ct.title, ct.description,
        ct.budget_per_person, ct.required_people, ct.accepted_count,
        ct.address, ct.status as task_status, ct.created_at,
        ct.payment_status,
        tp.id as tp_id, tp.status as tp_status, tp.accepted_at, tp.completed_at,
        tp.work_status,
        tp.payout_confirmed,
        pc.full_name as customer_name,
        ST_Y(ct.location::geometry) as lat,
        ST_X(ct.location::geometry) as lng,
        o.id as order_id, o.status as order_status, o.total_price, o.platform_fee,
        COALESCE(
          (SELECT json_agg(json_build_object(
            'id', tl.id, 'label', tl.label, 'address', tl.address,
            'lat', ST_Y(tl.location::geometry),
            'lng', ST_X(tl.location::geometry),
            'stop_order', tl.stop_order
          ) ORDER BY tl.stop_order)
          FROM task_locations tl WHERE tl.task_id = ct.id),
          '[]'::json
        ) as task_locations
      FROM task_providers tp
      JOIN custom_tasks ct ON tp.task_id = ct.id
      JOIN users u ON ct.customer_id = u.id
      JOIN profiles_customer pc ON u.id = pc.user_id
      LEFT JOIN orders o ON o.task_provider_id = tp.id
      WHERE tp.provider_id = ${profile.id}::uuid
      ORDER BY tp.accepted_at DESC
      LIMIT 50
    `;
    return this.normalizeLocations(rows);
  }

  async getMyActiveTasks(providerUserId: string) {
    const profile = await prisma.provider_profiles.findUnique({
      where: { user_id: providerUserId },
      select: { id: true }
    });
    if (!profile) return [];

    const rows = await prisma.$queryRaw<any[]>`
      SELECT
        ct.id as task_id, ct.title, ct.description,
        ct.budget_per_person, ct.required_people, ct.accepted_count,
        ct.address, ct.location_detail,
        ct.status as task_status, ct.created_at,
        ct.payment_status,
        tp.id as tp_id, tp.status as tp_status, tp.accepted_at, tp.completed_at,
        tp.work_status,
        tp.payout_confirmed,
        pc.full_name as customer_name,
        ST_Y(ct.location::geometry) as lat,
        ST_X(ct.location::geometry) as lng,
        o.id as order_id, o.status as order_status, o.total_price, o.platform_fee,
        COALESCE(
          (SELECT json_agg(json_build_object(
            'id', tl.id, 'label', tl.label, 'address', tl.address,
            'lat', ST_Y(tl.location::geometry),
            'lng', ST_X(tl.location::geometry),
            'stop_order', tl.stop_order
          ) ORDER BY tl.stop_order)
          FROM task_locations tl WHERE tl.task_id = ct.id),
          '[]'::json
        ) as task_locations
      FROM task_providers tp
      JOIN custom_tasks ct ON tp.task_id = ct.id
      JOIN users u ON ct.customer_id = u.id
      JOIN profiles_customer pc ON u.id = pc.user_id
      LEFT JOIN orders o ON o.task_provider_id = tp.id
      WHERE tp.provider_id = ${profile.id}::uuid
        AND ct.payment_status = 'paid'
        AND (tp.work_status IS NULL OR tp.work_status != 'completed')
      ORDER BY tp.accepted_at DESC
      LIMIT 20
    `;
    return this.normalizeLocations(rows);
  }

  async getTaskDetail(taskId: string) {
    const task = await prisma.custom_tasks.findUnique({
      where: { id: taskId },
      include: {
        users: {
          select: {
            profiles_customer: { select: { full_name: true, id: true } }
          }
        },
        task_locations: {
          orderBy: { stop_order: 'asc' },
          select: { id: true, label: true, address: true, stop_order: true }
        },
        task_providers: {
          include: {
            provider_profiles: { select: { id: true, full_name: true, profile_photo: true, rating: true } },
            orders: { select: { id: true, status: true, total_price: true } }
          }
        }
      }
    });
    if (!task) return null;

    const location = await prisma.$queryRaw<Array<{ lat: number; lng: number }>>`
      SELECT ST_Y(location::geometry) as lat, ST_X(location::geometry) as lng
      FROM custom_tasks WHERE id = ${taskId}::uuid
    `;

    const taskLocations = await prisma.$queryRaw<Array<{ id: string; lat: number; lng: number }>>`
      SELECT id, ST_Y(location::geometry) as lat, ST_X(location::geometry) as lng
      FROM task_locations WHERE task_id = ${taskId}::uuid
    `;

    const locMap = new Map(taskLocations.map(l => [l.id, { lat: l.lat, lng: l.lng }]));

    return {
      ...task,
      customer_name: task.users?.profiles_customer?.full_name ?? null,
      lat: location[0]?.lat,
      lng: location[0]?.lng,
      task_locations: task.task_locations.map(tl => ({
        ...tl,
        lat: locMap.get(tl.id)?.lat,
        lng: locMap.get(tl.id)?.lng,
      })),
    };
  }

  async acceptTask(providerUserId: string, taskId: string) {
    const profile = await prisma.provider_profiles.findUnique({
      where: { user_id: providerUserId },
      select: { id: true, full_name: true }
    });
    if (!profile) throw new Error('Profil provider tidak ditemukan');
    if (!profile.full_name) throw new Error('Lengkapi profil Anda terlebih dahulu');

    const task = await prisma.custom_tasks.findUnique({
      where: { id: taskId },
      select: {
        id: true, title: true, budget_per_person: true, required_people: true,
        accepted_count: true, status: true, customer_id: true, platform_fee_rate: true,
        users: { select: { profiles_customer: { select: { id: true } } } }
      }
    });
    if (!task) throw new Error('Task tidak ditemukan');
    if (task.status !== 'open') throw new Error('Task sudah tidak tersedia');
    if (task.accepted_count >= task.required_people) throw new Error('Kuota task sudah penuh');
    if (task.customer_id === providerUserId) throw new Error('Tidak bisa menerima task Anda sendiri');

    const customerProfileId = task.users?.profiles_customer?.id;
    if (!customerProfileId) throw new Error('Data customer tidak ditemukan');

    // Cek apakah provider sudah accept task ini
    const existing = await prisma.task_providers.findUnique({
      where: { task_id_provider_id: { task_id: taskId, provider_id: profile.id } }
    });
    if (existing) throw new Error('Anda sudah menerima task ini');

    // Hitung accepted_count baru
    const newAcceptedCount = task.accepted_count + 1;
    const isNowFull = newAcceptedCount >= task.required_people;

    // Atomic increment + insert
    const result = await prisma.$transaction(async (tx) => {
      const updated = await tx.custom_tasks.updateMany({
        where: {
          id: taskId,
          status: 'open',
          accepted_count: { lt: tx.custom_tasks.fields.required_people }
        },
        data: {
          accepted_count: { increment: 1 }
        }
      });

      if (updated.count === 0) throw new Error('Task sudah penuh atau tidak tersedia');

      // Hanya set in_progress jika task sudah penuh (single atau multi)
      if (isNowFull) {
        await tx.custom_tasks.update({
          where: { id: taskId },
          data: { status: 'in_progress' }
        });
      }

      const budgetPerPerson = Number(task.budget_per_person) || 0;
      const feeRate = Number(task.platform_fee_rate) || 5;
      const totalPrice = budgetPerPerson;
      const platformFee = Math.round(budgetPerPerson * feeRate / 100);
      const finalPrice = totalPrice + platformFee;

      const tp = await tx.task_providers.create({
        data: {
          task_id: taskId,
          provider_id: profile.id,
          status: 'accepted',
        }
      });

      const order = await tx.orders.create({
        data: {
          customer_id: customerProfileId,
          provider_id: profile.id,
          total_price: finalPrice,
          platform_fee: platformFee,
          description: task.title,
          work_date: new Date(),
          status: 'pending_payment',
          assignment_type: 'custom_task',
          custom_task_id: taskId,
          task_provider_id: tp.id,
        }
      });

      await tx.payments.create({
        data: {
          order_id: order.id,
          method: 'rekber',
          status: 'pending',
          amount: finalPrice,
        }
      });

      return { tp, order };
    });

    // Notifikasi customer — fire & forget
    NotificationService.sendToUser(
      task.customer_id,
      'Task Diterima Provider!',
      isNowFull
        ? `Semua provider telah menerima task "${task.title}". Lakukan pembayaran untuk memulai.`
        : `Provider "${profile.full_name}" telah menerima task "${task.title}". Menunggu provider lain.`,
      { taskId, orderId: result.order.id, providerName: profile.full_name, type: 'CUSTOM_TASK_ACCEPTED' }
    ).catch(() => {});

    // Jika sudah penuh, notifikasi semua provider lain — parallel, fire & forget
    if (isNowFull) {
      prisma.task_providers.findMany({
        where: { task_id: taskId },
        select: { provider_profiles: { select: { user_id: true } } }
      }).then(otherProviders => {
        Promise.allSettled(
          otherProviders.map(p =>
            NotificationService.sendToUser(
              p.provider_profiles.user_id,
              'Task Siap Dibayar!',
              `Task "${task.title}" sudah penuh! Customer akan segera melakukan pembayaran.`,
              { taskId, type: 'CUSTOM_TASK_FULL' }
            )
          )
        );
      }).catch(() => {});
    }

    return result.order;
  }

  async updateWorkStatus(providerUserId: string, taskId: string, workStatus: string) {
    const VALID_TRANSITIONS: Record<string, string[]> = {
      'on_the_way': ['arrived'],
      'arrived': ['in_progress'],
      'in_progress': ['completed'],
    };

    if (!['on_the_way', 'arrived', 'in_progress', 'completed'].includes(workStatus)) {
      throw new Error('Status kerja tidak valid');
    }

    const profile = await prisma.provider_profiles.findUnique({
      where: { user_id: providerUserId },
      select: { id: true }
    });
    if (!profile) throw new Error('Profil provider tidak ditemukan');

    const tp = await prisma.task_providers.findUnique({
      where: { task_id_provider_id: { task_id: taskId, provider_id: profile.id } },
      include: {
        custom_tasks: { select: { title: true, customer_id: true, required_people: true, payment_status: true } }
      }
    });
    if (!tp) throw new Error('Anda tidak terdaftar di task ini');
    if (tp.custom_tasks.payment_status !== 'paid') throw new Error('Pembayaran belum dikonfirmasi admin');
    if (tp.status === 'completed') throw new Error('Task ini sudah Anda selesaikan');

    if (workStatus === 'on_the_way') {
      // First transition — check current work_status is null
      if (tp.work_status != null) throw new Error('Anda sudah memulai perjalanan');
    } else {
      // Subsequent transitions — validate against current work_status
      const allowedNext = VALID_TRANSITIONS[tp.work_status ?? ''];
      if (!allowedNext?.includes(workStatus)) {
        throw new Error(`Tidak bisa transisi dari ${tp.work_status ?? 'menunggu'} ke ${workStatus}`);
      }
    }

    await prisma.$transaction([
      prisma.task_providers.update({
        where: { id: tp.id },
        data: { work_status: workStatus }
      }),
      prisma.orders.updateMany({
        where: { task_provider_id: tp.id },
        data: { status: workStatus }
      }),
    ]);

    // Jika completed, update status juga
    if (workStatus === 'completed') {
      await prisma.task_providers.update({
        where: { id: tp.id },
        data: { status: 'completed', completed_at: new Date() }
      });

      await prisma.provider_profiles.update({
        where: { id: profile.id },
        data: { total_jobs: { increment: 1 } }
      });

      const completedCount = await prisma.task_providers.count({
        where: { task_id: taskId, status: 'completed' }
      });
      if (completedCount >= (tp.custom_tasks.required_people ?? 1)) {
        await prisma.custom_tasks.update({
          where: { id: taskId },
          data: { status: 'completed' }
        });
      }
    }

    // Notifikasi customer — fire & forget
    const notifMap: Record<string, { title: string; body: string }> = {
      on_the_way: {
        title: 'Provider Menuju Lokasi',
        body: `Provider sedang dalam perjalanan menuju "${tp.custom_tasks.title}".`,
      },
      arrived: {
        title: 'Provider Tiba di Lokasi',
        body: `Provider telah tiba di lokasi untuk "${tp.custom_tasks.title}".`,
      },
      in_progress: {
        title: 'Task Sedang Dikerjakan',
        body: `Provider sedang mengerjakan "${tp.custom_tasks.title}".`,
      },
      completed: {
        title: 'Task Selesai!',
        body: `Provider telah menyelesaikan task "${tp.custom_tasks.title}". Admin akan memproses payout.`,
      },
    };
    const notif = notifMap[workStatus];
    if (notif) {
      NotificationService.sendToUser(
        tp.custom_tasks.customer_id,
        notif.title,
        notif.body,
        { taskId, tpId: tp.id, workStatus, type: 'CUSTOM_TASK_WORK_STATUS' }
      ).catch(() => {});
    }

    return { message: `Status kerja diubah ke ${workStatus}` };
  }

  async completeTask(providerUserId: string, taskId: string) {
    const profile = await prisma.provider_profiles.findUnique({
      where: { user_id: providerUserId },
      select: { id: true }
    });
    if (!profile) throw new Error('Profil provider tidak ditemukan');

    const tp = await prisma.task_providers.findUnique({
      where: { task_id_provider_id: { task_id: taskId, provider_id: profile.id } },
      include: {
        custom_tasks: { select: { title: true, customer_id: true, required_people: true } }
      }
    });
    if (!tp) throw new Error('Anda tidak terdaftar di task ini');
    if (tp.status === 'completed') throw new Error('Task ini sudah Anda selesaikan');

    await prisma.$transaction([
      prisma.task_providers.update({
        where: { id: tp.id },
        data: { status: 'completed', work_status: 'completed', completed_at: new Date() }
      }),
      prisma.orders.updateMany({
        where: { task_provider_id: tp.id },
        data: { status: 'completed' }
      }),
    ]);

    // Update provider stats
    await prisma.provider_profiles.update({
      where: { id: profile.id },
      data: { total_jobs: { increment: 1 } }
    });

    // Jika semua provider selesai, set custom_tasks.status = 'completed'
    const completedCount = await prisma.task_providers.count({
      where: { task_id: taskId, status: 'completed' }
    });
    if (completedCount >= (tp.custom_tasks.required_people ?? 1)) {
      await prisma.custom_tasks.update({
        where: { id: taskId },
        data: { status: 'completed' }
      });
    }

    // Notifikasi customer
    try {
      await NotificationService.sendToUser(
        tp.custom_tasks.customer_id,
        'Task Selesai!',
        `Provider telah menyelesaikan task "${tp.custom_tasks.title}". Admin akan memproses pembayaran.`,
        { taskId, tpId: tp.id, type: 'CUSTOM_TASK_COMPLETED' }
      );
    } catch (_) {}

    return { message: 'Task ditandai selesai. Menunggu konfirmasi pembayaran dari admin.' };
  }

  async republishTask(customerId: string, taskId: string) {
    const task = await prisma.custom_tasks.findUnique({
      where: { id: taskId },
      select: {
        id: true, customer_id: true, status: true, expires_at: true,
        publish_days: true, title: true,
      }
    });
    if (!task) throw new Error('Task tidak ditemukan');
    if (task.customer_id !== customerId) throw new Error('Anda tidak berhak mempublikasi ulang task ini');
    if (task.status !== 'open') throw new Error('Task sudah tidak bisa dipublikasi ulang');

    const acceptedCount = await prisma.task_providers.count({
      where: { task_id: taskId }
    });
    if (acceptedCount > 0) {
      throw new Error('Task sudah ada provider yang menerima. Tidak bisa publikasi ulang.');
    }

    const publishDays = task.publish_days || 1;
    const newExpiresAt = new Date(Date.now() + publishDays * 24 * 60 * 60 * 1000);

    await prisma.custom_tasks.update({
      where: { id: taskId },
      data: { expires_at: newExpiresAt }
    });

    try {
      await NotificationService.sendToUser(
        customerId,
        'Task Dipublikasi Ulang!',
        `Task "${task.title}" telah dipublikasi ulang dan tersedia untuk provider.`,
        { taskId, type: 'CUSTOM_TASK_REPUBLISHED' }
      );
    } catch (_) {}

    return { message: 'Task berhasil dipublikasi ulang', expires_at: newExpiresAt };
  }

  async deleteTask(customerId: string, taskId: string) {
    const task = await prisma.custom_tasks.findUnique({
      where: { id: taskId },
      select: { id: true, customer_id: true, status: true, title: true }
    });
    if (!task) throw new Error('Task tidak ditemukan');
    if (task.customer_id !== customerId) throw new Error('Anda tidak berhak menghapus task ini');
    if (task.status !== 'completed' && task.status !== 'fulfilled') {
      throw new Error('Hanya task yang sudah selesai yang bisa dihapus');
    }

    await prisma.$transaction(async (tx) => {
      const orders = await tx.orders.findMany({
        where: { task_provider: { task_id: taskId } },
        select: { id: true }
      });
      const orderIds = orders.map(o => o.id);

      if (orderIds.length > 0) {
        await tx.payments.deleteMany({ where: { order_id: { in: orderIds } } });
        await tx.orders.deleteMany({ where: { id: { in: orderIds } } });
      }

      await tx.task_providers.deleteMany({ where: { task_id: taskId } });
      await tx.custom_tasks.delete({ where: { id: taskId } });
    });

    return { message: 'Task berhasil dihapus' };
  }

  async cancelTask(customerId: string, taskId: string) {
    const task = await prisma.custom_tasks.findUnique({
      where: { id: taskId },
      select: { id: true, customer_id: true, status: true, title: true }
    });
    if (!task) throw new Error('Task tidak ditemukan');
    if (task.customer_id !== customerId) throw new Error('Anda tidak berhak membatalkan task ini');
    if (task.status !== 'open') throw new Error('Task sudah tidak bisa dibatalkan');

    const acceptedCount = await prisma.task_providers.count({
      where: { task_id: taskId }
    });
    if (acceptedCount > 0) {
      throw new Error('Task sudah ada provider yang menerima. Hubungi admin untuk pembatalan.');
    }

    await prisma.custom_tasks.update({
      where: { id: taskId },
      data: { status: 'cancelled' }
    });

    return { message: 'Task dibatalkan' };
  }

  async confirmTaskPayment(tpId: string) {
    const tp = await prisma.task_providers.findUnique({
      where: { id: tpId },
      include: {
        custom_tasks: { select: { title: true, customer_id: true } },
        orders: { where: { status: 'pending_payment' }, take: 1 },
        provider_profiles: { select: { full_name: true, user_id: true } },
      }
    });
    if (!tp) throw new Error('Task provider tidak ditemukan');
    const order = tp.orders[0];
    if (!order) throw new Error('Order tidak ditemukan');

    // Update order status
    await prisma.orders.update({
      where: { id: order.id },
      data: { status: 'accepted', start_date: new Date() }
    });

    // Update payment status
    await prisma.payments.updateMany({
      where: { order_id: order.id },
      data: { status: 'paid', paid_at: new Date() }
    });

    // Update custom_tasks.payment_status dan status
    await prisma.custom_tasks.update({
      where: { id: tp.task_id },
      data: { payment_status: 'paid', status: 'active' }
    });

    try {
      await NotificationService.sendToUser(
        tp.custom_tasks.customer_id,
        'Pembayaran Dikonfirmasi!',
        `Pembayaran task "${tp.custom_tasks.title}" telah dikonfirmasi. Provider siap bekerja!`,
        { tpId, type: 'CUSTOM_TASK_PAYMENT_CONFIRMED' }
      );
    } catch (_) {}

    try {
      await NotificationService.sendToUser(
        tp.provider_profiles.user_id,
        'Pembayaran Dikonfirmasi!',
        `Pembayaran untuk task "${tp.custom_tasks.title}" telah dikonfirmasi admin. Anda dapat mulai mengerjakan task!`,
        { tpId, type: 'CUSTOM_TASK_PAYMENT_CONFIRMED' }
      );
    } catch (_) {}

    return { message: 'Pembayaran dikonfirmasi. Provider dapat mulai mengerjakan task.' };
  }

  async confirmTaskPayout(tpId: string) {
    const tp = await prisma.task_providers.findUnique({
      where: { id: tpId },
      include: {
        custom_tasks: { select: { title: true, customer_id: true, budget_per_person: true, platform_fee_rate: true } },
        provider_profiles: { select: { full_name: true, user_id: true } },
      }
    });
    if (!tp) throw new Error('Task provider tidak ditemukan');
    if (tp.payout_confirmed) throw new Error('Pembayaran sudah dikonfirmasi sebelumnya');

    await prisma.task_providers.update({
      where: { id: tpId },
      data: { payout_confirmed: true, payout_at: new Date() }
    });

    // Cek apakah semua provider sudah completed & payout confirmed
    const allTp = await prisma.task_providers.findMany({
      where: { task_id: tp.task_id }
    });
    const allDone = allTp.every(t => t.status === 'completed' && t.payout_confirmed);
    if (allDone) {
      await prisma.custom_tasks.update({
        where: { id: tp.task_id },
        data: { status: 'fulfilled' }
      });
    }

    try {
      await NotificationService.sendToUser(
        tp.provider_profiles.user_id,
        'Pembayaran Dikirim!',
        `Pembayaran untuk task "${tp.custom_tasks.title}" sudah dikirim ke rekening Anda.`,
        { tpId, type: 'CUSTOM_TASK_PAYOUT_CONFIRMED' }
      );
    } catch (_) {}

    return { message: `Pembayaran untuk ${tp.provider_profiles.full_name} telah dikonfirmasi.` };
  }

  async getPaymentDetail(taskId: string, userId: string) {
    const task = await prisma.custom_tasks.findUnique({
      where: { id: taskId },
      select: {
        id: true, title: true, budget_per_person: true, required_people: true,
        accepted_count: true, platform_fee_rate: true, payment_proof: true,
        payment_status: true, customer_id: true, status: true,
      }
    });
    if (!task) throw new Error('Task tidak ditemukan');
    if (task.customer_id !== userId && task.status !== 'open') {
      throw new Error('Anda tidak berhak mengakses pembayaran task ini');
    }
    if (task.customer_id !== userId) {
      throw new Error('Anda tidak berhak mengakses pembayaran task ini');
    }
    if (task.accepted_count === 0) throw new Error('Belum ada provider yang menerima task ini');

    const [banks, ewallets, qris] = await Promise.all([
      prisma.admin_bank_accounts.findMany({ where: { is_active: true } }),
      prisma.admin_ewallet_accounts.findMany({ where: { is_active: true } }),
      prisma.admin_qris_accounts.findMany({ where: { is_active: true } }),
    ]);

    const budgetPerPerson = Number(task.budget_per_person);
    const feeRate = Number(task.platform_fee_rate);
    const feePerPerson = Math.round(budgetPerPerson * feeRate / 100);
    const total = (budgetPerPerson + feePerPerson) * task.accepted_count;

    return {
      task_id: task.id,
      title: task.title,
      accepted_count: task.accepted_count,
      required_people: task.required_people,
      budget_per_person: budgetPerPerson,
      fee_per_person: feePerPerson,
      total_amount: total,
      payment_status: task.payment_status,
      payment_proof: task.payment_proof,
      admin_accounts: [
        ...banks.map(a => ({ id: a.id, type: 'bank', account_name: a.account_name, account_number: a.account_number, provider_name: a.provider_name, qris_image_url: null })),
        ...ewallets.map(a => ({ id: a.id, type: 'ewallet', account_name: a.account_name, account_number: a.account_number, provider_name: a.provider_name, qris_image_url: null })),
        ...qris.map(a => ({ id: a.id, type: 'qris', account_name: null, account_number: null, provider_name: a.provider_name, qris_image_url: a.qris_image_url })),
      ],
    };
  }

  async uploadPaymentProof(taskId: string, userId: string, fileUrl: string) {
    const task = await prisma.custom_tasks.findUnique({
      where: { id: taskId },
      select: { id: true, customer_id: true, payment_status: true, title: true }
    });
    if (!task) throw new Error('Task tidak ditemukan');
    if (task.customer_id !== userId) throw new Error('Anda tidak berhak mengupload bukti pembayaran task ini');
    if (task.payment_status === 'paid') throw new Error('Pembayaran task ini sudah dikonfirmasi');

    await prisma.custom_tasks.update({
      where: { id: taskId },
      data: { payment_proof: fileUrl, payment_status: 'proof_uploaded' }
    });

    // Notifikasi admin
    try {
      const adminRole = await prisma.roles.findFirst({ where: { name: 'admin' } });
      if (adminRole) {
        const admins = await prisma.users.findMany({
          where: { role_id: adminRole.id, status: 'active' },
          select: { id: true }
        });
        for (const a of admins) {
          await NotificationService.sendToUser(
            a.id,
            'Bukti Pembayaran Masuk!',
            `Customer mengupload bukti bayar untuk task "${task.title}". Segera konfirmasi.`,
            { taskId, type: 'PAYMENT_PROOF_UPLOADED' }
          );
        }
      }
    } catch (_) {}

    return { message: 'Bukti pembayaran berhasil diupload. Menunggu konfirmasi admin.' };
  }

  async adminConfirmTaskPayment(taskId: string) {
    const task = await prisma.custom_tasks.findUnique({
      where: { id: taskId },
      select: { id: true, title: true, payment_status: true }
    });
    if (!task) throw new Error('Task tidak ditemukan');
    if (task.payment_status !== 'proof_uploaded' && task.payment_status !== 'unpaid') {
      throw new Error('Pembayaran task ini sudah dikonfirmasi');
    }

    const tps = await prisma.task_providers.findMany({
      where: { task_id: taskId },
      include: {
        orders: { where: { status: 'pending_payment' }, take: 1 },
        provider_profiles: { select: { user_id: true } }
      }
    });

    if (tps.length === 0) throw new Error('Tidak ada provider yang perlu dikonfirmasi pembayarannya');

    const now = new Date();

    for (const tp of tps) {
      const order = tp.orders[0];
      if (order) {
        await prisma.orders.update({
          where: { id: order.id },
          data: { status: 'accepted', start_date: now }
        });
        await prisma.payments.updateMany({
          where: { order_id: order.id },
          data: { status: 'paid', paid_at: now }
        });
      }
    }

    await prisma.custom_tasks.update({
      where: { id: taskId },
      data: { payment_status: 'paid', status: 'active' }
    });

    // Notifikasi semua provider — fire & forget
    const providerUserIds = tps.map(tp => tp.provider_profiles?.user_id).filter(Boolean);
    Promise.allSettled(
      providerUserIds.map(uid =>
        NotificationService.sendToUser(
          uid!,
          'Pembayaran Dikonfirmasi!',
          `Pembayaran task "${task.title}" telah dikonfirmasi. Kamu bisa mulai bekerja!`,
          { taskId, type: 'CUSTOM_TASK_PAYMENT_CONFIRMED' }
        )
      )
    );

    return { message: 'Pembayaran untuk seluruh provider dikonfirmasi. Provider dapat mulai bekerja.' };
  }

  async getPendingPaymentTasksByTask() {
    return await prisma.$queryRaw`
      SELECT
        ct.id as task_id, ct.title, ct.payment_proof, ct.payment_status,
        ct.budget_per_person, ct.required_people, ct.accepted_count,
        pc.full_name as customer_name,
        COUNT(tp.id)::int as provider_count,
        SUM(o.total_price) as total_amount,
        SUM(o.platform_fee) as total_fee
      FROM custom_tasks ct
      JOIN profiles_customer pc ON ct.customer_id = pc.user_id
      JOIN orders o ON o.custom_task_id = ct.id
      LEFT JOIN task_providers tp ON tp.task_id = ct.id
      WHERE ct.payment_status IN ('unpaid', 'proof_uploaded')
        AND ct.accepted_count > 0
      GROUP BY ct.id, pc.full_name
      ORDER BY ct.created_at DESC
    `;
  }

  async getPendingPaymentTasks() {
    return await prisma.$queryRaw`
      SELECT
        tp.id as tp_id,
        tp.accepted_at,
        ct.id as task_id, ct.title, ct.budget_per_person, ct.required_people, ct.payment_proof,
        pc.full_name as customer_name,
        pp.full_name as provider_name, pp.id as provider_profile_id,
        o.id as order_id, o.total_price, o.platform_fee, o.status as order_status,
        ppm.id as payout_method_id, ppm.type as payout_type,
        ppm.account_name, ppm.account_number, ppm.provider_name as bank_name
      FROM task_providers tp
      JOIN custom_tasks ct ON tp.task_id = ct.id
      JOIN provider_profiles pp ON tp.provider_id = pp.id
      JOIN users u ON ct.customer_id = u.id
      JOIN profiles_customer pc ON u.id = pc.user_id
      JOIN orders o ON o.task_provider_id = tp.id
      LEFT JOIN provider_payout_methods ppm ON pp.id = ppm.provider_id
      WHERE o.status IN ('pending_payment', 'accepted')
        AND ct.payment_status IN ('unpaid', 'proof_uploaded', 'paid')
      ORDER BY tp.accepted_at DESC
    `;
  }

  async getPendingPayoutTasks() {
    return await prisma.$queryRaw`
      SELECT
        tp.id as tp_id,
        tp.accepted_at, tp.completed_at,
        tp.payout_confirmed,
        ct.id as task_id, ct.title, ct.budget_per_person, ct.payment_proof,
        pp.full_name as provider_name,
        pc.full_name as customer_name,
        o.id as order_id, o.total_price, o.platform_fee,
        ppm.id as payout_method_id, ppm.type as payout_type,
        ppm.account_name, ppm.account_number, ppm.provider_name as bank_name
      FROM task_providers tp
      JOIN custom_tasks ct ON tp.task_id = ct.id
      JOIN provider_profiles pp ON tp.provider_id = pp.id
      JOIN users u ON ct.customer_id = u.id
      JOIN profiles_customer pc ON u.id = pc.user_id
      JOIN orders o ON o.task_provider_id = tp.id
      LEFT JOIN provider_payout_methods ppm ON pp.id = ppm.provider_id
      WHERE tp.status = 'completed'
        AND o.status = 'completed'
      ORDER BY tp.payout_confirmed ASC, tp.completed_at ASC
    `;
  }

  async getTaskTracking(taskId: string) {
    const task = await prisma.custom_tasks.findUnique({
      where: { id: taskId },
      select: {
        id: true,
        title: true,
        status: true,
        address: true,
      }
    });
    if (!task) return null;

    const location = await prisma.$queryRaw<Array<{ lat: number; lng: number }>>`
      SELECT ST_Y(location::geometry) as lat, ST_X(location::geometry) as lng
      FROM custom_tasks WHERE id = ${taskId}::uuid
    `;

    const acceptedProvider = await prisma.task_providers.findFirst({
      where: { task_id: taskId, status: 'accepted' },
      select: {
        provider_profiles: {
          select: { user_id: true, full_name: true }
        },
        orders: {
          select: { id: true, status: true }
        }
      }
    });

    let providerLocation = null;
    let providerName: string | null = null;
    let orderId: string | null = null;
    if (acceptedProvider?.provider_profiles) {
      providerName = acceptedProvider.provider_profiles.full_name;
      const locService = new LocationService();
      providerLocation = await locService.getProviderLocation(acceptedProvider.provider_profiles.user_id);
    }
    if (acceptedProvider?.orders && acceptedProvider.orders.length > 0) {
      orderId = acceptedProvider.orders[0].id;
    }

    const customerLocation = location.length > 0
      ? { lat: location[0].lat, lng: location[0].lng, address: task.address }
      : null;

    return {
      taskId: task.id,
      title: task.title,
      status: task.status,
      providerName,
      orderId,
      providerLocation: providerLocation
        ? { lat: providerLocation.lat, lng: providerLocation.lng, address: providerLocation.address }
        : null,
      customerLocation,
    };
  }
}
