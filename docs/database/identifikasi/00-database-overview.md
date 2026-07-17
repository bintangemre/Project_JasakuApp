# Overview Database Jasaku

> Dokumentasi komprehensif aritektur dan desain database platform Jasaku.
> Terakhir diperbarui: Juli 2026

---

## Arsitektur

Jasaku menggunakan arsitektur database relasional dengan ekstensi geospasial untuk mendukung fitur lokasi dan pemetaan.

| Aspek | Detail |
|---|---|
| **Engine** | PostgreSQL 15 |
| **Ekstensi** | PostGIS (geospasial), uuid-ossp (generasi UUID) |
| **Hosting** | Supabase (managed PostgreSQL) |
| **ORM** | Prisma 7 dengan `@prisma/adapter-pg` |
| **Total Tabel** | 30 (termasuk `spatial_ref_sys` dari PostGIS) |
| **Total Foreign Keys** | 32 |
| **Total Indeks** | 37+ (termasuk GIST indeks untuk geospasial) |
| **Unique Constraints** | 4 (komposit) + 3 (kolom individual) |
| **Primary Key** | UUID (`uuid_generate_v4()`) untuk semua tabel kecuali `roles` (auto-increment INT) |
| **Row-Level Security** | Diaktifkan di semua tabel (dikelola di database, bukan Prisma) |

### Fitur Spesifik

- **UUID sebagai Primary Key**: Semua tabel menggunakan UUID v4 sebagai primary key, kecuali tabel `roles` yang menggunakan auto-increment integer. UUID dipilih karena unik global, tidak bisa ditebak, dan aman untuk digunakan di URL.

- **PostGIS Geometry**: Tabel `provider_locations`, `order_locations`, `custom_tasks`, dan `task_locations` menggunakan tipe data `geometry(Point, 4326)` untuk menyimpan koordinat geospasial dalam format WGS 84 (SRID 4326).

- **Row-Level Security (RLS)**: Semua tabel di database Jasaku diaktifkan RLS-nya. RLS dikelola di level database (bukan di Prisma), sehingga setiap query otomatis difilter berdasarkan konteks pengguna yang sedang login.

- **Array Columns**: Beberapa tabel menggunakan tipe data array PostgreSQL (`TEXT[]`) untuk menyimpan data multi-value, seperti `portfolios` di `provider_profiles` dan `attachments` di `reports`.

---

## Domain Aplikasi

Database Jasaku terbagi menjadi **6 domain utama** yang masing-masing mengelola aspek berbeda dari platform:

### 1. Autentikasi & Pengguna (9 tabel)

Domain ini mengelola seluruh data pengguna platform, mulai dari akun, profil, dokumen verifikasi, hingga perangkat yang terdaftar.

| Tabel | Fungsi |
|---|---|
| `roles` | Daftar role pengguna (admin, customer, provider/mitra) |
| `users` | Akun pengguna utama (email, password, status) |
| `profiles_customer` | Profil lengkap customer (nama, alamat, avatar) |
| `provider_profiles` | Profil lengkap mitra (nama, verifikasi, rating, portofolio) |
| `provider_locations` | Lokasi geospasial mitra (koordinat GPS) |
| `provider_documents` | Dokumen unggahan mitra (KTP, sertifikat, dll.) |
| `provider_payout_methods` | Metode pencairan dana mitra (rekening bank, e-wallet) |
| `identity_verifications` | Hasil verifikasi identitas mitra (OCR KTP, face match, liveness) |
| `user_devices` | Token FCM perangkat untuk push notifikasi |

### 2. Katalog Layanan (5 tabel)

Domain ini mengelola katalog layanan yang tersedia di platform, termasuk kategori, jenis harga, dan penawaran layanan per mitra.

| Tabel | Fungsi |
|---|---|
| `categories` | Kategori layanan (kebersihan, perbaikan, dll.) |
| `pricing_types` | Jenis satuan harga (per jam, per meter, per item, dll.) |
| `services` | Daftar layanan dalam satu kategori |
| `provider_services` | Layanan yang ditawarkan oleh masing-masing mitra |
| `provider_service_prices` | Harga spesifik mitra untuk setiap jenis harga pada layanan |

