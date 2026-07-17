# Manajemen Pelanggan

## Deskripsi

Halaman ini digunakan oleh admin untuk mengelola akun customer (pelanggan). Fitur utama adalah melihat daftar pelanggan dan melakukan ban/unban akun.

## Flow Ban Akun

```
Admin buka halaman Pelanggan
    ↓
Admin melihat daftar pelanggan dengan status aktif/banned
    ↓
Admin klik "Blokir" pada pelanggan
    ↓
Modal konfirmasi: "Ban pelanggan ini?"
    ↓
Admin klik "Ya, Hapus"
    ↓
API: PATCH /api/admin/customers/:userId/ban
    ↓
users.status = 'banned'
    ↓
Pelanggan dikirim notifikasi push: ACCOUNT_BANNED
("Akun Anda telah diblokir oleh admin. Hubungi CS untuk informasi lebih lanjut.")
    ↓
Pelanggan tidak bisa login lagi
```

## Flow Unban Akun

```
Admin klik "Aktifkan" pada pelanggan yang dibanned
    ↓
API: PATCH /api/admin/customers/:userId/unban (tanpa konfirmasi modal)
    ↓
users.status = 'active'
    ↓
Pelanggan dikirim notifikasi push: ACCOUNT_UNBANNED
("Akun Anda telah diaktifkan kembali. Anda bisa login sekarang.")
    ↓
Pelanggan bisa login kembali
```

## Halaman

### Kolom Tabel

| Kolom | Keterangan |
|---|---|
| Nama | Nama lengkap customer |
| Email | Email dari tabel users |
| No. HP | Nomor telepon dari tabel users |
| Status | Badge: Aktif (hijau) atau Diblokir (merah) |
| Aksi | Tombol "Blokir" atau "Aktifkan" |

### Tombol Aksi per Status

| Status | Tombol |
|---|---|
| Aktif | Blokir (btn-danger) |
| Diblokir | Aktifkan (btn-success) |

**Perbedaan behavior:**
- **Blokir**: Ada modal konfirmasi ("Ban pelanggan ini?")
- **Aktifkan**: Langsung diproses tanpa modal konfirmasi

## Loading State

Skeleton 5 baris ditampilkan saat data sedang dimuat.

## Empty State

Jika belum ada pelanggan, menampilkan pesan:
- Ikon `fa-users` gray
- "Belum ada pelanggan"

## API Endpoints

| Method | Endpoint | Keterangan |
|---|---|---|
| GET | `/api/admin/customers` | Ambil seluruh pelanggan |
| PATCH | `/api/admin/customers/:userId/ban` | Blokir akun pelanggan |
| PATCH | `/api/admin/customers/:userId/unban` | Aktifkan kembali akun pelanggan |

### Response `GET /api/admin/customers`

Mengembalikan array `profiles_customer` dengan include data `users` (id, email, phone, status, created_at).

### Request `PATCH /api/admin/customers/:userId/ban`

Tidak memerlukan body. Cukup header auth.

**Efek samping:**
- `users.status = 'banned'`
- Push notification `ACCOUNT_BANNED` dikirim ke pelanggan

### Request `PATCH /api/admin/customers/:userId/unban`

Tidak memerlukan body. Cukup header auth.

**Efek samping:**
- `users.status = 'active'`
- Push notification `ACCOUNT_UNBANNED` dikirim ke pelanggan

## Status: (SUKSES)

Fitur manajemen pelanggan berfungsi dengan baik. Ban dan unban aktif dengan push notification.

**Lokasi kode:**
- Frontend: `index.html:415-430` (template), `app.js:239-266` (logic)
- Backend: `admin.routes.ts:49-51` (routes), `admin.controller.ts:169-196` (handlers), `admin.service.ts:204-230` (logic)
