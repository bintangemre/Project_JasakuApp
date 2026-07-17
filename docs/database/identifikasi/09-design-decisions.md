# Keputusan Desain Database — Jasaku

> Dokumentasi komprehensif seluruh keputusan desain (design decisions) di balik arsitektur database Jasaku.
> Tiap keputusan mencakup: alasan pemilihan, trade-off, dan referensi tabel/kolom terkait.
> Terakhir diperbarui: Juli 2026

---

## Daftar Isi

1. [UUID sebagai Primary Key](#1-mengapa-uuid-sebagai-primary-key)
2. [INT Auto-Increment untuk Roles](#2-mengapa-roles-pakai-int-auto-increment-bukan-uuid)
3. [Pemisahan users, profiles_customer, provider_profiles](#3-mengapa-users-profiles_customer-provider_profiles-dipisah-bukan-satu-tabel)
4. [Pemisahan provider_locations dari provider_profiles](#4-mengapa-provider_locations-dipisah-dari-provider_profiles)
5. [orders.customer_id → profiles_customer.id](#5-mengapa-orderscustomer_id--profiles_customerid-bukan-usersid)
6. [orders.provider_id → provider_profiles.id](#6-mengapa-ordersprovider_id--provider_profilesid-bukan-usersid)
7. [Payment Accounts dipisah menjadi 3 tabel](#7-mengapa-payment-accounts-dipisah-menjadi-3-tabel)
8. [PostGIS geometry bukan lat/lng terpisah](#8-mengapa-postgis-geometry-bukan-latlng-terpisah)
9. [Unique constraint provider_schedules](#9-mengapa-provider_schedules-memiliki-unique-constraint-provider_id-work_date)
10. [Custom Tasks punya orders terpisah](#10-mengapa-custom_tasks-punya-orders-terpisah-bukan-field-di-custom_tasks)
11. [DECIMAL vs FLOAT untuk Harga](#11-penggunaan-decimal-vs-float-untuk-harga)
12. [JsonB untuk Data OCR](#12-penggunaan-jsonb-untuk-data-ocr)
13. [On Delete Behavior](#13-on-delete-behavior)
14. [Tidak Ada Soft Delete](#14-mengapa-tidak-ada-soft-delete)
15. [Indexing Strategy](#15-indexing-strategy)
16. [Tidak Ada Table Notifications](#16-mengapa-tidak-ada-table-notifications)
17. [Row-Level Security (RLS)](#17-row-level-security-rls)

---

## 1. Mengapa UUID sebagai Primary Key?

### Keputusan

Semua tabel di database Jasaku menggunakan **UUID v4** (`uuid_generate_v4()`) sebagai primary key, kecuali tabel `roles`.

### Alasan

| # | Alasan | Penjelasan |
|---|--------|------------|
| 1 | **Global unique** | UUID tidak memerlukan auto-increment yang bisa bentrok di distributed system. Di masa depan jika Jasaku punya beberapa server/region, tidak ada konflik ID. |
| 2 | **Tidak bisa ditebak** | URL seperti `api/orders/550e8400-e29b-41d4-a716-446655440000` tidak bisa ditebak oleh attacker. Berbeda dengan `api/orders/42` yang bisa diiterasi. |
| 3 | **Bisa digenerate di client side** | Memungkinkan arsitektur offline-first: Flutter app bisa generate ID pesanan saat offline, lalu sync ke server saat online tanpa konflik. |
| 4 | **Prisma support** | Prisma 7 mendukung UUID generation secara built-in melalui `@default(dbgenerated("uuid_generate_v4()"))` — tidak perlu custom logic. |
| 5 | **Konsistensi** | Semua tabel menggunakan pola yang sama, memudahkan developer baru memahami struktur database. |

### Trade-off

| Aspek | Dampak |
|-------|--------|
| Ukuran storage | UUID = 16 bytes, INT = 4 bytes. Tabel besar seperti `orders` membutuhkan storage lebih banyak untuk primary key dan semua foreign key yang referensi ke UUID. |
| Index performance | B-tree index pada UUID v4 (random) kurang optimal dibanding INT auto-increment (sequential). Page splits lebih sering terjadi karena UUID random tidak berurutan. |
| Readability | UUID sulit dibaca dan diingat manusia. Debugging production memerlukan tools tambahan untuk lookup. |
| Join performance | JOIN pada UUID membutuhkan perbandingan 16 bytes vs 4 bytes pada INT. Dampaknya kecil untuk dataset saat ini (< 1 juta baris), tapi bisa terasa di scale besar. |

### Referensi

- `schema.prisma`: Semua model menggunakan `@id @default(dbgenerated("uuid_generate_v4()")) @db.Uuid`
- `jasaku_ddl.sql`: `id UUID PRIMARY KEY DEFAULT uuid_generate_v4()`

---

## 2. Mengapa Roles pakai INT Auto-Increment (bukan UUID)?

### Keputusan

Tabel `roles` adalah satu-satunya tabel yang menggunakan `SERIAL` (auto-increment integer) sebagai primary key.

### Alasan

| # | Alasan | Penjelasan |
|---|--------|------------|
| 1 | **Tabel sangat kecil** | Hanya 3-4 baris: `customer` (id=1), `provider` (id=2), `admin` (id=3). Tidak perlu UUID untuk tabel referensi statis. |
| 2 | **Efisiensi storage** | Integer 4 bytes vs UUID 16 bytes. Tabel referensi yang jarang berubah tidak memerlukan UUID. |
| 3 | **Kemudahan debugging** | `role_id = 1` lebih mudah dibaca daripada `role_id = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11'`. |
| 4 | **Referensi dari users** | Kolom `role_id` di tabel `users` adalah `INTEGER NOT NULL`. Menggunakan INT untuk foreign key ke tabel kecil lebih efisien. |
| 5 | **Konvensi umum** | Tabel lookup/referensi kecil (roles, status, kategori tetap) sering kali menggunakan integer ID dalam industri. |

### Implikasi di Schema

```prisma
model roles {
  id          Int       @id @default(autoincrement())
  name        String    @unique @db.VarChar(50)
  description String?
  created_at  DateTime? @default(now()) @db.Timestamp(6)
  users       users[]
}
```

```sql
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    ...
);
```

---

## 3. Mengapa users, profiles_customer, provider_profiles dipisah (bukan satu tabel)?

### Keputusan

Data pengguna direpresentasikan dalam **3 tabel terpisah**:
- `users` — data autentikasi & akun
- `profiles_customer` — data profil customer
- `provider_profiles` — data profil mitra

### Alasan

| # | Alasan | Penjelasan |
|---|--------|------------|
| 1 | **Single Responsibility** | Setiap tabel punya satu tujuan. `users` = siapa (autentikasi), `profiles_customer` = data customer, `provider_profiles` = data bisnis mitra. |
| 2 | **Efisiensi storage** | Customer tidak butuh kolom `ktp_photo`, `selfie_photo`, `is_verified`, `rating`, `total_jobs`, `portfolios`. Memisahkan menghemat storage untuk 90%+ pengguna yang adalah customer. |
| 3 | **Efisiensi query** | Query customer (`SELECT * FROM users WHERE email = ?`) tidak perlu melewati kolom provider yang banyak. Query lebih ringan dan cepat. |
| 4 | **Scalability** | `provider_profiles` bisa di-scale independen. Misalnya: caching, replica khusus, atau sharding untuk data provider tanpa mempengaruhi data customer. |
| 5 | **Security** | Data sensitif provider (KTP, selfie) terisolasi di tabel terpisah dengan akses yang lebih ketat. |
| 6 | **Tipe user fleksibel** | Satu user tidak harus punya profil. User bisa daftar dulu (isi `users`), lalu melengkapi profil nanti. Relasi 1:1 dengan nullable profile memungkinkan ini. |

### Trade-off

- **Butuh JOIN** untuk mendapatkan data lengkap: `SELECT u.*, pc.full_name FROM users u JOIN profiles_customer pc ON u.id = pc.user_id`
- **Kode lebih kompleks**: Perlu handle 2-3 tabel saat registrasi dan update profil

### Diagram Relasi

```
roles ──1:N── users ──1:1── profiles_customer
                     ──1:1── provider_profiles
                     ──1:N── user_devices
                     ──1:N── reports
                     ──1:N── reviews
```

---

## 4. Mengapa provider_locations dipisah dari provider_profiles?

### Keputusan

Lokasi mitra disimpan di tabel `provider_profiles`, **bukan** sebagai kolom di `provider_profiles`.

```sql
-- Tabel terpisah
CREATE TABLE provider_locations (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id UUID NOT NULL UNIQUE,
    address     TEXT,
    location    GEOMETRY(Point, 4326)
);
```

### Alasan

| # | Alasan | Penjelasan |
|---|--------|------------|
| 1 | **Update frequency** | Lokasi diupdate **setiap 30 detik** melalui `Geolocator.getPositionStream()`. Profil provider jarang berubah (bulan sekali atau lebih jarang). Menggabungkan berarti lock baris profil saat lokasi diupdate. |
| 2 | **Performance** | Update lokasi tidak mengunci baris profil. Tanpa pemisahan, setiap update lokasi akan mengunci seluruh baris `provider_profiles` yang memiliki 27+ kolom, memblokir pembacaan profil oleh customer. |
| 3 | **PostGIS index** | GIST index hanya perlu dibuat di tabel `provider_locations`. Index geospasial pada tabel dengan 27 kolom akan kurang optimal. |
| 4 | **Ukuran row** | Baris `provider_profiles` sudah besar (27 kolom + array `portfolios`). Menambah kolom `geometry` akan memperparah. Row yang lebih kecil = lebih banyak row per page disk = lebih cepat scan. |
| 5 | **Arsitektur microservice-ready** | Di masa depan, lokasi bisa dipindahkan ke service terpisah (location service) tanpa mengubah struktur profil. |

### Trade-off

- **Extra JOIN** untuk data provider lengkap: `SELECT pp.*, pl.location FROM provider_profiles pp JOIN provider_locations pl ON pp.id = pl.provider_id`
- **Kode lebih kompleks**: Perlu handle 2 tabel saat update lokasi

### Query Geospasial Khas

```sql
-- Cari provider dalam radius 50km
SELECT pp.id, pp.full_name, pl.location
FROM provider_profiles pp
JOIN provider_locations pl ON pp.id = pl.provider_id
WHERE ST_DWithin(
    pl.location::geography,
    ST_SetSRID(ST_MakePoint(119.4167, -5.1333), 4326)::geography,
    50000  -- 50 km dalam meter
);
```

---

## 5. Mengapa orders.customer_id → profiles_customer.id (bukan users.id)?

### Keputusan

Foreign key `customer_id` di tabel `orders` mereferensikan `profiles_customer.id`, bukan `users.id`.

```prisma
model orders {
  customer_id String @db.Uuid
  profiles_customer profiles_customer @relation(fields: [customer_id], references: [id])
}
```

### Alasan

| # | Alasan | Penjelasan |
|---|--------|------------|
| 1 | **Representasi bisnis** | `profiles_customer` adalah representasi "siapa customer ini" dalam konteks bisnis — punya nama, alamat, telepon. `users` hanya punya email dan password. |
| 2 | **Data order butuh profil** | Order menampilkan nama customer, alamat layanan, nomor telepon — semua ada di `profiles_customer`, bukan di `users`. |
| 3 | **Normalisasi** | Order berinteraksi dengan data bisnis, bukan data autentikasi. Memisahkan concern ini mengikuti prinsip normalisasi. |
| 4 | **Cascade delete yang tepat** | `profiles_customer.user_id` pakai `ON DELETE CASCADE` ke `users`. Jika user dihapus, profil customer hilang otomatis. Order tidak hilang karena FK ke `profiles_customer` pakai `NoAction`. |

### Trade-off

- **Extra JOIN ke `users`** untuk data autentikasi: `SELECT u.email FROM orders o JOIN profiles_customer pc ON o.customer_id = pc.id JOIN users u ON pc.user_id = u.id`
- **Query lokasi customer** memerlukan JOIN 3 tabel: `orders → profiles_customer → users (jika butuh email)`

---

## 6. Mengapa orders.provider_id → provider_profiles.id (bukan users.id)?

### Keputusan

Foreign key `provider_id` di tabel `orders` mereferensikan `provider_profiles.id`, bukan `users.id`.

### Alasan

| # | Alasan | Penjelasan |
|---|--------|------------|
| 1 | **Data bisnis provider** | `provider_profiles` punya data yang dibutuhkan order: rating, total_jobs, is_verified, verifikasi_status, nama, telepon. |
| 2 | **Order menampilkan info provider** | Customer melihat nama provider, rating, foto profil saat melihat order — semua dari `provider_profiles`. |
| 3 | **Provider availability** | Pengecekan apakah provider aktif (`is_active`), terverifikasi (`is_verified`), dan tersedia (`service_available`) dilakukan di `provider_profiles`. |
| 4 | **Tipe relasi** | `provider_profiles` punya `orders[]` (1:N) — satu provider bisa punya banyak order. Relasi ini natural dari sisi data bisnis. |

### Trade-off

- **Extra JOIN ke `users`** untuk data autentikasi atau notifikasi: `SELECT u.email FROM orders o JOIN provider_profiles pp ON o.provider_id = pp.id JOIN users u ON pp.user_id = u.id`
- **Query FCM token** untuk push notifikasi ke provider memerlukan 3 tabel: `orders → provider_profiles → users → user_devices`

---

## 7. Mengapa payment accounts dipisah menjadi 3 tabel?

### Keputusan

Metode pembayaran admin disimpan dalam **3 tabel terpisah**:
- `admin_bank_accounts` — rekening bank (nomor rekening, nama pemilik)
- `admin_ewallet_accounts` — e-wallet (nomor telepon, nama akun)
- `admin_qris_accounts` — QRIS (gambar QR code)

### Alasan

| # | Alasan | Penjelasan |
|---|--------|------------|
| 1 | **Struktur data berbeda** | Bank punya `account_number` + `account_name`. QRIS punya `qris_image_url`. E-wallet mirip bank tapi konteks berbeda. Menggabungkan berarti banyak kolom NULL. |
| 2 | **Type safety** | Tidak perlu validasi tipe di application layer. Setiap tabel jelas field-nya, tidak perlu cek `type` untuk menentukan kolom mana yang diisi. |
| 3 | **Mudah diextend** | Jika metode pembayaran baru ditambahkan (misal:/crypto, virtual account), cukup buat tabel baru tanpa mengubah tabel yang ada. |
| 4 | **Query sederhana** | Admin bisa langsung query `SELECT * FROM admin_bank_accounts WHERE is_active = true` tanpa perlu WHERE clause `type = 'bank'`. |
| 5 | **RLS lebih granular** | Setiap tabel bisa punya policy RLS yang berbeda. Misal: hanya admin yang bisa melihat QRIS accounts. |

### Trade-off

- **Query lebih kompleks** jika perlu semua metode pembayaran: `SELECT * FROM admin_bank_accounts UNION ALL SELECT * FROM admin_ewallet_accounts UNION ALL SELECT * FROM admin_qris_accounts`
- **3 tabel untuk admin management** = lebih banyak code di backend

### Struktur Kolom

| Tabel | Kolom Khusus | Kolom Umum |
|-------|-------------|------------|
| `admin_bank_accounts` | `account_number`, `account_name` | `provider_name`, `is_active` |
| `admin_ewallet_accounts` | `account_number`, `account_name` | `provider_name`, `is_active` |
| `admin_qris_accounts` | `qris_image_url` | `provider_name`, `is_active` |

---

## 8. Mengapa PostGIS geometry (bukan lat/lng terpisah)?

### Keputusan

Koordinat geospasial disimpan sebagai `geometry(Point, 4326)` menggunakan **PostGIS**, bukan sebagai kolom `latitude` dan `longitude` terpisah.

```sql
CREATE TABLE provider_locations (
    id          UUID PRIMARY KEY,
    provider_id UUID NOT NULL UNIQUE,
    address     TEXT,
    location    GEOMETRY(Point, 4326)
);
```

### Alasan

| # | Alasan | Penjelasan |
|---|--------|------------|
| 1 | **Query geospasial native** | PostGIS menyediakan fungsi bawaan: `ST_DWithin()`, `ST_DistanceSphere()`, `ST_Intersects()`, `ST_Contains()`. Query radius search menjadi satu baris SQL. |
| 2 | **Radius search** | "Find providers within 50km" = `ST_DWithin(pl.location::geography, point::geography, 50000)`. Tanpa PostGIS, perlu manual haversine formula yang lambat dan error-prone. |
| 3 | **GIST index** | PostGIS menggunakan GIST (Generalized Search Tree) index yang dioptimasi untuk query spasial. B-tree index pada lat/lng terpisah tidak bisa mendukung query lingkaran/area secara efisien. |
| 4 | **Standard** | SRID 4326 (WGS 84) adalah standar GPS internasional. Semua library maps (Flutter Map, Leaflet) menggunakan SRID 4326. |
| 5 | **Advanced queries** | Mendukung query kompleks: "find providers near a route" (ST_DWithin dengan linestring), "find orders in a polygon area" (ST_Contains), "calculate distance between two points" (ST_DistanceSphere). |

### Trade-off

- **Tidak bisa query langsung tanpa PostGIS functions**: Perlu `ST_X(location)` untuk longitude, `ST_Y(location)` untuk latitude
- **Kompleksitas migrasi**: Jika pindah dari Supabase ke PostgreSQL biasa, perlu install PostGIS manual
- **Prisma tidak native support**: Harus pakai `Unsupported("geometry")` di Prisma schema, tidak bisa type-safe

### Contoh Query

```sql
-- Latitude & Longitude dari geometry
SELECT ST_Y(location) AS latitude, ST_X(location) AS longitude
FROM provider_locations;

-- Jarak dalam meter antara dua titik
SELECT ST_DistanceSphere(
    pl.location,
    ST_SetSRID(ST_MakePoint(119.4167, -5.1333), 4326)
) AS distance_meters
FROM provider_locations pl;

-- Provider terdekat dari suatu titik
SELECT pp.full_name, pl.location
FROM provider_profiles pp
JOIN provider_locations pl ON pp.id = pl.provider_id
ORDER BY pl.location <-> ST_SetSRID(ST_MakePoint(119.4167, -5.1333), 4326)
LIMIT 5;
```

---

## 9. Mengapa provider_schedules memiliki unique constraint (provider_id, work_date)?

### Keputusan

Tabel `provider_schedules` memiliki unique constraint komposit pada `(provider_id, work_date)`:

```prisma
model provider_schedules {
  provider_id String   @db.Uuid
  work_date   DateTime @db.Date
  is_booked   Boolean  @default(false)
  order_id    String?

  @@unique([provider_id, work_date])
  @@index([provider_id, work_date])
}
```

### Alasan

| # | Alasan | Penjelasan |
|---|--------|------------|
| 1 | **Mencegah double-booking** | Satu provider hanya bisa menerima **satu order per hari**. Unique constraint memastikan tidak ada dua baris dengan provider_id dan work_date yang sama. |
| 2 | **Business rule** | Provider Jasaku bekerja **per hari**, bukan per jam. Satu hari = satu pekerjaan. Ini aturan inti dari platform. |
| 3 | **Atomic prevention** | Database langsung menolak insert kedua dengan error `unique_violation`. Tidak perlu application-level lock atau SELECT FOR UPDATE. |
| 4 | **Query efisien** | Cek ketersediaan provider = `SELECT COUNT(*) FROM provider_schedules WHERE provider_id = X AND work_date = Y`. Composite index membuat query ini sangat cepat. |
| 5 | **Data integrity** | Constraint di database level lebih reliable daripada validasi di application level yang bisa di-bypass. |

### Alur Pemesanan

```
Customer pilih tanggal → Cek provider_schedules WHERE provider_id = X AND work_date = Y
  → Jika tidak ada baris: provider tersedia, buat schedule + order
  → Jika sudah ada baris: provider sudah booked, tampilkan error
```

---

## 10. Mengapa custom_tasks punya orders terpisah (bukan field di custom_tasks)?

### Keputusan

Custom task dan order dipisah menjadi entitas terpisah:
- `custom_tasks` — wadah/pekerjaan yang diposting customer
- `orders` — transaksi individual untuk setiap provider yang diterima
- `task_providers` — jembatan antara custom_task dan provider

### Alasan

| # | Alasan | Penjelasan |
|---|--------|------------|
| 1 | **Custom task = wadah** | Satu custom task bisa dikerjakan oleh **banyak provider** (`required_people`). Setiap provider yang diterima punya **order sendiri** dengan status, pembayaran, dan review independen. |
| 2 | **Order adalah unit transaksi standar** | Order memiliki payment, items, status workflow, extensions. Semua fitur yang sudah ada untuk order otomatis tersedia untuk custom task. |
| 3 | **Status independen** | Provider A bisa selesai (order status: completed) sementara Provider B masih kerja (order status: in_progress). Tidak bisa dicampur dalam satu tabel. |
| 4 | **Pembayaran independen** | Setiap provider punya jumlah pembayaran sendiri berdasarkan `budget_per_person`. Payment bisa diverifikasi satu per satu. |
| 5 | **Review independen** | Customer bisa kasih review terpisah untuk setiap provider dari custom task yang sama. |

### Trade-off

- **Data terduplikasi**: `customer_id` dan `provider_id` ada di `custom_tasks` DAN `orders`. Tapi ini acceptable karena orders perlu data ini untuk workflow standard.
- **Query lebih kompleks**: Untuk melihat semua order dari custom task: `SELECT * FROM orders WHERE custom_task_id = ?`

### Relasi

```
custom_tasks ──1:N── task_providers ──1:N── orders
                   (siapa menerima)     (transaksi individual)
```

---

## 11. Penggunaan DECIMAL vs FLOAT untuk Harga

### Keputusan

Semua kolom harga menggunakan **DECIMAL(12,2)**, bukan FLOAT:

| Kolom | Tipe | Keterangan |
|-------|------|------------|
| `orders.total_price` | `DECIMAL(12,2)` | Total harga pesanan |
| `orders.platform_fee` | `DECIMAL(12,2)` | Biaya platform |
| `orders.additional_fee` | `DECIMAL(12,2)` | Biaya tambahan (extension) |
| `order_items.price` | `DECIMAL(12,2)` | Harga per item |
| `order_items.subtotal` | `DECIMAL(12,2)` | Subtotal item |
| `payments.amount` | `DECIMAL(12,2)` | Jumlah pembayaran |
| `custom_tasks.budget_per_person` | `DECIMAL(12,0)` | Budget per provider |
| `provider_service_prices.price` | `DECIMAL(12,2)` | Harga mitra per layanan |
| `provider_profiles.rating` | `DECIMAL(2,1)` | Rating 0.0 - 5.0 |
| `order_extensions.additional_cost` | `DECIMAL(12,2)` | Biaya ekstensi |

### Alasan

| # | Alasan | Penjelasan |
|---|--------|------------|
| 1 | **Presisi tepat** | DECIMAL menyimpan angka persis seperti yang dimasukkan. `DECIMAL(12,2)` mendukung nilai hingga Rp 9.999.999.999,99 (12 digit total, 2 desimal). |
| 2 | **Tidak ada floating point error** | `0.1 + 0.2 = 0.30000000000000004` dalam FLOAT. Untuk uang, ini tidak bisa diterima. DECIMAL: `0.1 + 0.2 = 0.3`. |
| 3 | **Standar industri** | Sistem pembayaran (bank, payment gateway) selalu menggunakan DECIMAL/NUMERIC untuk monetary values. |
| 4 | **Predictable rounding** | DECIMAL melakukan rounding yang konsisten. FLOAT bisa menghasilkan angka tak terduga di desimal ke-15. |

### Perbandingan

```
-- FLOAT (ERROR)
SELECT (0.1 + 0.2)::float;        -- 0.30000000000000004
SELECT 9999999999.99::float;       -- 10000000000 (hilang presisi)

-- DECIMAL (BENAR)
SELECT (0.1 + 0.2)::decimal(12,2); -- 0.30
SELECT 9999999999.99::decimal(12,2); -- 9999999999.99 (presisi terjaga)
```

### Rating: DECIMAL(2,1)

```sql
-- Rating 0.0, 0.1, 0.2, ... 4.9, 5.0
-- 1 digit sebelum desimal, 1 digit setelah desimal
-- Cukup untuk representasi rating bintang
```

---

## 12. Penggunaan JsonB untuk Data OCR

### Keputusan

Kolom `ocr_raw_result` dan `liveness_data` di tabel `identity_verifications` menggunakan tipe **JSONB**:

```prisma
model identity_verifications {
  ocr_raw_result Json? @db.JsonB
  liveness_data  Json? @db.JsonB
}
```

### Alasan

| # | Alasan | Penjelasan |
|---|--------|------------|
| 1 | **Data kompleks** | Data OCR berupa JSON nested yang sangat berbeda antar provider OCR (Vidio, FaceTec, dll). Strukturnya tidak bisa diprediksi. |
| 2 | **Format berubah** | Provider OCR sering mengupdate API response format. JSONB fleksibel terhadap perubahan format tanpa perlu migration. |
| 3 | **Bisa diquery** | JSONB bisa diquery: `ocr_raw_result->>'name'` untuk extract field, `ocr_raw_result @> '{"type": "ktp"}'` untuk filter. |
| 4 | **Storage efisien** | JSONB dikompresi dan dioptimasi oleh PostgreSQL. Lebih efisien daripada menyimpan JSON sebagai TEXT. |
| 5 | **Full audit trail** | Menyimpan raw result memungkinkan debugging dan audit jika ada dispute tentang verifikasi identitas. |

### Trade-off

- **Tidak bisa di-validasi di database level**: PostgreSQL tidak bisa enforce struktur JSON. Validasi harus di application layer.
- **Query lebih lambat** dibanding kolom terpisah: `ocr_full_name` sudah ada sebagai kolom VARCHAR, `ocr_raw_result` hanya untuk raw data.
- **Prisma support terbatas**: `Unsupported("JsonB")` di Prisma, tidak ada type safety.

### Contoh Query

```sql
-- Extract nama dari OCR result
SELECT ocr_raw_result->>'full_name' AS nama
FROM identity_verifications;

-- Check apakah OCR result mengandung data tertentu
SELECT * FROM identity_verifications
WHERE ocr_raw_result @> '{"status": "valid"}';
```

---

## 13. On Delete Behavior

### Keputusan

Setiap foreign key di database Jasaku memiliki **ON DELETE behavior** yang dipilih secara deliberatif:

### Kategori CASCADE (Hapus Turunan)

| Parent → Child | ON DELETE | Alasan |
|----------------|-----------|--------|
| `users → profiles_customer` | CASCADE | Hapus user = hapus profil customer. Tidak ada gunanya profil tanpa akun. |
| `users → provider_profiles` | CASCADE | Hapus user = hapus profil provider beserta semua data terkait. |
| `users → user_devices` | CASCADE | Hapus user = hapus semua FCM tokens. Tidak perlu notifikasi ke user yang sudah hapus akun. |
| `users → reviews` (as customer) | CASCADE | Hapus user = hapus semua review yang ditulis. |
| `users → reviews` (as provider) | CASCADE | Hapus user = hapus semua review yang diterima. |
| `orders → reviews` | CASCADE | Hapus order = hapus review. Review tanpa order tidak valid. |
| `provider_profiles → identity_verifications` | CASCADE | Hapus provider = hapus data verifikasi. |
| `provider_profiles → provider_documents` | CASCADE | Hapus provider = hapus semua dokumen. |
| `custom_tasks → task_locations` | CASCADE | Hapus custom task = hapus semua lokasi terkait. |

### Kategori NoAction (Jangan Hapus)

| Parent → Child | ON DELETE | Alasan |
|----------------|-----------|--------|
| `profiles_customer → orders` | NoAction | **Hapus profil customer tidak menghapus order.** Order adalah data transaksi yang harus dipertahankan untuk audit. |
| `provider_profiles → orders` | NoAction | **Hapus provider tidak menghapus order.** Order yang sudah selesai/dibatalkan harus tetap ada. |
| `orders → payments` | NoAction | **Hapus order tidak menghapus payment.** Bukti pembayaran harus tetap ada untuk audit keuangan. |
| `orders → order_items` | NoAction | Data transaksi harus persist. |
| `orders → order_extensions` | NoAction | Riwayat perpanjangan harus tetap ada. |
| `custom_tasks → orders` | NoAction | Order dari custom task harus tetap ada meskipun task dihapus. |
| `custom_tasks → task_providers` | NoAction | Riwayat siapa yang menerima task harus tetap ada. |

### Prinsip

> **Data transaksi (orders, payments, reviews) tidak boleh hilang meskipun user/provider dihapus.** Ini adalah aturan inti untuk audit trail dan compliance.

---

## 14. Mengapa Tidak Ada Soft Delete?

### Keputusan

Semua operasi delete di database Jasaku bersifat **hard delete** — data benar-benar dihapus dari database.

### Alasan

| # | Alasan | Penjelasan |
|---|--------|------------|
| 1 | **Supabase RLS sudah mengontrol akses** | Row-Level Security memastikan hanya authorized users yang bisa mengakses data. Tidak perlu soft delete untuk "menyembunyikan" data. |
| 2 | **Simplicity** | Hard delete lebih sederhana: tidak perlu column `deleted_at`, tidak perlu filter `WHERE deleted_at IS NULL` di setiap query. |
| 3 | **Performance** | Tabel tidak bertumbuh dengan data "mati". Index tetap kecil dan query tetap cepat. |
| 4 | **Storage** | Data yang benar-benar tidak dibutuhkan tidak memakan storage. |
| 5 | **Backup sebagai audit** | Supabase menyediakan point-in-time recovery (PITR). Jika perlu data yang sudah dihapus, bisa di-restore dari backup. |

### Trade-off

- **Tidak bisa restore** data yang terhapus secara langsung dari application
- **Audit trail terbatas**: Tidak ada cara mudah untuk melihat data yang sudah dihapus
- **Referensi FK bisa menjadi masalah**: Jika order mereferensi provider yang sudah dihapus, data provider tidak bisa ditampilkan (hanya ID tersisa)

---

## 15. Indexing Strategy

### Keputusan

Database Jasaku menggunakan **37+ indeks** yang terdiri dari B-tree, GIST, dan unique indeks.

### B-tree Indeks (Login & Lookup Queries)

| Tabel | Indeks | Kolom | Alasan |
|-------|--------|-------|--------|
| `users` | `idx_users_email` | `email` | Login by email — query paling sering |
| `users` | `idx_users_google_id` | `google_id` | Login by Google OAuth |
| `users` | `idx_users_phone` | `phone` | Login by phone, pencarian user |
| `profiles_customer` | `idx_profiles_user_id` | `user_id` | JOIN dari users ke profiles |
| `provider_documents` | `idx_provider_documents_pid` | `provider_id` | Ambil semua dokumen provider |
| `identity_verifications` | `idx_identity_verifications_pid` | `provider_id` | Ambil data verifikasi provider |
| `user_devices` | `idx_user_devices_pid` | `user_id` | Ambil FCM tokens user |
| `reports` | `idx_reports_reporter_id` | `reporter_id` | Filter laporan per user |
| `reports` | `idx_reports_status` | `status` | Filter laporan per status (admin dashboard) |

### Composite Indeks (Query Gabungan)

| Tabel | Indeks | Kolom | Alasan |
|-------|--------|-------|--------|
| `provider_schedules` | Unique + Index | `(provider_id, work_date)` | Cek ketersediaan provider per tanggal |
| `task_providers` | Unique | `(task_id, provider_id)` | Mencegah double-accept custom task |

### GIST Indeks (Geospasial)

| Tabel | Indeks | Kolom | Alasan |
|-------|--------|-------|--------|
| `provider_locations` | `provider_locations_geo_idx` | `location` | Query radius: "find providers within X km" |

### Unique Indeks (Data Integrity)

| Tabel | Kolom | Alasan |
|-------|-------|--------|
| `users` | `email` | Email harus unik per pengguna |
| `users` | `phone` | Nomor telepon harus unik per pengguna |
| `provider_locations` | `provider_id` | Satu lokasi per provider |
| `identity_verifications` | `provider_id` | Satu verifikasi per provider |
| `reviews` | `order_id` | Satu review per order |
| `user_devices` | `fcm_token` | Satu token per device |
| `roles` | `name` | Nama role harus unik |

---

## 16. Mengapa Tidak Ada Table untuk Notifications?

### Keputusan

Tidak ada tabel `notifications` di database Jasaku. Notifikasi ditangani melalui **Firebase Cloud Messaging (FCM)** secara real-time.

### Alasan

| # | Alasan | Penjelasan |
|---|--------|------------|
| 1 | **FCM tokens di `user_devices`** | Token FCM perangkat sudah disimpan di tabel `user_devices`. Tidak perlu tabel terpisah untuk menyimpan token. |
| 2 | **Push notifications bersifat ephemeral** | Notifikasi dikirim langsung ke FCM dan diteruskan ke device. Tidak perlu menyimpan history notifikasi di database. |
| 3 | **Biaya storage** | Menyimpan ribuan notifikasi per user per hari akan membuat database tumbuh sangat cepat tanpa manfaat bisnis yang signifikan. |
| 4 | **Performance** | Query notifikasi (biasanya: "ambil 20 notifikasi terbaru") akan melambat seiring waktu jika semua history disimpan. |
| 5 | **Sudah ada di Firebase** | Firebase Console menyediakan analytics untuk push notifications: delivery rate, open rate, dll. |

### Trade-off

- **Tidak bisa melihat riwayat notifikasi** di aplikasi. Jika user bertanya "notifikasi apa yang saya terima kemarin?", tidak ada cara menjawab.
- **Tidak ada notifikasi in-app**: Notifikasi hanya muncul sebagai push notification, bukan sebagai in-app notification center.
- **Tidak ada notifikasi offline**: Jika device offline, notifikasi hilang (kecuali FCM menampung sementara, tapi tidak dijamin).

---

## 17. Row-Level Security (RLS)

### Keputusan

**Semua tabel** di database Jasaku diaktifkan RLS-nya di Supabase.

### Alasan

| # | Alasan | Penjelasan |
|---|--------|------------|
| 1 | **Keamanan di level database** | Meskipun API bocor atau ada bug di backend, data tetap aman karena RLS memfilter query berdasarkan konteks pengguna. |
| 2 | **Zero-trust architecture** | Setiap query harus melewati policy RLS. Tidak ada "trusted path" yang bisa bypass. |
| 3 | **Supabase managed** | Supabase menyediakan UI untuk manage RLS policies. Tidak perlu SQL manual untuk setup. |
| 4 | **Compliance** | Untuk platform yang menangani data pribadi (KTP, foto, alamat), RLS adalah best practice keamanan. |
| 5 | **Multi-tenant safety** | Customer A tidak bisa melihat data Customer B karena RLS policy memfilter berdasarkan `auth.uid()`. |

### Trade-off

- **Query lebih lambat**: PostgreSQL harus mengevaluasi RLS policy untuk setiap query. Dampaknya kecil untuk single-row lookup, tapi terasa untuk analytical queries.
- **Testing lebih kompleks**: Perlu test dengan konteks user yang berbeda (customer, provider, admin) untuk memastikan policy benar.
- **Development friction**: Developer tidak bisa langsung query database tanpa konteks autentikasi. Perlu service role atau bypass RLS untuk debugging.

### Implementasi

RLS dikelola di database (bukan Prisma). Prisma client berinteraksi dengan database melalui connection yang sudah di-setting konteksnya oleh backend (JWT token → Supabase session → RLS policy evaluation).

---

## Ringkasan

| # | Keputusan | Trade-off Utama |
|---|-----------|-----------------|
| 1 | UUID sebagai PK | Storage lebih besar, index lebih lambat sedikit |
| 2 | INT untuk Roles | Tabel kecil, jarang berubah — efisien |
| 3 | users/profiles_customer/provider_profiles terpisah | Butuh JOIN untuk data gabungan |
| 4 | provider_locations terpisah | Extra JOIN, tapi update lokasi tidak lock profil |
| 5 | orders → profiles_customer | Extra JOIN ke users untuk data auth |
| 6 | orders → provider_profiles | Extra JOIN ke users untuk data auth |
| 7 | 3 tabel payment accounts | Query lebih kompleks, tapi data terstruktur |
| 8 | PostGIS geometry | Tidak bisa query tanpa PostGIS functions |
| 9 | Unique constraint schedules | Database-level prevention, bukan application-level |
| 10 | custom_tasks + orders terpisah | Data terduplikasi, tapi workflow independent |
| 11 | DECIMAL untuk harga | Presisi tepat, tidak ada floating point error |
| 12 | JSONB untuk data OCR | Tidak bisa validasi di database level |
| 13 | On Delete Behavior | Data transaksi harus persist |
| 14 | Tidak ada soft delete | Tidak bisa restore data terhapus |
| 15 | Indexing strategy | B-tree + GIST + composite |
| 16 | Tidak ada tabel notifications | Tidak ada history notifikasi |
| 17 | RLS aktif | Query lebih lambat, testing lebih kompleks |