### 3. Pesanan (7 tabel)

Domain ini mengelola seluruh siklus pesanan, mulai dari pembuatan, item pesanan, lokasi, lampiran, hingga perpanjangan waktu.

| Tabel | Fungsi |
|---|---|
| `orders` | Pesanan utama (status, harga, jadwal) |
| `order_items` | Item layanan dalam satu pesanan |
| `order_locations` | Lokasi tujuan pengerjaan pesanan (geospasial) |
| `order_attachments` | Lampiran file pada pesanan |
| `order_extensions` | Permintaan perpanjangan waktu pengerjaan |
| `provider_schedules` | Jadwal ketersediaan mitra per tanggal |
| _(payments)_ | Terkait domain Pembayaran |

### 4. Pembayaran (4 tabel)

Domain ini mengelola transaksi pembayaran, termasuk metode pembayaran yang tersedia dari sisi admin.

| Tabel | Fungsi |
|---|---|
| `payments` | Record pembayaran untuk setiap pesanan |
| `admin_bank_accounts` | Rekening bank admin untuk pembayaran |
| `admin_ewallet_accounts` | Akun e-wallet admin untuk pembayaran |
| `admin_qris_accounts` | Akun QRIS admin untuk pembayaran |

### 5. Custom Tasks (3 tabel)

Domain ini mengelola fitur tender/pekerjaan khusus di mana customer memposting pekerjaan dan mitra mendaftar untuk mengerjakannya.

| Tabel | Fungsi |
|---|---|
| `custom_tasks` | Pekerjaan khusus yang diposting customer |
| `task_locations` | Lokasi-lokasi dalam satu custom task |
| `task_providers` | Mitra yang menerima/mengerjakan custom task |

### 6. Ulasan & Laporan (2 tabel)

Domain ini mengelola ulasan dari customer dan sistem pelaporan masalah.

| Tabel | Fungsi |
|---|---|
| `reviews` | Ulasan dan rating customer terhadap mitra |
| `reports` | Laporan masalah dari pengguna |

---

## Ringkasan Semua Tabel

| # | Nama Tabel | Domain | Jumlah Kolom | Deskripsi Singkat |
|---|---|---|---|---|
| 1 | `roles` | Autentikasi & Pengguna | 4 | Daftar role pengguna (admin, customer, provider) |
| 2 | `users` | Autentikasi & Pengguna | 12 | Akun pengguna utama dengan credential dan status |
| 3 | `profiles_customer` | Autentikasi & Pengguna | 10 | Profil lengkap pelanggan |
| 4 | `provider_profiles` | Autentikasi & Pengguna | 27 | Profil lengkap mitra dengan status verifikasi dan statistik |
| 5 | `provider_locations` | Autentikasi & Pengguna | 4 | Lokasi geospasial mitra |
| 6 | `provider_documents` | Autentikasi & Pengguna | 7 | Dokumen unggahan mitra untuk verifikasi |
| 7 | `provider_payout_methods` | Autentikasi & Pengguna | 7 | Metode pencairan dana mitra |
| 8 | `identity_verifications` | Autentikasi & Pengguna | 17 | Hasil verifikasi identitas OCR + face match |
| 9 | `user_devices` | Autentikasi & Pengguna | 7 | Token FCM perangkat untuk notifikasi |
| 10 | `categories` | Katalog Layanan | 5 | Kategori layanan |
| 11 | `pricing_types` | Katalog Layanan | 5 | Jenis satuan harga |
| 12 | `services` | Katalog Layanan | 5 | Daftar layanan |
| 13 | `provider_services` | Katalog Layanan | 5 | Layanan yang ditawarkan mitra |
| 14 | `provider_service_prices` | Katalog Layanan | 6 | Harga mitra per jenis harga |
| 15 | `orders` | Pesanan | 18 | Pesanan utama |
| 16 | `order_items` | Pesanan | 7 | Item layanan dalam pesanan |
| 17 | `order_locations` | Pesanan | 4 | Lokasi tujuan pesanan |
| 18 | `order_attachments` | Pesanan | 4 | Lampiran file pesanan |
| 19 | `order_extensions` | Pesanan | 12 | Perpanjangan waktu pengerjaan |
| 20 | `provider_schedules` | Pesanan | 6 | Jadwal ketersediaan mitra |
| 21 | `payments` | Pembayaran | 8 | Record pembayaran |
| 22 | `admin_bank_accounts` | Pembayaran | 7 | Rekening bank admin |
| 23 | `admin_ewallet_accounts` | Pembayaran | 7 | Akun e-wallet admin |
| 24 | `admin_qris_accounts` | Pembayaran | 6 | Akun QRIS admin |
| 25 | `custom_tasks` | Custom Tasks | 17 | Pekerjaan khusus/tender |
| 26 | `task_locations` | Custom Tasks | 6 | Lokasi dalam custom task |
| 27 | `task_providers` | Custom Tasks | 11 | Mitra penerima custom task |
| 28 | `reviews` | Ulasan & Laporan | 8 | Ulasan dan rating |
| 29 | `reports` | Ulasan & Laporan | 12 | Laporan masalah |
| 30 | `spatial_ref_sys` | PostGIS Internal | 5 | Referensi sistem koordinat (PostGIS) |

