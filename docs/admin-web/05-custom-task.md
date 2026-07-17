# Custom Task

## Deskripsi

Halaman ini mengelola Custom Task — layanan khusus yang dibuat langsung oleh customer (bukan dari katalog layanan). Admin bertanggung jawab mengonfirmasi pembayaran dari customer dan me-release dana ke mitra (payout). Halaman memiliki dua sub-tab: **Menunggu Bayar** dan **Pencairan Dana**.

## Flow Lengkap

### Flow Pembayaran

```
Customer buat custom task (judul, deskripsi, budget)
    ↓
Provider/mitra mengerjakan task → Selesai
    ↓
Customer upload bukti bayar → Order status: pending_payment
    ↓
Admin buka halaman Custom Task → Tab "Menunggu Bayar"
    ↓
Admin lihat daftar task menunggu pembayaran
    ↓
Admin klik "Konfirmasi Bayar"
    ↓
API: PATCH /api/admin/tasks/:tpId/confirm-payment
    ↓
Order status: pending_payment → accepted
    ↓
Dana masuk ke escrow (held by platform)
```

### Flow Pencairan Dana

```
Task selesai & pembayaran sudah dikonfirmasi
    ↓
Admin buka tab "Pencairan Dana"
    ↓
Admin lihat daftar task completed, belum payout
    ↓
Admin lihat info rekening mitra (bank/e-wallet, nomor, nama)
    ↓
Admin transfer dana secara manual ke mitra
    ↓
Admin klik "Release Dana"
    ↓
API: PATCH /api/admin/tasks/:tpId/confirm-payout
    ↓
task_providers: payout_confirmed = true
    ↓
Mitra dapat notifikasi: ORDER_PAYOUT_CONFIRMED
```

## Platform Fee

| Aspek | Nilai |
|---|---|
| Platform fee | **5%** dari total harga |
| Perhitungan | `diterima_mitra = total_price - platform_fee` |

## Halaman

### Sub-tabs

| Tab | ID | Keterangan |
|---|---|---|
| Menunggu Bayar | `payment` | Task yang customer sudah upload bukti tapi belum dikonfirmasi admin |
| Pencairan Dana | `payout` | Task yang sudah dibayar tapi belum dicairkan ke mitra |

### Tab: Menunggu Bayar

#### Kolom Tabel

| Kolom | Keterangan |
|---|---|
| Task | Judul task |
| Pelanggan | Nama customer |
| Mitra | Nama mitra |
| Tanggal | Tanggal mitra menerima task |
| Total Dibayar | Total harga (termasuk platform fee) |
| Bukti | Tombol "Lihat" jika ada bukti, atau "-" |
| Status | Badge "Sudah Dibayar" (success) atau "Menunggu Bayar" (warning) |
| Aksi | Tombol "Konfirmasi Bayar" jika belum dikonfirmasi |

#### Aksi Konfirmasi Bayar

1. Admin klik "Konfirmasi Bayar"
2. Modal konfirmasi: "Konfirmasi pembayaran untuk mitra ini?"
3. API: `PATCH /api/admin/tasks/:tpId/confirm-payment`
4. Toast: "Pembayaran dikonfirmasi"
5. Status berubah: "Sudah Dibayar" (hijau), aksi menjadi label "Selesai"

#### Fitur Riwayat

- Toggle "Lihat Riwayat" / "Sembunyikan Riwayat"
- Mode "Hapus Riwayat": centang → sembunyikan
- Disimpan di `localStorage` dengan key `custom_task_payment_hidden`

### Tab: Pencairan Dana

#### Kolom Tabel

| Kolom | Keterangan |
|---|---|
| Task | Judul task |
| Pelanggan | Nama customer |
| Mitra | Nama mitra |
| Tanggal | Tanggal task selesai |
| Diterima Mitra | Total - platform fee (format Rupiah) |
| Rekening Tujuan | Nama bank + badge tipe (Bank/E-Wallet). Jika belum diatur: "-" (merah) |
| No. Rekening | Nomor rekening mitra. Jika belum diatur: "-" (merah) |
| A/N | Nama pemilik rekening. Jika belum diatur: "-" (merah) |
| Bukti | Tombol "Lihat" jika ada bukti bayar dari customer |
| Aksi | Tombol "Release Dana" atau label "Sudah Dicairkan" (hijau) |

#### Aksi Release Dana

1. Admin klik "Release Dana"
2. Modal konfirmasi: "Yakin akan me-release dana ke mitra? Pastikan dana sudah ditransfer manual."
3. API: `PATCH /api/admin/tasks/:tpId/confirm-payout`
4. Toast: "Dana di-release"
5. Label berubah: "Sudah Dicairkan" (hijau)

#### Fitur Riwayat

- Toggle "Lihat Riwayat" / "Sembunyikan Riwayat"
- Mode "Hapus Riwayat": centang → sembunyikan
- Disimpan di `localStorage` dengan key `custom_task_payout_hidden`

### Auto-refresh

Kedua tab di-refresh otomatis setiap **15 detik** (load data dari kedua endpoint secara paralel).

## API Endpoints

| Method | Endpoint | Keterangan |
|---|---|---|
| GET | `/api/admin/tasks/pending-payment` | Task menunggu pembayaran (customer sudah bayar, admin belum konfirmasi) |
| GET | `/api/admin/tasks/pending-payout` | Task menunggu pencairan (sudah dibayar, belum dicairkan ke mitra) |
| PATCH | `/api/admin/tasks/:tpId/confirm-payment` | Konfirmasi pembayaran task |
| PATCH | `/api/admin/tasks/:tpId/confirm-payout` | Konfirmasi pencairan dana task |

### Endpoint Tambahan (tidak dipakai di frontend)

| Method | Endpoint | Keterangan |
|---|---|---|
| GET | `/api/admin/tasks/pending-payment-by-task` | Grouped per task (backend only) |
| PATCH | `/api/admin/tasks/:taskId/confirm-payment-task` | Konfirmasi per task (bukan per task_provider) |

## Status: (SUKSES)

Fitur custom task berfungsi dengan baik. Kedua tab (pembayaran dan pencairan) aktif dengan auto-refresh 15 detik. Riwayat bisa disembunyikan per-browser.

**Lokasi kode:**
- Frontend: `index.html:726-868` (template), `app.js:1358-1465` (logic)
- Backend: `admin.routes.ts:94-99` (routes), `admin.controller.ts:364-422` (handler)
