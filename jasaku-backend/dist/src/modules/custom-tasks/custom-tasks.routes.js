import { Router } from 'express';
import { createTask, getAvailableTasks, getMyTasks, getMyAcceptedTasks, getTaskDetail, acceptTask, completeTask, updateWorkStatus, getMyActiveTasks, republishTask, getPaymentDetail, uploadPaymentProof, cancelTask, deleteTask, getTaskTracking, } from './custom-tasks.controller';
import { authenticate } from '../../middleware/auth.middleware';
import { isCustomer, isProvider } from '../../middleware/role.middleware';
import { validate } from '../../middleware/validate.middleware';
import { createCustomTaskSchema } from '../../middleware/schemas';
import { upload } from '../../middleware/upload.middleware';
const router = Router();
// Utility: search lokasi via Photon (gratis, no key) — MUST be above /:taskId
router.get('/search-location', authenticate, async (req, res) => {
    try {
        const q = String(req.query.q || '');
        const lat = req.query.lat ? Number(req.query.lat) : undefined;
        const lng = req.query.lng ? Number(req.query.lng) : undefined;
        if (!q)
            return res.json({ success: true, data: [] });
        let url = `https://photon.komoot.io/api/?q=${encodeURIComponent(q)}&limit=5`;
        if (lat && lng)
            url += `&lat=${lat}&lon=${lng}`;
        const response = await fetch(url);
        const json = await response.json();
        const features = json.features || [];
        const results = features.map((f) => ({
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
    }
    catch {
        return res.json({ success: true, data: [] });
    }
});
router.post('/', authenticate, isCustomer, upload.array('images', 5), validate(createCustomTaskSchema), createTask);
router.get('/available', authenticate, isProvider, getAvailableTasks);
router.get('/mine', authenticate, isCustomer, getMyTasks);
router.get('/my-accepted', authenticate, isProvider, getMyAcceptedTasks);
router.get('/my-active', authenticate, isProvider, getMyActiveTasks);
router.get('/:taskId', authenticate, getTaskDetail);
router.post('/:taskId/accept', authenticate, isProvider, acceptTask);
router.patch('/:taskId/complete', authenticate, isProvider, completeTask);
router.patch('/:taskId/work-status', authenticate, isProvider, updateWorkStatus);
router.get('/:taskId/payment', authenticate, isCustomer, getPaymentDetail);
router.post('/:taskId/payment-proof', authenticate, isCustomer, upload.single('proof'), uploadPaymentProof);
router.post('/:taskId/republish', authenticate, isCustomer, republishTask);
router.post('/:taskId/cancel', authenticate, isCustomer, cancelTask);
router.get('/:taskId/tracking', authenticate, getTaskTracking);
router.delete('/:taskId', authenticate, isCustomer, deleteTask);
export default router;
