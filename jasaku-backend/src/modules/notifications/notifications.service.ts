import { prisma } from '../../config/prisma';
import { getFirebaseMessaging } from '../../config/firebase/admin';

export class NotificationService {
  static async sendToUser(userId: string, title: string, body: string, dataPayload: Record<string, string> = {}) {
    try {
      const devices = await prisma.user_devices.findMany({
        where: { user_id: userId },
        select: { id: true, fcm_token: true }
      });

      if (devices.length === 0) return;

      const tokens = devices.map(d => d.fcm_token);

      const messaging = getFirebaseMessaging();

      const message: any = {
        tokens: tokens,
        notification: { title, body },
        data: {
          ...dataPayload,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: { priority: 'high' },
        apns: { payload: { aps: { sound: 'default' } } }
      };

      const response = await messaging.sendEachForMulticast(message);

      if (response.failureCount > 0) {
        const tokensToDelete: string[] = [];
        response.responses.forEach((resp: any, idx: number) => {
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
    } catch (error) {
      console.warn('Gagal mengirim notifikasi:', error instanceof Error ? error.message : error);
    }
  }
}
