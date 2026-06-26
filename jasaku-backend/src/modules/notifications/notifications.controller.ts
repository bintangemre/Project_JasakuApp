import {Response} from 'express';
import {NotificationService} from './notifications.service';
import {successResponse, errorResponse} from '../../utils/response';

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

export { sendNotificationToUser };
