import { ZodError } from 'zod';
export const validate = (schema) => {
    return (req, res, next) => {
        try {
            req.body = schema.parse(req.body);
            next();
        }
        catch (err) {
            if (err instanceof ZodError) {
                const issues = err.issues;
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
