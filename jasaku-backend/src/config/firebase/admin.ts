import admin from 'firebase-admin';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';
import fs from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const serviceAccountPath = resolve(__dirname, 'service-account.json');

let initialized = false;

function initializeFirebase() {
    if (initialized) return;

    try {
        if (fs.existsSync(serviceAccountPath)) {
            const serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf-8'));
            admin.initializeApp({
                credential: admin.credential.cert(serviceAccount),
            });
        } else {
            admin.initializeApp({
                credential: admin.credential.applicationDefault(),
            });
        }
        initialized = true;
    } catch (error) {
        console.warn('Firebase Admin gagal diinisialisasi. Notifikasi push tidak akan berfungsi.');
        if (error instanceof Error) {
            console.warn(error.message);
        }
    }
}

export function getFirebaseMessaging() {
    initializeFirebase();
    if (!initialized) {
        throw new Error('Firebase Admin tidak tersedia');
    }
    return admin.messaging();
}
