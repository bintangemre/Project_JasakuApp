import { Response, NextFunction } from 'express';
import { ZodSchema, ZodError } from 'zod';
import { AuthRequest } from './auth.middleware';

export const validate = (schema: ZodSchema) => {
    return (req: AuthRequest, res: Response, next: NextFunction) => {
        try {
            schema.parse(req.body);
            next();
        } catch (err) {
            if (err instanceof ZodError) {
                const issues = JSON.parse(err.message) as Array<{ path: (string | number)[]; message: string }>;
                const messages = issues.map(e => `${e.path.join('.')}: ${e.message}`);
                return res.status(400).json({
                    success: false,
                    message: 'Validasi gagal',
                    errors: messages
                });
            }
            next(err);
        }
    };
};
