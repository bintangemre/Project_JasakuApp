import { Router, Request, Response } from 'express';
import {
  createTask,
  getAvailableTasks,
  getMyTasks,
  getMyAcceptedTasks,
  getTaskDetail,
  acceptTask,
  completeTask,
  cancelTask,
} from './custom-tasks.controller';
import { authenticate } from '../../middleware/auth.middleware';
import { isCustomer, isProvider, isAny } from '../../middleware/role.middleware';
import { validate } from '../../middleware/validate.middleware';
import { createCustomTaskSchema } from '../../middleware/schemas';

const router = Router();

// Utility: search lokasi via Photon (gratis, no key) — MUST be above /:taskId
router.get('/search-location', authenticate, async (req: Request, res: Response) => {
  try {
    const q = String(req.query.q || '');
    const lat = req.query.lat ? Number(req.query.lat) : undefined;
    const lng = req.query.lng ? Number(req.query.lng) : undefined;
    if (!q) return res.json({ success: true, data: [] });
    let url = `https://photon.komoot.io/api/?q=${encodeURIComponent(q)}&limit=5`;
    if (lat && lng) url += `&lat=${lat}&lon=${lng}`;
    const response = await fetch(url);
    const json = await response.json();
    const features = json.features || [];
    const results = features.map((f: any) => ({
      label: f.properties.name || '',
      address: [
        f.properties.name,
        f.properties.street,
        f.properties.housenumber,
        f.properties.city,
        f.properties.state,
      ].filter(Boolean).join(', '),
      lat: f.geometry?.coordinates?.[1],
      lng: f.geometry?.coordinates?.[0],
    }));
    return res.json({ success: true, data: results });
  } catch {
    return res.json({ success: true, data: [] });
  }
});

router.post('/', authenticate, isCustomer, validate(createCustomTaskSchema), createTask);
router.get('/available', authenticate, isProvider, getAvailableTasks);
router.get('/mine', authenticate, isCustomer, getMyTasks);
router.get('/my-accepted', authenticate, isProvider, getMyAcceptedTasks);
router.get('/:taskId', authenticate, getTaskDetail);
router.post('/:taskId/accept', authenticate, isProvider, acceptTask);
router.patch('/:taskId/complete', authenticate, isProvider, completeTask);
router.post('/:taskId/cancel', authenticate, isCustomer, cancelTask);

export default router;
