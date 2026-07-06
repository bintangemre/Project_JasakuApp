import { initializeApp, applicationDefault, cert } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
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
            initializeApp({
                credential: cert(serviceAccount),
            });
        } else {
            initializeApp({
                credential: applicationDefault(),
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
    return getMessaging();
}
