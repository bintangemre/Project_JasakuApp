import { Response, NextFunction } from 'express';
import { AuthRequest } from './auth.middleware';

const checkRole = (...roles: string[]) => {
  return (req: AuthRequest, res: Response, next: NextFunction) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ success: false, message: 'Akses ditolak' });
    }
    next();
  };
};

export const isAdmin    = checkRole('admin');
export const isCustomer = checkRole('customer');
export const isProvider = checkRole('provider');
export const isAny      = checkRole('admin', 'customer', 'provider');