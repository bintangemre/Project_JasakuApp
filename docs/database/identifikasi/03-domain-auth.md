# Domain: Autentikasi & Pengguna

> Analisis mendalam tentang desain tabel-tabel dalam domain autentikasi dan pengguna Jasaku.
> Tabel: `roles`, `users`, `profiles_customer`, `provider_profiles`, `provider_locations`, `provider_documents`, `provider_payout_methods`, `identity_verifications`, `user_devices`

---

## Ikhtisar Domain

Domain ini menangani semua aspek yang berkaitan dengan identitas pengguna, autentikasi, otorisasi, dan data profil. Domain ini adalah fondasi dari seluruh sistem — setiap fitur lain (orders, services, payments) bergantung pada domain ini.

```
┌─────────────────────────────────────────────────────────────────────┐
│                     DOMAIN AUTENTIKASI & PENGGUNA                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────┐     ┌──────────────────────────────────────────────┐  │
│  │  roles   │─1:N─│                   users                      │  │
│  └──────────┘     └──────────────────────────────────────────────┘  │
│                          │         │          │          │          │
│                     1:1  │    1:1  │     1:N  │     1:N  │          │
│                          ▼         ▼          ▼          ▼          │
│              ┌──────────────┐ ┌──────────┐ ┌────────┐ ┌─────────┐  │
│              │   profiles_  │ │ provider_│ │reports │ │user_    │  │
│              │   customer   │ │ profiles │ │        │ │devices  │  │
│              └──────────────┘ └────┬─────┘ └────────┘ └─────────┘  │
│                                    │                                │
│                          ┌─────────┼─────────┐                     │
│                      1:1 │     1:N │     1:N │                     │
│                          ▼         ▼         ▼                     │
│              ┌───────────────┐ ┌─────────┐ ┌──────────┐           │
│              │  identity_    │ │provider_│ │provider_ │           │
│              │  verifications│ │documents│ │payout_   │           │
│              └───────────────┘ └─────────┘ │methods   │           │
│                                            └──────────┘           │
│  ┌──────────────────────────────┐                                 │
│  │     provider_locations       │  (terpisah dari provider_profiles) │
│  └──────────────────────────────┘                                 │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Mengapa Desain Ini Dipilih?

### 1. users + profiles_customer + provider_profiles (Tiga Tabel Terpisah)

**Pertanyaan:** Mengapa tidak satu tabel saja yang menyimpan semua data user?

**Jawaban:** Prinsip **Single Responsibility**. Tiga tabel ini punya tanggung jawab yang sangat berbeda:

| Tabel | Tanggung Jawab | Siapa yang mengisi | Frekuensi Update |
|---|---|---|---|
| `users` | Autentikasi (email, password, role, status) | Sistem (otomatis saat register/login) | Jarang |
| `profiles_customer` | Data pribadi customer (nama, alamat, avatar) | Customer (manual) | Sesekali |
| `provider_profiles` | Data provider lengkap (KTP, selfie, rating, verifikasi) | Provider + Sistem (otomatis) | Sering (rating, total_jobs) |

**Kelebihan desain ini:**

1. **Query lebih cepat**: Query login hanya perlu `SELECT` dari `users` — tidak perlu JOIN ke kolom profil yang berat (avatar_url, portfolios, dll).
2. **Tidak ada null columns**: Jika semua digabung, `profiles_customer` akan punya puluhan kolom null (ktp_photo, selfie_photo, rating, dll), dan `provider_profiles` akan punya kolom null untuk data customer.
3. **Evolusi independen**: Menambah kolom profil provider (misal: `portfolios`) tidak mempengaruhi tabel `users`.
4. **Keamanan**: Data sensitif provider (KTP, NIK) terisolasi di tabel terpisah — bisa diberi akses lebih ketat.

**Kekurangan:**

- Butuh JOIN untuk data gabungan (misal: tampilkan nama + email + avatar).
- Lebih banyak tabel = lebih banyak migration.

**Alternatif yang ditolak:**

| Alternatif | Alasan Penolakan |
|---|---|
| Single tabel `users` + semua kolom | Terlalu banyak null columns, query lambat, sulit evolve |
| Single tabel `users` + JSONB profile | Sulit query relasional, tidak ada foreign key, sulit index |
| `users` + `profiles` (tabel universal) | Customer dan provider punya atribut yang sangat berbeda — tabel universal akan sangat lebar |

---

### 2. users + provider_locations (Lokasi Dipisah dari Profil)

**Pertanyaan:** Mengapa lokasi provider tidak disimpan di `provider_profiles`?

**Jawaban:** Lokasi dan profil punya pola update yang **sangat berbeda**.

| Aspek | `provider_profiles` | `provider_locations` |
|---|---|---|
| **Frekuensi Update** | Jarang (saat edit profil) | Sangat sering (~setiap 30 detik) |
| **Ukuran Update** | Banyak kolom (nama, foto, KTP, dll) | 2 kolom saja (location, address) |
| **Akses** | Dibaca saat profil ditampilkan | Dibaca saat pencarian terdekat |
| **Teknologi** | Standar PostgreSQL | PostGIS + GIST index |

**Apa yang terjadi jika digabung?**

```
-- UPDATE provider_profiles SET location = ST_SetSRID(ST_MakePoint(lon, lat), 4326)
-- WHERE id = 'xxx'

