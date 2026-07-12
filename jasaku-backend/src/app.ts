// @ts-ignore - BigInt serialization for JSON (pg driver returns BigInt for COUNT(*))
(BigInt.prototype as any).toJSON = function () { return Number(this); };

import express from 'express';
import cors from 'cors';
import authRoutes from './modules/auth/auth.routes';
import servicesRoutes from './modules/services/services.routes';
import providerServicesRoutes from './modules/provider/services/services.routes';
import providerProfileRoutes from './modules/provider/profile/profile.routes';
import locationsRoutes from './modules/locations/locations.routes';
import ordersRoutes from './modules/orders/orders.routes';
import notificationRoutes from './modules/notifications/notifications.routes';
import reviewsRoutes from './modules/reviews/reviews.routes';
import paymentsRoutes from './modules/payments/payments.routes';
import adminRoutes from './modules/admin/admin.routes';
import customerProfileRoutes from './modules/customer/profile/profile.routes';
import providerPayoutRoutes from './modules/provider/payout/payout.routes';
import customTasksRoutes from './modules/custom-tasks/custom-tasks.routes';
import reportsRoutes from './modules/reports/reports.routes';
import dotenv from 'dotenv';
import swaggerUi from "swagger-ui-express";
import swaggerJsdoc from "swagger-jsdoc";
import swaggerSpec from "./config/swagger";

dotenv.config();
const app = express();


app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerSpec));

app.get('/health', (_req, res) => res.send('OK'));

app.use(cors({ origin: '*' }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use('/admin', express.static('public/admin', { index: 'index.html' }));
app.get('/admin', (_req, res) => res.redirect('/admin/'));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/services', servicesRoutes);
app.use('/api/locations', locationsRoutes);
app.use('/api/orders', ordersRoutes);
app.use('/api/provider/services', providerServicesRoutes);
app.use('/api/provider', providerProfileRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api', reviewsRoutes);
app.use('/api', paymentsRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/custom-tasks', customTasksRoutes);
app.use('/api/customer', customerProfileRoutes);
app.use('/api/provider', providerPayoutRoutes);
app.use('/api/reports', reportsRoutes);

// Static files — landing page & APK downloads
app.use('/', express.static('public'));

// Periodic cleanup: hard-delete cancelled/rejected orders older than 2 minutes
const cleanupInterval = 60_000; // every 60s
setInterval(async () => {
  try {
    const { prisma } = await import('./config/prisma');
    const twoMinutesAgo = new Date(Date.now() - 2 * 60 * 1000);
    const result = await prisma.orders.deleteMany({
      where: {
        status: { in: ["cancelled", "rejected"] },
        created_at: { lt: twoMinutesAgo }
      }
    });
    if (result.count > 0) {
      console.log(`🧹 Cleaned up ${result.count} stale cancelled/rejected orders`);
    }
  } catch (err) {
    // silent
  }
}, cleanupInterval);

// Global error handler
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error('========== UNHANDLED ERROR ==========');
  console.error('URL:', req.method, req.originalUrl);
  console.error(err.stack || err);
  console.error('=====================================');
  res.status(err.status || 500).json({ success: false, message: err.message || 'Internal Server Error' });
});

const PORT = process.env.PORT || 3000;
app.listen(Number(PORT), '0.0.0.0', () => {
  console.log(`============= JASAKU BACKEND =============`);
  console.log(`🚀 Server running on http://localhost:${PORT}`);
  console.log(`🌐 Accessible locally via network IP on port ${PORT}`);
  console.log(`==========================================`);
});

export default app;