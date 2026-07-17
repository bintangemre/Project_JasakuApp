import multer from 'multer';
import path from 'path';
const storage = multer.memoryStorage();
const fileFilter = (_req, file, cb) => {
    const allowed = ['.jpg', '.jpeg', '.png', '.pdf'];
    const ext = path.extname(file.originalname).toLowerCase();
    if (allowed.includes(ext)) {
        cb(null, true);
    }
    else {
        cb(new Error(`Tipe file tidak didukung: ${ext}. Hanya JPG, PNG, PDF yang diizinkan.`));
    }
};
export const upload = multer({
    storage,
    fileFilter,
    limits: { fileSize: 10 * 1024 * 1024 },
});