-- Problem: Update ini akan:
-- 1. Menulis ulang SELURUH baris (termasuk full_name, ktp_photo, portfolios, dll)
-- 2. Mematikan row-level lock pada baris yang sering diakses
-- 3. Memperlambat query SELECT yang membaca profil
-- 4. Meng-invalidate cache lebih sering
```

**Kelebihan desain terpisah:**

1. **Write contention berkurang**: Update lokasi hanya menulis 2 kolom, bukan 20+ kolom.
2. **GIST index terisolasi**: PostGIS spatial index hanya ada di `provider_locations`, tidak memperlambat operasi CRUD di `provider_profiles`.
3. **Parallel read**: Query profil (untuk dashboard) dan query lokasi (untuk pencarian) bisa berjalan paralel tanpa lock contention.
4. **Retention policy**: Lokasi lama bisa diarsipkan/dihapus tanpa mempengaruhi profil.

**Catatan desain:**

- `provider_locations` FK ke `users.id` (bukan `provider_profiles.id`), karena lokasi adalah data real-time yang melekat pada user, bukan pada profil.
- `provider_id` UNIQUE: Satu provider hanya punya satu baris lokasi (upsert pattern).

---

### 3. provider_documents (Array of Rows, Bukan PostgreSQL Array)

**Pertanyaan:** Mengapa dokumen provider tidak disimpan sebagai array di `provider_profiles`?

```sql
-- Alternatif yang ditolak:
ALTER TABLE provider_profiles ADD COLUMN documents TEXT[];
-- ['url1.jpg', 'url2.jpg', 'url3.pdf']
```

**Jawaban:** Setiap dokumen punya **metadata yang penting dan berbeda**:

```sql
-- Desain aktual (array of rows):
CREATE TABLE provider_documents (
    id          UUID PRIMARY KEY,
    provider_id UUID NOT NULL,
    type        VARCHAR(30) NOT NULL,  -- 'ktp', 'sertifikat', 'portfolio', 'izin_usaha'
    file_url    TEXT NOT NULL,
    category_id UUID,                   -- relasi ke categories (opsional)
    description TEXT,
    created_at  TIMESTAMP
);
```

**Perbandingan:**

| Aspek | PostgreSQL Array | Array of Rows (Tabel) |
|---|---|---|
| Metadata per item | Tidak bisa | Bisa (type, description, created_at) |
| Query by type | `WHERE 'ktp' = ANY(documents)` — tidak efisien | `WHERE type = 'ktp'` — cepat dengan index |
| Relasi ke tabel lain | Tidak bisa | Bisa (category_id) |
| Hapus satu dokumen | Hapus array, reconstruct | `DELETE WHERE id = 'xxx'` |
| Urutan dokumen | Tidak terjamin | Bisa ditambahkan `sort_order` |
| Ukuran | Lebih kecil (satuan kolom) | Lebih besar (tabel terpisah) |

**Kapan array lebih baik?**

Array lebih baik untuk data yang: (a) tidak butuh metadata, (b) tidak perlu query individual, (c) selalu dibaca bersamaan. Contoh: `portfolios` di `provider_profiles` memang menggunakan `TEXT[]` karena hanya berisi URL gambar tanpa metadata tambahan.

---

### 4. identity_verifications (Dipisah dari provider_profiles)

**Pertanyaan:** Mengapa data verifikasi identitas tidak disimpan langsung di `provider_profiles`?

**Jawaban:** Data verifikasi identitas adalah **data sensitif khusus** yang membutuhkan penanganan berbeda:

**Alasan Keamanan:**

1. **Akses terbatas**: Hanya admin dan sistem OCR yang boleh mengakses NIK, data KTP. Profil provider bisa diakses oleh provider itu sendiri dan customer (untuk melihat nama/rating).
2. **Audit trail**: Setiap perubahan data verifikasi perlu dicatat. Dengan tabel terpisah, mudah di-audit.
3. **Retention policy**: Data verifikasi bisa dihapus setelah jangka waktu tertentu tanpa mempengaruhi profil.

**Alasan Teknis:**

1. **JSONB besar**: `ocr_raw_result` dan `liveness_data` menyimpan JSON hasil OCR yang bisa sangat besar (ratusan KB). Menyimpannya di `provider_profiles` akan memperlambat semua query ke tabel tersebut.
2. **Status terpisah**: `face_match_status` dan `liveness_status` adalah alur kerja tersendiri — tidak berkaitan dengan profil provider.

**Isi identity_verifications:**

```
┌─────────────────────────────────────────────────────────┐
│ identity_verifications                                   │
├─────────────────────────────────────────────────────────┤
│ Data KTP (hasil OCR):                                    │
│   - nik (Nomor Induk Kependudukan)                       │
│   - ocr_full_name                                        │
│   - ocr_birth_place, ocr_birth_date                      │
│   - ocr_address, ocr_gender                              │
│   - ocr_blood_type, ocr_religion                         │
│   - ocr_raw_result (JSONB — data mentah dari OCR)        │
│                                                          │
│ Verifikasi Wajah:                                        │
│   - face_match_score (0-1)                               │
│   - face_match_status (pending/matched/unmatched)        │
│                                                          │
│ Liveness Detection:                                      │
│   - liveness_data (JSONB)                                │
│   - liveness_status (pending/passed/failed)              │
│                                                          │
│ Status:                                                   │
│   - created_at, verified_at                              │
└─────────────────────────────────────────────────────────┘
```

---

### 5. user_devices (Tabel Terpisah untuk FCM Tokens)

**Pertanyaan:** Mengapa FCM token tidak disimpan sebagai JSONB array di `users`?

```sql
-- Alternatif yang ditolak:
ALTER TABLE users ADD COLUMN fcm_tokens JSONB;
-- [{"token": "abc", "device": "android"}, {"token": "xyz", "device": "ios"}]
```

**Jawaban:** Satu user bisa login di **banyak device**, dan setiap device punya FCM token yang berbeda dan berubah seiring waktu.

**Masalah dengan array di users:**

1. **Update atomik**: Menghapus satu token dari array JSONB membutuhkan operasi `jsonb_array_elements` + rebuild — tidak atomic.
2. **Index**: Tidak bisa membuat index yang efisien untuk mencari user berdasarkan FCM token tertentu.
3. **Race condition**: Jika user login di device baru sementara device lain logout, update array bisa konflik.
4. **Scan baris `users`**: Query "ambil semua FCM token untuk notifikasi" harus scan kolom JSONB yang besar.

**Kelebihan tabel terpisah:**

1. **Index langsung**: `fcm_token` UNIQUE + index → query `WHERE fcm_token = 'xxx'` sangat cepat.
2. **Upsert mudah**: `INSERT ... ON CONFLICT (fcm_token) DO UPDATE` — sinkronisasi token jadi mudah.
3. **Cleanup otomatis**: `ON DELETE CASCADE` — hapus user → hapus semua token.
4. **Metadata device**: Bisa menyimpan `device_type`, `device_name` — berguna untuk debugging notifikasi.

**Catatan unik:**

- `user_devices` menggunakan `gen_random_uuid()` (PostgreSQL native) bukan `uuid_generate_v4()` — sedikit lebih cepat karena tidak perlu load extension.
- Menggunakan `TIMESTAMPTZ` (timezone-aware) — konsisten untuk aplikasi mobile yang user-nya di timezone berbeda.

---

## Struktur Tabel Secara Detail

### roles

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | SERIAL (INT) | PRIMARY KEY | Auto-increment — satu-satunya tabel non-UUID PK |
| `name` | VARCHAR(50) | NOT NULL UNIQUE | Nama role: `customer`, `mitra`, `admin` |
| `description` | TEXT | — | Deskripsi role |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Waktu pembuatan |

**Data seed:**
```sql
INSERT INTO roles (name, description) VALUES
  ('customer', 'Pengguna yang memesan jasa'),
  ('mitra', 'Penyedia jasa/layanan'),
  ('admin', 'Administrator platform');
