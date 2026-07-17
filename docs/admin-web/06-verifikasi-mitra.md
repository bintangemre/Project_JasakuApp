# Verifikasi Mitra

## Deskripsi

Halaman ini digunakan oleh admin untuk memverifikasi mitra (provider) yang baru mendaftar. Mitra mendaftar dengan data KTP, selfie, dan dokumen pendukung. Admin mereview dan menyetujui/menolak menggunakan checklist verifikasi.

## Flow Lengkap

### Flow Verifikasi

```
Mitra register → Upload KTP + Selfie + Foto Profil + Sertifikat
    ↓
Data masuk ke sistem → verification_status: pending
    ↓
Admin buka halaman Mitra → Filter "Pending"
    ↓
Admin klik "Detail" → Review data diri, foto, dokumen
    ↓
Admin klik "Setujui" → Input catatan (opsional)
    ↓
API: PATCH /api/admin/providers/:providerId/verify { status: 'verified' }
    ↓
provider_profiles: is_verified = true, verification_status = 'verified'
    ↓
Mitra dapat notifikasi push: PROVIDER_VERIFIED
("Selamat! Akun Mitra Anda telah diverifikasi. Silakan mulai menerima pesanan.")
```

### Flow Penolakan

```
Admin klik "Tolak" atau "Tolak dengan Catatan"
    ↓
Modal Checklist Verifikasi muncul (8 item)
    ↓
Admin centang item yang "Tidak Sesuai" + berikan alasan
    ↓
Admin klik "Simpan & Tolak"
    ↓
API: PATCH /api/admin/providers/:providerId/verify { status: 'rejected', checklist, notes }
    ↓
provider_profiles: is_verified = false, verification_status = 'rejected'
    ↓
Mitra dapat notifikasi push: PROVIDER_REJECTED
("Maaf, akun Mitra Anda ditolak. Silakan periksa detail di aplikasi.")
```

### Flow Pembatalan Verifikasi

```
Admin klik "Kembalikan ke Pending"
    ↓
Modal konfirmasi: "Kembalikan mitra ke status pending?"
    ↓
API: PATCH /api/admin/providers/:providerId/unverify
    ↓
provider_profiles: is_verified = false, verification_status = 'pending'
```

## Checklist Verifikasi (8 Item)

| # | ID | Label | Keterangan |
|---|---|---|---|
| 1 | `full_name` | Nama lengkap sesuai KTP | Cocokkan nama di form dengan KTP |
| 2 | `profile_photo` | Foto profil wajar dan sesuai | Foto tidak aneh, tidak blur |
| 3 | `ktp_photo` | Foto KTP jelas dan terbaca | NIK, nama, alamat terbaca |
| 4 | `selfie` | Selfie sesuai KTP (face match) | Wajah di selfie cocok dengan KTP |
| 5 | `documents` | Dokumen ijazah/sertifikat jelas | Dokumen pendukung terbaca |
| 6 | `phone` | Nomor telepon valid | Nomor aktif dan bisa dihubungi |
| 7 | `address` | Alamat domisili valid | Alamat masuk akal |
| 8 | `services` | Layanan sesuai keahlian | Layanan yang dipilih sesuai background |

### Behavior Checklist

- Default setiap item: `status = 'passed'` (Sesuai)
- Admin mengubah ke `status = 'failed'` (Tidak Sesuai) jika ada masalah
- Saat `failed`, input alasan muncul di bawah item tersebut
- Catatan tambahan (opsional) di textarea bawah untuk catatan keseluruhan
- Data yang dikirim ke backend:
  ```json
  {
    "status": "rejected",
    "notes": "catatan keseluruhan",
    "checklist": [
      { "item": "ktp_photo", "status": "failed", "note": "foto buram" },
      { "item": "full_name", "status": "passed" }
    ]
  }
  ```

## Halaman Utama: Daftar Mitra

### Filter

| Tab | Keterangan |
|---|---|
| Semua | Tampilkan seluruh mitra |
| Pending | Hanya mitra dengan `verification_status = pending` |

### Kolom Tabel

| Kolom | Keterangan |
|---|---|
| Nama | Nama lengkap mitra |
| Email | Email dari tabel users |
| No. HP | Nomor telepon |
| Status | Badge: Terverifikasi (hijau), Pending (kuning), Ditolak (merah) |
| Aksi | Tombol aksi sesuai status |

### Tombol Aksi per Status

