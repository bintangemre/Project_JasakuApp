# Notifikasi

## Deskripsi

Sistem notifikasi customer mencakup halaman notifikasi in-app (untuk permintaan ekstensi waktu) dan push notification via Firebase Cloud Messaging (FCM). Notifikasi FCM dikirim saat ada perubahan status order, permintaan ekstensi, update custom task, dan aktivitas pembayaran.

## Flow

### 1. Inisialisasi FCM

1. Saat bootstrap → `FcmManager().initialize()`
2. Minta izin notifikasi dari user
3. Dapatkan FCM token perangkat
4. Register token ke backend: `POST /api/notifications/devices/register`
   ```json
   {
     "fcmToken": "token-fcm-device",
     "deviceType": "android"
   }
   ```
5. Re-register dilakukan di `CustomerShell.initState()` sebagai fallback

### 2. Push Notification (Foreground)

Ketika notifikasi diterima saat aplikasi aktif:

1. `FcmManager.onForegroundMessage` callback dipanggil
2. Berdasarkan `type` notifikasi:

| Type | Aksi |
|---|---|
| `EXTENSION_REQUEST` | SnackBar "Ada permintaan perpanjangan waktu baru" + tombol "Lihat" |
| `ORDER_ACCEPTED`, `ORDER_CANCELLED`, `ON_THE_WAY`, dll | Invalidate `customerHomeOrdersProvider` (refresh data) |
| `CUSTOM_TASK_ACCEPTED`, `CUSTOM_TASK_COMPLETED`, dll | Invalidate data custom task |

### 3. Push Notification (Tap/Background)

Ketika user mengetuk notifikasi:

1. `FcmManager.onNotificationTap` callback dipanggil
2. Berdasarkan `type`:

| Type | Navigasi |
|---|---|
| `NEW_CUSTOM_TASK`, `CUSTOM_TASK_*` | Buka `TaskDetailPage(taskId)` |
| `NEW_ORDER`, `ORDER_*`, `PAYMENT_*`, `EXTENSION_*` | Switch ke tab Pesanan (`_selectedIndex = 1`) |

### 4. Halaman Notifikasi In-App (CustomerNotificationsPage)

1. Akses dari ikon lonceng di header Beranda
2. Memuat pesanan aktif customer: `GET /api/orders/customer/orders`
3. Untuk setiap pesanan aktif → cek ekstensi: `GET /api/orders/orders/{orderId}/extensions`
4. Filter ekstensi dengan status `pending_customer`
5. Tampilkan daftar permintaan perpanjangan waktu

**Setiap kartu notifikasi menampilkan:**
- Ikon timer (oranye)
- "Permintaan Perpanjangan"
- Nama provider
- Tambahan hari
- Rincian biaya (harga provider + fee aplikasi = total)
- Tombol **"Tolak"** dan **"Setujui & Bayar"**

### 5. Respon Ekstensi

**Setujui:**
1. Tap **"Setujui & Bayar"** → `POST /api/orders/extensions/{extId}/respond` dengan `action: "approved"`
2. Ambil rekening admin: `GET /api/orders/payment-accounts`
3. Tampilkan dialog "Pilih Pembayaran" → pilih metode → lihat detail rekening
4. Customer transfer manual → hubungi admin

**Tolak:**
1. Tap **"Tolak"** → `POST /api/orders/extensions/{extId}/respond` dengan `action: "rejected"`
2. SnackBar "Ekstensi ditolak"

### 6. Unread Count Badge

- `unreadNotifProvider` (StateProvider<int>) melacak jumlah notifikasi belum dibaca
- Badge ditampilkan di tab Pesanan (bottom nav) dan ikon notifikasi (header Beranda)
- Count di-reset ke 0 saat tab Pesanan dibuka atau notifikasi diakses

## API Endpoints

| Endpoint | Method | Keterangan |
|---|---|---|
| `/api/notifications/devices/register` | POST | Register FCM token |
| `/api/orders/customer/orders` | GET | Ambil pesanan aktif (untuk cek ekstensi) |
| `/api/orders/orders/{orderId}/extensions` | GET | Daftar ekstensi per pesanan |
| `/api/orders/extensions/{extensionId}/respond` | POST | Respon ekstensi (approve/reject) |
| `/api/orders/payment-accounts` | GET | Rekening admin |

## Tipe Notifikasi FCM

| Type | Keterangan |
|---|---|
| `NEW_ORDER` | Pesanan baru diterima provider |
| `ORDER_ACCEPTED` | Pesanan diterima provider |
| `ORDER_REJECTED` | Pesanan ditolak provider |
| `ON_THE_WAY` | Provider dalam perjalanan |
| `ARRIVED` | Provider tiba di lokasi |
| `IN_PROGRESS` | Pekerjaan dimulai |
| `COMPLETED` | Pekerjaan selesai |
| `ORDER_CANCELLED` | Pesanan dibatalkan |
| `PAYMENT_SUCCESS` | Pembayaran berhasil |
| `PAYMENT_FAILED` | Pembayaran gagal |
| `PAYMENT_CONFIRMED` | Pembayaran dikonfirmasi admin |
| `EXTENSION_REQUEST` | Provider minta perpanjangan waktu |
| `EXTENSION_ACTIVATED` | Ekstensi diaktifkan |
| `EXTENSION_REJECTED` | Ekstensi ditolak |
| `CUSTOM_TASK_ACCEPTED` | Custom task diterima provider |
| `CUSTOM_TASK_COMPLETED` | Custom task selesai |
| `CUSTOM_TASK_WORK_STATUS` | Status pekerjaan custom task |
| `CUSTOM_TASK_REPUBLISHED` | Custom task dipublikasi ulang |
| `CUSTOM_TASK_PAYMENT_CONFIRMED` | Pembayaran custom task dikonfirmasi |

## Provider State Management

| Provider | Tipe | Keterangan |
|---|---|---|
| `unreadNotifProvider` | `StateProvider<int>` | Jumlah notifikasi belum dibaca |

## Screen Files

| Screen | Path |
|---|---|
| Notifikasi In-App | `features/customer/presentation/screens/customer_notifications_page.dart` |
| FCM Manager | `features/notifications/data/services/fcm_manager.dart` |
| Notification Provider | `features/notifications/presentation/providers/notification_provider.dart` |

## Status

**(SUKSES)** — Notifikasi FCM berfungsi untuk semua tipe event. Halaman notifikasi in-app menampilkan permintaan ekstensi dengan aksi approve/reject. Unread count badge ditampilkan di bottom nav dan header.