```

**Mengapa SERIAL, bukan UUID?**

`roles` adalah tabel referensi kecil (hanya 3 baris). Integer lebih efisien untuk tabel yang jarang berubah dan sering di-JOIN. UUID tidak diperlukan karena role tidak perlu di-generate secara terdistribusi.

---

### users

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PRIMARY KEY | `uuid_generate_v4()` |
| `role_id` | INT | NOT NULL, FK → roles | Role user |
| `email` | VARCHAR(255) | UNIQUE | Email login |
| `phone` | VARCHAR(20) | UNIQUE | Nomor telepon |
| `password_hash` | TEXT | — | Hash bcrypt (opsional untuk Google OAuth) |
| `google_id` | VARCHAR(255) | — | Google OAuth ID |
| `is_phone_verified` | BOOLEAN | DEFAULT FALSE | Status verifikasi HP |
| `is_email_verified` | BOOLEAN | DEFAULT FALSE | Status verifikasi email |
| `status` | VARCHAR(20) | DEFAULT 'active' | Status: `active`, `suspended`, `deleted` |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Waktu registrasi |
| `updated_at` | TIMESTAMP | — | Waktu update terakhir |

**Alur Autentikasi:**

```
Registration
  → Insert ke users (email + password_hash atau google_id)
  → Insert ke profiles_customer ATAU provider_profiles
  → Insert ke user_devices (FCM token)

