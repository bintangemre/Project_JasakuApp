// src/services/notification.service.ts
import admin from 'firebase-admin';
import {prisma} from '../../config/prisma';

export class NotificationService {
  /**
   * Mengirim Notifikasi Push ke Seluruh Perangkat Aktif Milik User
   */
  static async sendToUser(userId: string, title: string, body: string, dataPayload: Record<string, string> = {}) {
    // 1. Ambil semua token perangkat milik user tersebut
    const devices = await prisma.user_devices.findMany({
      where: { user_id: userId },
      select: { id: true, fcm_token: true }
    });

    if (devices.length === 0) return;

    const tokens = devices.map(d => d.fcm_token);
    
    const message: admin.messaging.MulticastMessage = {
      tokens: tokens,
      notification: { title, body },
      data: {
        ...dataPayload,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } }
    };

    // 2. Kirim pesan secara multicast
    const response = await admin.messaging().sendEachForMulticast(message);
    
    // 3. Bersihkan token mati/kadaluwarsa (Best Practice Clean-up)
    if (response.failureCount > 0) {
      const tokensToDelete: string[] = [];
      response.responses.forEach((resp: admin.messaging.SendResponse, idx: number) => {
        if (!resp.success && resp.error) {
          const code = resp.error.code;
          if (code === 'messaging/invalid-registration-token' || code === 'messaging/registration-token-not-registered') {
            tokensToDelete.push(tokens[idx]);
          }
        }
      });

      if (tokensToDelete.length > 0) {
        await prisma.user_devices.deleteMany({
          where: { fcm_token: { in: tokensToDelete } }
        });
      }
    }
  }
}