# Push Notifications dari Admin

## Deskripsi

Dokumen ini mencantumkan seluruh push notification yang dikirim secara otomatis sebagai dampak dari aksi admin di panel. Notifikasi dikirim melalui Firebase Cloud Messaging (FCM) via `NotificationService.sendToUser()`.

## Tabel Notifikasi

| # | Notifikasi | Trigger (Aksi Admin) | Penerima | Tipe | Judul | Isi Pesan |
|---|---|---|---|---|---|---|
| 1 | Konfirmasi Pembayaran Order | Admin klik "Konfirmasi" di halaman Konfirmasi Bayar | Mitra (provider) | `NEW_ORDER` | Pesanan Baru | Pesanan baru menunggu Anda! |
| 2 | Pembayaran Dikonfirmasi | Admin klik "Konfirmasi" di halaman Konfirmasi Bayar | Customer | `PAYMENT_CONFIRMED` | Pembayaran Dikonfirmasi | Pembayaran pesanan Anda telah dikonfirmasi. Mitra akan segera mengerjakan. |
| 3 | Pencairan Dana Berhasil | Admin klik "Konfirmasi" di halaman Pencairan Dana | Mitra (provider) | `ORDER_PAYOUT_CONFIRMED` | Pencairan Dana Berhasil | Dana untuk pesanan telah dikirim ke rekening Anda. Terima kasih atas kerja kerasnya! |
| 4 | Mitra Diverifikasi | Admin klik "Terima" / "Setujui" di halaman Verifikasi Mitra | Mitra (provider) | `PROVIDER_VERIFIED` | Akun Terverifikasi | Selamat! Akun Mitra Anda telah diverifikasi. Silakan mulai menerima pesanan. |
| 5 | Mitra Ditolak | Admin klik "Tolak" di halaman Verifikasi Mitra | Mitra (provider) | `PROVIDER_REJECTED` | Akun Ditolak | Maaf, akun Mitra Anda ditolak. Silakan periksa detail di aplikasi. |
| 6 | Akun Diblokir | Admin klik "Blokir" di halaman Pelanggan | Customer | `ACCOUNT_BANNED` | Akun Diblokir | Akun Anda telah diblokir oleh admin. Hubungi CS untuk informasi lebih lanjut. |
| 7 | Akun Diaktifkan | Admin klik "Aktifkan" di halaman Pelanggan | Customer | `ACCOUNT_UNBANNED` | Akun Diaktifkan | Akun Anda telah diaktifkan kembali. Anda bisa login sekarang. |
| 8 | Laporan Ditanggapi | Admin klik "Kirim" di modal Tanggapi Laporan | Pelapor (customer/mitra) | `REPORT_RESPONDED` | Laporan [terselesaikan/ditutup] | Laporan "[subjek]" telah [terselesaikan/ditutup] oleh admin. Respon: [respon admin] |

## Mapping Aksi → Notifikasi

| Halaman Admin | Aksi | Notifikasi # |
|---|---|---|
| Konfirmasi Bayar | Konfirmasi order | #1 (ke mitra) + #2 (ke customer) |
| Pencairan Dana | Konfirmasi payout | #3 (ke mitra) |
| Verifikasi Mitra | Setujui mitra | #4 (ke mitra) |
| Verifikasi Mitra | Tolak mitra | #5 (ke mitra) |
| Pelanggan | Blokir pelanggan | #6 (ke customer) |
| Pelanggan | Aktifkan pelanggan | #7 (ke customer) |
| Laporan | Tanggapi laporan | #8 (ke pelapor) |

## Behavior Notifikasi

- Semua notifikasi dikirim secara **asynchronous** (fire-and-forget)
- Jika pengiriman gagal, error di-`catch(() => {})` — tidak mempengaruhi operasi utama
- Notifikasi menggunakan Firebase Admin SDK (`NotificationService.sendToUser()`)
- Service account Firebase harus tersedia di `jasaku-backend/src/config/firebase/service-account.json`
- Jika file service account tidak ada, notifikasi **diam-diam gagal** (tidak ada crash)

## Tipe Notifikasi yang Tidak Dikirim oleh Admin

Beberapa notifikasi dikirim oleh sistem otomatis (bukan dari aksi admin langsung):

| Tipe | Trigger | Keterangan |
|---|---|---|
| `ORDER_STATUS_CHANGED` | Mitra mengubah status order | Bukan dari admin |
| `EXTENSION_APPROVED` | Customer menyetujui ekstensi | Bukan dari admin |
| `CUSTOM_TASK_ASSIGNED` | Provider menerima custom task | Bukan dari admin |
| `NEW_REPORT` | Customer/mitra mengirim laporan | Notifikasi ke admin (in-app badge) |

## Status: (SUKSES)

Sistem push notification untuk aksi admin berfungsi dengan baik. 8 tipe notifikasi aktif. Error handling graceful (tidak crash jika FCM gagal).

**Lokasi kode:**
- Backend: `admin.service.ts` — `NotificationService.sendToUser()` dipanggil di:
  - Line 137-140: Verifikasi/Tolak mitra
  - Line 209-214: Ban user
  - Line 226-228: Unban user
  - Line 447-452: Tanggapi laporan
  - Line 597-603: Konfirmasi payout order
