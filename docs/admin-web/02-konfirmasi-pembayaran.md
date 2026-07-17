# Konfirmasi Pembayaran (Rekber)

## Deskripsi

Halaman ini adalah pusat operasional Rekber (Rekening Bersama). Admin mengonfirmasi bukti pembayaran dari customer sebelum pesanan diteruskan ke mitra. Halaman menampilkan seluruh order (bukan custom task) dengan berbagai filter dan fitur manajemen riwayat.

## Flow Lengkap

### Flow Transaksi Normal

```
Customer buka layanan → Pilih layanan → Pilih jadwal → Pilih metode bayar → Upload bukti bayar
    ↓
Order status: pending_payment
    ↓
Admin buka halaman Konfirmasi Bayar → Lihat daftar order pending_payment
    ↓
Admin klik "Lihat" untuk melihat bukti bayar (modal preview gambar)
    ↓
Admin klik "Konfirmasi"
    ↓
API: PATCH /api/admin/orders/:orderId/confirm-payment
    ↓
Order status berubah: pending_payment → pending
    ↓
Mitra dikirim notifikasi push: NEW_ORDER ("Pesanan baru menunggu Anda!")
    ↓
Mitra menerima → Status berubah: pending → accepted
    ↓
Setelah pekerjaan selesai → Status: completed
    ↓
Customer dikirim notifikasi: PAYMENT_CONFIRMED
```

### Flow Penolakan/Pembatalan

Jika customer atau mitra membatalkan, order masuk ke status `cancelled` atau `rejected`. Order ini tetap terlihat di halaman ini sebagai riwayat.

## Halaman

### Filter Status

Dropdown filter di bagian atas:

| Value | Label | Keterangan |
|---|---|---|
| _(kosong)_ | Semua Status | Tampilkan semua |
| `pending_payment` | Menunggu Pembayaran | Order yang perlu dikonfirmasi |
| `pending` | Menunggu Mitra | Sudah dikonfirmasi, menunggu mitra |
| `accepted` | Sedang Bekerja | Mitra sudah menerima |
| `in_progress` | Sedang Bekerja | Pengerjaan berlangsung |
| `completed` | Selesai | Order selesai |
| `rejected` | Ditolak | Ditolak oleh mitra |
| `cancelled` | Dibatalkan | Dibatalkan oleh customer |

### Kolom Tabel

| Kolom | Keterangan |
|---|---|
| Pelanggan | Nama lengkap + nickname customer |
| Mitra | Nama lengkap mitra |
| Tanggal | Tanggal pembuatan order (dd MMM yyyy, HH:mm) |
| Total | Total harga + platform fee (format Rupiah) |
| Metode Pembayaran | Label metode bayar (misal: "Transfer BCA - PT Jasaku") |
| Bukti Bayar | Tombol "Lihat" jika ada bukti, atau "Belum diupload" |
| Status | Badge berwarna sesuai status |
| Aksi | Tombol "Konfirmasi" hanya untuk status `pending_payment` |

### Status Badge

| Status | Warna Badge | Label |
|---|---|---|
| `pending_payment` | Warning (kuning) | Menunggu Bayar |
| `pending` | Warning (kuning) | Menunggu Mitra |
| `accepted` | Info (biru) | Sedang Bekerja |
| `in_progress` | Info (biru) | Sedang Bekerja |
| `completed` | Success (hijau) | Selesai |
| `rejected` | Danger (merah) | Ditolak |
| `cancelled` | Gray | Dibatalkan |

### Aksi Konfirmasi

1. Admin klik tombol "Konfirmasi" pada order dengan status `pending_payment`
2. Tombol berubah menjadi spinner "Memproses..."
3. API dipanggil: `PATCH /api/admin/orders/:orderId/confirm-payment`
4. Jika berhasil: toast hijau "Pembayaran dikonfirmasi! Pesanan masuk ke mitra."
5. Jika gagal: toast merah dengan pesan error
6. Daftar order di-refresh otomatis

### Fitur Riwayat (History Hiding)

Order yang sudah tidak aktif (completed/rejected/cancelled) bisa disembunyikan agar tampilan bersih:

1. **Tombol "Lihat Riwayat"**: Toggle menampilkan/menyembunyikan order yang sudah diproses
2. **Tombol "Hapus Riwayat"**: Masuk ke mode select (checkbox)
3. **Mode Select**: Centang order yang ingin disembunyikan → klik "Sembunyikan"
4. ID order yang disembunyikan disimpan di `localStorage` dengan key `confirm_payment_hidden`

**Perubahan riwayat tidak menghapus data di server** — hanya menyembunyikan dari tampilan admin. Riwayat bisa ditampilkan kembali dengan tombol "Lihat Riwayat".

### Auto-refresh

Data di-refresh otomatis setiap **15 detik** via `setInterval`. Interval dihentikan saat halaman ditinggalkan.

### View Payment Proof (Bukti Bayar)

Klik tombol "Lihat" pada kolom Bukti Bayar membuka modal `proofModal` yang menampilkan gambar bukti pembayaran dalam ukuran penuh. Gambar dimuat dari URL yang sudah di-resolve ke public file path.

## API Endpoints

| Method | Endpoint | Keterangan |
|---|---|---|
| GET | `/api/admin/orders/all` | Ambil semua order reguler (bukan custom task) |
| PATCH | `/api/admin/orders/:orderId/confirm-payment` | Konfirmasi pembayaran order |

### Response `GET /api/admin/orders/all`

Mengembalikan array order yang bukan custom task (`task_provider_id = null`), diurutkan dari yang terbaru. Setiap order include:
- `profiles_customer`: nama + nickname customer
- `provider_profiles`: nama mitra
- `payments`: method label, bukti bayar
- `provider_payout`: info rekening mitra (untuk pencairan)
- `platform_fee`: biaya platform

### Request `PATCH /api/admin/orders/:orderId/confirm-payment`

Tidak memerlukan body. Cukup header `Authorization: Bearer <token>`.

**Efek samping:**
- Order status berubah dari `pending_payment` ke `pending`
- Mitra dikirim push notification `NEW_ORDER`
- Customer dikirim push notification `PAYMENT_CONFIRMED`

## Status: (SUKSES)

Fitur konfirmasi pembayaran berfungsi dengan baik. Auto-refresh 15 detik aktif. Fitur history hiding tersimpan di localStorage per browser.

**Lokasi kode:**
- Frontend: `index.html:525-601` (template), `app.js:1207-1295` (logic)
- Backend: `admin.routes.ts:78-80` (routes), `admin.controller.ts:284-301` (handler), `admin.service.ts:266-345` (query)
