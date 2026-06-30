import {Response} from 'express';
import {NotificationService} from './notifications.service';
import {prisma} from '../../config/prisma';
import {successResponse, errorResponse} from '../../utils/response';
import {AuthRequest} from '../../middleware/auth.middleware';

const sendNotificationToUser = async (req: any, res: Response) => {
  try {
    const {userId, title, body, dataPayload} = req.body;
    await NotificationService.sendToUser(userId, title, body, dataPayload);
    return successResponse(res, null, 'Notifikasi berhasil dikirim');
  }
    catch (err: any) {
        return errorResponse(res, err.message);
    }
};

const registerDevice = async (req: AuthRequest, res: Response) => {
  try {
    const userId = req.user?.userId;
    if (!userId) return errorResponse(res, 'Anda harus login terlebih dahulu', 401);

    const { fcmToken, deviceType, deviceName } = req.body;
    if (!fcmToken || !deviceType) {
      return errorResponse(res, 'fcmToken dan deviceType wajib diisi', 400);
    }

    // Upsert: update jika token sudah ada, insert jika belum
    const existing = await prisma.user_devices.findUnique({
      where: { fcm_token: fcmToken }
    });

    if (existing) {
      await prisma.user_devices.update({
        where: { id: existing.id },
        data: { device_name: deviceName || existing.device_name }
      });
    } else {
      await prisma.user_devices.create({
        data: {
          user_id: userId,
          fcm_token: fcmToken,
          device_type: deviceType,
          device_name: deviceName || null
        }
      });
    }

    return successResponse(res, null, 'Perangkat berhasil didaftarkan');
  } catch (err: any) {
    return errorResponse(res, err.message);
  }
};

export { sendNotificationToUser, registerDevice };