Login (Email)
  → SELECT * FROM users WHERE email = ?
  → Verify password_hash dengan bcrypt
  → Generate JWT
  → Upsert ke user_devices

Login (Google)
  → Verify Google ID token
  → SELECT * FROM users WHERE google_id = ?
  → Jika belum ada: Insert ke users + profiles_customer
  → Generate JWT
  → Upsert ke user_devices
```

**Unique Constraints:**
- `email` UNIQUE: Satu email hanya untuk satu user.
- `phone` UNIQUE: Satu nomor HP hanya untuk satu user.
- Keduanya NULLABLE — user bisa login dengan salah satu saja.

**Indexes:**
- `idx_users_email`: Login by email.
- `idx_users_google_id`: Login by Google.
- `idx_users_phone`: Login by phone / OTP.

---

### profiles_customer

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PRIMARY KEY | `uuid_generate_v4()` — ID profil, bukan ID user |
| `user_id` | UUID | NOT NULL UNIQUE, FK → users | Relasi ke user (CASCADE delete) |
| `full_name` | VARCHAR(150) | NOT NULL | Nama lengkap |
| `nickname` | VARCHAR(100) | — | Nama panggilan |
| `birth_date` | DATE | — | Tanggal lahir |
| `gender` | VARCHAR(10) | — | Jenis kelamin |
| `address` | TEXT | — | Alamat lengkap |
| `avatar_url` | TEXT | — | URL foto profil |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Waktu pembuatan |
| `updated_at` | TIMESTAMP | — | Waktu update terakhir |

**Penting:**

- `orders.customer_id` merujuk ke `profiles_customer.id`, **bukan** `users.id`. Ini karena order membutuhkan data profil (nama, alamat) secara langsung.
- `profiles_customer.id` ≠ `users.id` — keduanya UUID berbeda yang di-generate terpisah.

---

### provider_profiles

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PRIMARY KEY | `uuid_generate_v4()` |
| `user_id` | UUID | NOT NULL UNIQUE, FK → users | Relasi ke user (CASCADE delete) |
| `full_name` | VARCHAR(100) | NOT NULL | Nama lengkap |
| `nickname` | VARCHAR(50) | — | Nama panggilan |
| `gender` | VARCHAR(10) | — | Jenis kelamin |
| `birth_date` | DATE | — | Tanggal lahir |
| `phone` | VARCHAR(20) | — | Nomor HP (bisa beda dari users) |
| `address` | TEXT | — | Alamat |
| `domicile` | VARCHAR(100) | — | Domisili |
| `profile_photo` | TEXT | — | URL foto profil |
| `ktp_photo` | TEXT | — | URL foto KTP |
| `selfie_photo` | TEXT | — | URL selfie |
| `is_verified` | BOOLEAN | DEFAULT FALSE | Terverifikasi atau belum |
| `verification_status` | VARCHAR(20) | DEFAULT 'pending' | Status: pending/rejected/approved |
| `verification_notes` | TEXT | — | Catatan verifikasi admin |
| `is_active` | BOOLEAN | DEFAULT TRUE | Aktif atau nonaktif |
| `onboarding_completed` | BOOLEAN | DEFAULT FALSE | Onboarding selesai |
| `custom_task_enabled` | BOOLEAN | DEFAULT FALSE | Bisa terima custom task |
| `service_available` | BOOLEAN | DEFAULT TRUE | Menerima order layanan |
| `task_available` | BOOLEAN | DEFAULT TRUE | Menerima custom task |
| `rating` | DECIMAL(2,1) | DEFAULT 0 | Rating rata-rata (0.0 - 5.0) |
| `total_jobs` | INT | DEFAULT 0 | Total pekerjaan selesai |
| `total_reviews` | INT | DEFAULT 0 | Total ulasan diterima |
| `portfolios` | TEXT[] | DEFAULT '{}' | URL gambar portofolio |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Waktu registrasi |
| `updated_at` | TIMESTAMP | — | Waktu update terakhir |

**Denormalisasi yang disengaja:**

`rating`, `total_jobs`, `total_reviews` adalah kolom **denormalized** — dihitung dari tabel `reviews` dan `orders` tapi disimpan langsung di `provider_profiles`. Alasan:
1. Query pencarian provider sangat sering dan membutuhkan rating — menghitung `AVG(rating)` di setiap query terlalu mahal.
2. Rating di-update setiap kali ada ulasan baru (di backend: hitung ulang → update kolom).
3. Trade-off: sedikit inkonsistensi jika ada race condition, tapi performa jauh lebih baik.

---

### provider_locations

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PRIMARY KEY | `uuid_generate_v4()` |
| `provider_id` | UUID | NOT NULL UNIQUE, FK → users | Relasi ke user (NoAction) |
| `address` | TEXT | — | Alamat文字 |
| `location` | GEOMETRY(Point, 4326) | — | Koordinat GPS |

**Spatials Index:**

```sql
CREATE INDEX provider_locations_geo_idx ON provider_locations USING GIST(location);
```

Index GIST (Generalized Search Tree) adalah index khusus untuk data geospasial. Tanpa index ini, query pencarian provider terdekat akan melakukan **full table scan** — sangat lambat dengan ribuan provider.

**Query contoh (cari provider terdekat dalam 5km):**

```sql
SELECT pl.*, 
       ST_Distance(pl.location, ST_SetSRID(ST_MakePoint(116.4074, -6.8241), 4326)) AS distance