| Status Mitra | Tombol yang Tersedia |
|---|---|
| Pending | Detail, Terima, Tolak |
| Terverifikasi | Detail, Kembalikan ke Pending, Tolak dengan Catatan |
| Ditolak | Detail, Kembalikan ke Pending |

## Halaman Detail Mitra

### Tab: Data Diri

Menampilkan informasi lengkap mitra:

| Field | Keterangan |
|---|---|
| Foto Profil | Thumbnail, klik untuk buka full image |
| Foto KTP | Thumbnail, klik untuk buka full image |
| Selfie | Thumbnail, klik untuk buka full image |
| Catatan Verifikasi | Ditampilkan jika ada (merah untuk rejected, biru untuk verified) |
| Nama Lengkap | Nama dari form registrasi |
| Email | Email dari tabel users |
| No. HP | Nomor telepon |
| Nama Panggilan | Nickname |
| Jenis Kelamin | Gender |
| Domisili | Alamat domisili |
| Status | Badge verifikasi |
| Custom Task | Badge: Diaktifkan (hijau) atau Nonaktif (gray) |
| Portofolio | Galeri foto pengalaman kerja |

#### Hasil Scan KTP (OCR)

Jika mitra sudah melakukan identifikasi, ditampilkan panel kuning:

| Field | Keterangan |
|---|---|
| NIK | Nomor induk kependudukan |
| Nama (OCR) | Hasil OCR nama dari KTP |
| Tempat Lahir | Tempat lahir |
| Tanggal Lahir | Tanggal lahir |
| Alamat | Alamat dari KTP |
| Jenis Kelamin | Gender dari KTP |
| Gol. Darah | Golongan darah |
| Agama | Agama |

#### Status Liveness & Face Match

| Status | Badge |
|---|---|
| Liveness: `passed` | Lulus (hijau) |
| Liveness: `failed` | Gagal (merah) |
| Liveness: `pending` | Pending (kuning) |
| Face Match: `matched` | Cocok (hijau) |
| Face Match: `not_matched` | Tidak Cocok (merah) |
| Face Match: `pending` | Pending (kuning) |
| Skor Kecocokan | Persentase (misal: 85.3%) |

### Tab: Layanan

Menampilkan daftar layanan yang ditawarkan mitra:

| Kolom | Keterangan |
|---|---|
| Layanan | Nama layanan |
| Harga | Harga satuan (format Rupiah) |
| Satuan | Unit harga (hari, meter, unit, sesi) |

### Tab: Dokumen

Menampilkan dokumen pendukung mitra:

| Kolom | Keterangan |
|---|---|
| Tipe | Ijazah, Portofolio, atau Sertifikat |
| Keterangan | Deskripsi dokumen |
| File | Tombol "Lihat" untuk buka file |

## Auto-refresh

Daftar mitra di-refresh otomatis setiap **15 detik**.

## API Endpoints

| Method | Endpoint | Keterangan |
|---|---|---|
| GET | `/api/admin/providers` | Ambil semua mitra (atau `?pending=true` untuk pending saja) |
| GET | `/api/admin/providers/:providerId/detail` | Ambil detail mitra (profile, services, documents, OCR) |
| PATCH | `/api/admin/providers/:providerId/verify` | Verifikasi atau tolak mitra |
| PATCH | `/api/admin/providers/:providerId/unverify` | Kembalikan mitra ke status pending |

### Request `PATCH /api/admin/providers/:providerId/verify`

```json
// Untuk verifikasi
{ "status": "verified", "notes": "catatan opsional" }

// Untuk penolakan
{
  "status": "rejected",
  "notes": "catatan keseluruhan",
  "checklist": [
    { "item": "ktp_photo", "status": "failed", "note": "foto buram" },
    { "item": "selfie", "status": "failed", "note": "tidak cocok" }
  ]
}
```

### Request `PATCH /api/admin/providers/:providerId/unverify`

Tidak memerlukan body. Cukup header auth.

**Efek samping:**
- `is_verified = false`
- `verification_status = 'pending'`

## Status: (SUKSES)

Fitur verifikasi mitra berfungsi dengan baik. Checklist 8 item lengkap. OCR dan face match ditampilkan di detail. Auto-refresh aktif.

**Lokasi kode:**
- Frontend: `index.html:236-412` (template daftar + detail), `app.js:118-237` (logic daftar + detail), `app.js:268-316` (checklist modal)
- Backend: `admin.routes.ts:42-46` (routes), `admin.controller.ts:18-51,148-156` (handlers), `admin.service.ts:72-151` (logic)
