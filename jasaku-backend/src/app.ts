import express from 'express';
import cors from 'cors';
import authRoutes from './modules/auth/auth.routes';
import servicesRoutes from './modules/services/services.routes';
import providerServicesRoutes from './modules/provider/services/services.routes';
import locationsRoutes from './modules/locations/locations.routes';
import ordersRoutes from './modules/orders/orders.routes';
import dotenv from 'dotenv';
import swaggerUi from "swagger-ui-express";
import swaggerJsdoc from "swagger-jsdoc";
import swaggerSpec from "./config/swagger";

dotenv.config();
const app = express();


app.use("/api-docs", swaggerUi.serve, swaggerUi.setup(swaggerSpec));

app.use(cors({ origin: '*' }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/services', servicesRoutes);
app.use('/api/locations', locationsRoutes);
app.use('/api/orders', ordersRoutes);
app.use('/api/provider/services', providerServicesRoutes);

const PORT = process.env.PORT || 3000;
app.listen(Number(PORT), '0.0.0.0', () => {
  console.log(`============= JASAKU BACKEND =============`);
  console.log(`🚀 Server running on http://localhost:${PORT}`);
  console.log(`🌐 Accessible locally via network IP on port ${PORT}`);
  console.log(`==========================================`);
});

// Global error handler
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
  console.error(err.stack);
  res.status(err.status || 500).json({ success: false, message: err.message || 'Internal Server Error' });
});

export default app;