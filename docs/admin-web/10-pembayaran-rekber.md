# Pembayaran Rekber (Payment Accounts)

## Deskripsi

Halaman ini digunakan oleh admin untuk mengelola rekening/platform pembayaran Rekber (Rekening Bersama). Rekber adalah rekening tujuan customer membayar pesanan. Tersedia 3 tipe: Bank Transfer, E-Wallet, dan QRIS. Setiap tipe disimpan di tabel Prisma terpisah.

## Tipe Rekber

| Tipe | Kode | Tabel Prisma | Field Khusus |
|---|---|---|---|
| Bank Transfer | `bank_transfer` | `admin_bank_accounts` | `account_name`, `account_number`, `provider_name` |
| E-Wallet | `e_wallet` | `admin_ewallet_accounts` | `account_name`, `account_number`, `provider_name` |
| QRIS | `qris` | `admin_qris_accounts` | `provider_name`, `qris_image_url` |

**Perbedaan QRIS**: Tipe QRIS tidak memiliki `account_name` dan `account_number`. Sebagai gantinya, memiliki `qris_image_url` (gambar kode QR).

## Flow

### Tambah Rekening

```
Admin klik "Tambah"
    ↓
Modal form muncul:
  - Tipe: dropdown (Bank Transfer / E-Wallet / QRIS)
  - Nama Pemilik: input text (hidden untuk QRIS)
  - No. Rekening: input text (hidden untuk QRIS)
  - Nama Bank/Penyedia: input text (misal: BCA, GoPay, DANA)
  - Gambar QRIS: file upload (hanya untuk QRIS)
    ↓
Admin pilih tipe, isi data, upload gambar (jika QRIS)
    ↓
Admin klik "Simpan"
    ↓
API: POST /api/admin/payment-accounts { type, account_name, account_number, provider_name }
    ↓
Jika QRIS + ada file: POST /api/admin/payment-accounts/:id/qris-upload (FormData)
    ↓
Toast: "Rekening ditambahkan" + "Gambar QRIS berhasil diupload"
```

### Edit Rekening

```
Admin klik ikon edit (pensil) pada rekening
    ↓
Modal form muncul dengan data existing
    ↓
Admin ubah data
    ↓
Admin klik "Simpan"
    ↓
API: PUT /api/admin/payment-accounts/:id { ... }
    ↓
Jika ganti gambar QRIS: POST /api/admin/payment-accounts/:id/qris-upload
    ↓
Toast: "Rekening diperbarui"
```

### Hapus Rekening

```
Admin klik ikon tempat sampah
    ↓
Modal konfirmasi: "Hapus rekening ini?"
    ↓
Admin klik "Ya, Hapus"
    ↓
API: DELETE /api/admin/payment-accounts/:id
    ↓
Toast: "Rekening dihapus"
```

### Upload QRIS (langsung dari tabel)

Jika rekening QRIS belum punya gambar, tombol "Upload" ditampilkan langsung di kolom QRIS. Admin bisa upload tanpa masuk mode edit.

## Halaman

### Kolom Tabel

| Kolom | Keterangan |
|---|---|
| Tipe | Badge: Bank Transfer (info/biru), E-Wallet (success/hijau), QRIS (warning/kuning) |
| Nama Akun | Nama pemilik rekening |
| No. Rekening | Nomor rekening (font mono) |
| Penyedia | Nama bank/penyedia (BCA, GoPay, dll) |
| QRIS | Tombol "Lihat QRIS" jika ada gambar, atau tombol "Upload" jika belum |
| Aksi | Tombol Edit (pensil) + Hapus (tempat sampah) |

### QRIS Preview

Klik "Lihat QRIS" membuka modal dengan gambar QR dalam ukuran penuh + nama rekening di bawahnya.

### Empty State

Jika belum ada rekening:
- Ikon `fa-credit-card` gray
- "Belum ada rekening tujuan"
- "Tambah rekening bank, e-wallet, atau QRIS untuk pembayaran"

## API Endpoints

| Method | Endpoint | Keterangan |
|---|---|---|
| GET | `/api/admin/payment-accounts` | Ambil semua rekening (gabungan 3 tabel) |
| POST | `/api/admin/payment-accounts` | Buat rekening baru |
| PUT | `/api/admin/payment-accounts/:id` | Update rekening |
| DELETE | `/api/admin/payment-accounts/:id` | Hapus rekening |
| POST | `/api/admin/payment-accounts/:id/qris-upload` | Upload gambar QRIS (multipart/form-data) |

### Request POST

```json
// Bank Transfer / E-Wallet
{
  "type": "bank_transfer",
  "account_name": "PT Jasaku Bersama",
  "account_number": "1234567890",
  "provider_name": "BCA"
}

// QRIS
{
  "type": "qris",
  "provider_name": "QRIS BCA"
}
```

### Request POST (QRIS Upload)

Menggunakan `multipart/form-data` dengan field `qris` (file gambar).

### Response `GET /api/admin/payment-accounts`

Backend menggabungkan data dari 3 tabel (`admin_bank_accounts`, `admin_ewallet_accounts`, `admin_qris_accounts`) menjadi satu array dengan field `type` yang ditambahkan.

## Status: (SUKSES)

Fitur pembayaran Rekber berfungsi dengan baik. 3 tipe rekening didukung. Upload QRIS aktif.

**Lokasi kode:**
- Frontend: `index.html:479-497` (template), `app.js:1148-1188` (logic + modal + qris modal)
- Backend: `admin.routes.ts:71-75` (routes), `admin.controller.ts:220-282` (handlers), `admin.service.ts:348-417` (logic)
