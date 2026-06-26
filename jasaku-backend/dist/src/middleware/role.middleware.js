const checkRole = (...roles) => {
    return (req, res, next) => {
        if (!req.user || !roles.includes(req.user.role)) {
            return res.status(403).json({ success: false, message: 'Akses ditolak' });
        }
        next();
    };
};
export const isAdmin = checkRole('admin');
export const isCustomer = checkRole('customer');
export const isProvider = checkRole('jasa');
export const isAny = checkRole('admin', 'customer', 'jasa');