---

## Diagram

Tersedia beberapa diagram model data dalam format PlantUML dan SQL:

| File | Tipe Diagram | Keterangan |
|---|---|---|
| `erd.plantuml` | Entity Relationship Diagram (Crow's Foot) | Relasi antar entitas dengan notasi Crow's Foot |
| `cdm.plantuml` | Conceptual Data Model | Model konseptual tingkat tinggi |
| `ldm.plantuml` | Logical Data Model | Model logis dengan atribut dan FK |
| `pdm.plantuml` | Physical Data Model | Model fisik dengan tipe data tepat |
| `jasaku_ddl.sql` | SQL DDL Statements | Statements SQL untuk membuat seluruh tabel |

### Cara Generate Diagram

```bash
# Generate PNG dari PlantUML
java -jar plantuml.jar erd.plantuml
java -jar plantuml.jar cdm.plantuml
java -jar plantuml.jar ldm.plantuml
java -jar plantuml.jar pdm.plantuml

# Import DDL ke PowerDesigner
# Buka PowerDesigner → File → Import → SQL DDL → pilih jasaku_ddl.sql
```

---

## Konvensi Penamaan

### Tabel

| Konvensi | Contoh | Keterangan |
|---|---|---|
| snake_case | `provider_profiles` | Semua huruf kecil, underscore sebagai pemisah |
| Jamak (plural) | `users`, `orders`, `categories` | Nama tabel selalu jamak |
| Prefeks domain | `order_items`, `task_providers` | Tabel child menggunakan prefeks dari parent |

### Kolom

| Konvensi | Contoh | Keterangan |
|---|---|---|
| snake_case | `created_at`, `full_name` | Semua huruf kecil, underscore sebagai pemisah |
| Primary key | `id` | Selalu bernama `id` (UUID atau INT) |
| Foreign key | `{referenced_table_singular}_id` | Contoh: `user_id`, `provider_id`, `order_id` |
| Timestamps | `created_at`, `updated_at` | Format: `{verb}_at` |
| Boolean flags | `is_verified`, `is_active`, `is_booked` | Prefeks `is_` untuk flag boolean |
| Status fields | `status`, `verification_status` | Tipe VARCHAR dengan nilai enum |

### Tipe Data

| Tipe | Penggunaan |
|---|---|
| `UUID` | Primary key semua tabel (kecuali `roles`) |
| `INT` | Primary key `roles`, counter/quantity |
| `VARCHAR(n)` | Teks dengan batas panjang (nama, email, status) |
| `TEXT` | Teks panjang tanpa batas (deskripsi, alamat) |
| `DECIMAL(p,s)` | Harga dan angka presisi (uang) |
| `BOOLEAN` | Flag on/off |
| `TIMESTAMP` | Waktu lengkap (created_at, paid_at) |
| `DATE` | Tanggal tanpa waktu (work_date, birth_date) |
| `geometry` | Koordinat geospasial PostGIS |
| `JSONB` | Data JSON yang bisa diquery |
| `TEXT[]` | Array string (portfolios, attachments) |

---

## Statistik Database

### Jumlah Tabel per Domain

| Domain | Jumlah Tabel |
|---|---|
| Autentikasi & Pengguna | 9 |
| Katalog Layanan | 5 |
| Pesanan | 6 |
| Pembayaran | 4 |
| Custom Tasks | 3 |
| Ulasan & Laporan | 2 |
| PostGIS Internal | 1 |
| **Total** | **30** |

### Foreign Keys

Total: **32** foreign key constraints yang menghubungkan tabel-tabel di seluruh domain.

### Indeks

Total: **37+** indeks yang terdiri dari:
- **B-tree indeks** untuk kolom yang sering di-query (email, phone, foreign keys, status)
- **GIST indeks** untuk data geospasial (`provider_locations.location`)
- **Unique indeks** untuk kolom yang harus unik (email, phone, google_id, fcm_token)

### Unique Constraints

| Tabel | Kolom | Keterangan |
|---|---|---|
| `users` | `email` | Email harus unik per pengguna |
| `users` | `phone` | Nomor telepon harus unik per pengguna |
| `provider_schedules` | `(provider_id, work_date)` | Satu mitra hanya bisa punya satu jadwal per hari |
| `task_providers` | `(task_id, provider_id)` | Satu mitra hanya bisa menerima satu custom task sekali |

---

## Model Relasi (Ringkasan)

```
roles ──1:N── users
users ──1:1── profiles_customer
users ──1:1── provider_profiles
users ──1:1── provider_locations
users ──1:N── user_devices
users ──1:N── reports
users ──1:N── reviews (as customer)
users ──1:N── reviews (as provider)

provider_profiles ──1:1── identity_verifications
provider_profiles ──1:N── provider_documents
provider_profiles ──1:N── provider_payout_methods
provider_profiles ──1:N── provider_services
provider_profiles ──1:N── provider_schedules
provider_profiles ──1:N── task_providers
provider_profiles ──1:N── orders

categories ──1:N── pricing_types
categories ──1:N── services
services ──1:N── provider_services
services ──1:N── order_items
pricing_types ──1:N── provider_service_prices
provider_services ──1:N── provider_service_prices

orders ──1:1── payments
orders ──1:N── order_items
orders ──1:1── order_locations
orders ──1:N── order_attachments
orders ──1:N── order_extensions
orders ──1:1── reviews
orders ──0:N── custom_tasks
orders ──0:N── task_providers

custom_tasks ──1:N── task_locations
custom_tasks ──1:N── task_providers
custom_tasks ──1:N── orders
```

---

## Teknologi & Dependencies

| Komponen | Teknologi | Versi |
|---|---|---|
| Database | PostgreSQL | 15 |
| Geospasial | PostGIS | (managed by Supabase) |
| UUID Generation | uuid-ossp | (extension) |
| Hosting | Supabase | managed PostgreSQL |
| ORM | Prisma | 7 |
| Adapter | @prisma/adapter-pg | Prisma 7 |
| Node.js Driver | pg (node-postgres) | via Prisma |

---

## Catatan Penting

1. **RLS diaktifkan**: Semua tabel memiliki Row-Level Security yang aktif. Pastikan untuk memahami konteks autentikasi saat melakukan query langsung ke database.

2. **Tabel `spatial_ref_sys`**: Ini adalah tabel internal PostGIS yang berisi referensi sistem koordinat. Jangan dimodifikasi.

3. **Tabel `roles`**: Satu-satunya tabel yang menggunakan auto-increment integer sebagai primary key. Semua tabel lainnya menggunakan UUID.

4. **ON DELETE CASCADE**: Beberapa relasi menggunakan `ON DELETE CASCADE` (misalnya `profiles_customer.user_id`, `provider_profiles.user_id`), yang berarti menghapus user akan menghapus profil terkait secara otomatis.

5. **Geometry SRID**: Semua kolom `geometry` menggunakan SRID 4326 (WGS 84), yang merupakan standar GPS internasional.

6. **Harga**: Semua kolom harga menggunakan `DECIMAL(12,2)`, yang mendukung nilai hingga Rp 9.999.999.999,99.