FROM provider_locations pl
WHERE ST_DWithin(
    pl.location::geography,
    ST_SetSRID(ST_MakePoint(116.4074, -6.8241), 4326)::geography,
    5000  -- 5 kilometer
)
ORDER BY distance
LIMIT 20;
```

**Update pattern:**

```sql
-- Provider location tracker mengirim lokasi tiap 30 detik
INSERT INTO provider_locations (provider_id, location)
VALUES ('provider-uuid', ST_SetSRID(ST_MakePoint(lon, lat), 4326))
ON CONFLICT (provider_id)
DO UPDATE SET location = EXCLUDED.location, address = EXCLUDED.address;
```

---

### provider_documents

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PRIMARY KEY | `uuid_generate_v4()` |
| `provider_id` | UUID | NOT NULL, FK → provider_profiles | Relasi ke provider (CASCADE delete) |
| `type` | VARCHAR(30) | NOT NULL | Jenis: ktp, sertifikat, portfolio, izin_usaha |
| `file_url` | TEXT | NOT NULL | URL file (Supabase Storage) |
| `category_id` | UUID | — | Relasi ke categories (opsional) |
| `description` | TEXT | — | Deskripsi dokumen |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Waktu upload |

**Jenis dokumen:**

| Type | Keterangan | Wajib? |
|---|---|---|
| `ktp` | Foto KTP | Ya (untuk verifikasi) |
| `selfie` | Foto selfie | Ya (untuk verifikasi) |
| `sertifikat` | Sertifikat keahlian | Tidak |
| `portfolio` | Foto hasil kerja | Tidak |
| `izin_usaha` | Izin usaha (NIB, dll) | Tidak |

---

### provider_payout_methods

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PRIMARY KEY | `uuid_generate_v4()` |
| `provider_id` | UUID | NOT NULL | Relasi ke provider_profiles |
| `type` | VARCHAR(50) | — | Jenis: bank_transfer, e_wallet |
| `provider_name` | VARCHAR(100) | — | Nama bank/ewallet (BCA, GoPay, dll) |
| `account_number` | VARCHAR(100) | — | Nomor rekening |
| `account_name` | VARCHAR(150) | — | Nama pemilik rekening |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Waktu pembuatan |

**Catatan:** Tabel ini tidak punya FK constraint di Prisma (hanya di DDL). `ON DELETE` tidak didefinisikan — kemungkinan besar `NoAction` atau `Restrict` untuk menjaga data payout.

---

### identity_verifications

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PRIMARY KEY | `uuid_generate_v4()` |
| `provider_id` | UUID | NOT NULL UNIQUE, FK → provider_profiles | Relasi ke provider (CASCADE) |
| `nik` | VARCHAR | — | Nomor Induk Kependudukan |
| `ocr_full_name` | VARCHAR | — | Nama dari OCR KTP |
| `ocr_birth_place` | VARCHAR | — | Tempat lahir dari OCR |
| `ocr_birth_date` | VARCHAR | — | Tanggal lahir dari OCR |
| `ocr_address` | TEXT | — | Alamat dari OCR KTP |
| `ocr_gender` | VARCHAR | — | Jenis kelamin dari OCR |
| `ocr_blood_type` | VARCHAR | — | Golongan darah dari OCR |
| `ocr_religion` | VARCHAR | — | Agama dari OCR |
| `ocr_raw_result` | JSONB | — | Data mentah hasil OCR |
| `face_match_score` | FLOAT | — | Skor kecocokan wajah (0-1) |
| `face_match_status` | VARCHAR(20) | DEFAULT 'pending' | Status: pending/matched/unmatched |
| `liveness_data` | JSONB | — | Data liveness detection |
| `liveness_status` | VARCHAR(20) | DEFAULT 'pending' | Status: pending/passed/failed |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Waktu pembuatan |
| `verified_at` | TIMESTAMP | — | Waktu verifikasi selesai |

**Alur Verifikasi:**

```
1. Provider upload KTP → OCR dijalankan → data disimpan di identity_verifications
2. Provider upload selfie → Face match dijalankan → face_match_score & face_match_status diupdate
3. Liveness detection dijalankan → liveness_data & liveness_status diupdate
4. Admin memeriksa hasil → approve/reject
5. Jika approved → provider_profiles.is_verified = true, verification_status = 'approved'
```

---

### user_devices

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PRIMARY KEY | `gen_random_uuid()` |
| `user_id` | UUID | NOT NULL, FK → users | Relasi ke user (CASCADE delete) |
| `fcm_token` | TEXT | NOT NULL UNIQUE | Firebase Cloud Messaging token |
| `device_type` | VARCHAR | NOT NULL | Jenis: android, ios, web |
| `device_name` | VARCHAR | — | Nama device (Samsung Galaxy S23, dll) |
| `created_at` | TIMESTAMPTZ | DEFAULT NOW() | Waktu registrasi |
| `updated_at` | TIMESTAMPTZ | — | Waktu update terakhir |

**Lifecycle FCM Token:**

```
1. User buka app → Firebase register device → dapat fcm_token
2. App kirim token ke backend → UPSERT ke user_devices
3. Backend butuh kirim notifikasi → SELECT fcm_token FROM user_devices WHERE user_id = ?
4. User logout di device tertentu → DELETE dari user_devices WHERE fcm_token = ?
5. User uninstall app → token expired, Firebase auto-cleanup
6. User login di device baru → INSERT record baru
```

---

## Relasi Lintas Domain

Domain autentikasi terhubung ke domain lain melalui beberapa relasi kunci:

```
Domain Autentikasi ──▶ Domain Pesanan
  profiles_customer.id ──▶ orders.customer_id
  provider_profiles.id ──▶ orders.provider_id

Domain Autentikasi ──▶ Domain Layanan
  provider_profiles.id ──▶ provider_services.provider_id

Domain Autentikasi ──▶ Domain Custom Tasks
  users.id ──▶ custom_tasks.customer_id
  provider_profiles.id ──▶ task_providers.provider_id

Domain Autentikasi ──▶ Domain Pembayaran
  provider_profiles.id ──▶ provider_payout_methods.provider_id

Domain Autentikasi ──▶ Domain Ulasan
  users.id ──▶ reviews.customer_id
  users.id ──▶ reviews.provider_id
```

---

## Pertimbangan Keamanan

### 1. Password Storage

- Password disimpan sebagai **bcrypt hash** di `password_hash`.
- Field `password_hash` adalah `TEXT` — bisa menyimpan hash bcrypt (60 karakter) maupun hash algoritmia lain.
- Jika login via Google OAuth, `password_hash` NULL — tidak ada password yang disimpan.

### 2. Data Sensitif

| Data | Lokasi | Siapa yang bisa mengakses |
|---|---|---|
| Password hash | `users.password_hash` | Sistem autentikasi saja |
| NIK (KTP) | `identity_verifications.nik` | Admin + Sistem OCR |
| Hasil OCR KTP | `identity_verifications.ocr_*` | Admin + Sistem OCR |
| Foto KTP | `provider_documents.type = 'ktp'` | Admin + Provider sendiri |
| Data GPS | `provider_locations.location` | Sistem + Customer (saat order aktif) |

### 3. Row-Level Security (RLS)

Semua tabel dalam domain ini diklaim memiliki RLS (Row-Level Security) di PostgreSQL — artinya akses ke baris tertentu dibatasi berdasarkan policy yang didefinisikan di database level. Ini lapisan keamanan tambahan di atas aplikasi.

---

## Pertimbangan Performa

### 1. Query Login

```sql
-- Query paling kritis — harus sangat cepat
SELECT id, role_id, password_hash, status 
FROM users 
WHERE email = 'user@example.com';
-- Dioptimasi dengan index: idx_users_email
```

### 2. Query Pencarian Provider Terdekat

```sql
-- Query berat — butuh GIST index
SELECT pp.full_name, pp.rating, pl.location
FROM provider_profiles pp
JOIN provider_locations pl ON pp.user_id = pl.provider_id
WHERE pp.is_verified = true 
  AND pp.is_active = true
  AND ST_DWithin(pl.location::geography, 
                  ST_SetSRID(ST_MakePoint(?, ?), 4326)::geography, 
                  ?);
-- Dioptimasi dengan: provider_locations_geo_idx (GIST)
```

### 3. Query Notifikasi Push

```sql
-- Query sederhana tapi sering dijalankan
SELECT fcm_token FROM user_devices WHERE user_id IN (?, ?, ?);
-- Dioptimasi dengan: index pada user_id
```

---

## Kesimpulan

Desain domain autentikasi Jasaku mengikuti prinsip:

1. **Single Responsibility**: Setiap tabel punya satu tanggung jawab.
2. **Separation of Concerns**: Data autentikasi, profil, lokasi, dan verifikasi dipisah.
3. **Write Optimization**: Tabel yang sering diupdate (locations) dipisah dari yang jarang (profiles).
4. **Security by Design**: Data sensitif diisolasi di tabel terpisah dengan akses terbatas.
5. **Read Optimization**: Denormalisasi yang disengaja (rating, total_jobs) untuk query cepat.
