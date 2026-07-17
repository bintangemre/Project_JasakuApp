# Indeks & Performansi

> Panduan lengkap tentang semua index dalam database Jasaku dan strategi optimasi performansi.

---

## Ikhtisar

Database Jasaku menggunakan **24+ index** yang terdiri dari:
- **B-tree index** (default): Untuk query equality dan range.
- **GIST index**: Untuk query geospasial PostGIS.
- **Unique index**: Menjamin keunikan data + performa query.
- **Composite index**: Untuk query dengan banyak kolom.

```
+-------------------------------------------------------------------------+
|                    STRATEGI INDEX JASAKU                                |
+-------------------------------------------------------------------------+
|                                                                         |
|  B-tree Index (20+)      GIST Index (1)       Unique Index (5+)       |
|  ────────────────        ──────────────       ─────────────────        |
|  - Query equality        - Spatial query      - Data integrity         |
|  - Range query           - ST_DWithin()       - Fast lookup            |
|  - LIKE prefix           - KNN search         - Composite unique       |
|  - IS NULL               - Bounding box                                  |
|                                                                         |
+-------------------------------------------------------------------------+
```

---

## Daftar Lengkap Semua Index

### 1. Index pada Domain Autentikasi & Pengguna

| No | Nama Index | Tabel | Kolom | Tipe | Kegunaan |
|---|---|---|---|---|---|
| 1 | `idx_users_email` | `users` | `email` | B-tree | Login by email |
| 2 | `idx_users_google_id` | `users` | `google_id` | B-tree | Login by Google OAuth |
| 3 | `idx_users_phone` | `users` | `phone` | B-tree | Login by phone / OTP |
| 4 | `idx_profiles_user_id` | `profiles_customer` | `user_id` | B-tree | Cari profil dari user_id |
| 5 | `idx_provider_documents_pid` | `provider_documents` | `provider_id` | B-tree | Dokumen per provider |
| 6 | `idx_identity_verifications_pid` | `identity_verifications` | `provider_id` | B-tree | Verifikasi per provider |
| 7 | `idx_user_devices_pid` | `user_devices` | `user_id` | B-tree | Device per user |
| 8 | `provider_locations_geo_idx` | `provider_locations` | `location` | GIST | Query geospasial provider |

### 2. Index pada Domain Katalog Layanan

| No | Nama Index | Tabel | Kolom | Tipe | Kegunaan |
|---|---|---|---|---|---|
| 9 | `idx_services_category_id` | `services` | `category_id` | B-tree | Layanan per kategori |
| 10 | `idx_provider_services_pid` | `provider_services` | `provider_id` | B-tree | Layanan yang ditawarkan provider |
| 11 | `idx_provider_service_prices_psid` | `provider_service_prices` | `provider_service_id` | B-tree | Harga per layanan provider |
| 12 | `idx_pricing_types_category_id` | `pricing_types` | `category_id` | B-tree | Pricing type per kategori |
| 13 | (unique komposit) | `provider_services` | `provider_id, service_id` | B-tree UNIQUE | Satu provider = satu layanan sekali |
| 14 | (unique komposit) | `provider_service_prices` | `provider_service_id, pricing_type_id` | B-tree UNIQUE | Satu provider service = satu harga per pricing type |

### 3. Index pada Domain Pesanan

| No | Nama Index | Tabel | Kolom | Tipe | Kegunaan |
|---|---|---|---|---|---|
| 15 | `idx_orders_customer_id` | `orders` | `customer_id` | B-tree | Riwayat order customer |
| 16 | `idx_orders_provider_id` | `orders` | `provider_id` | B-tree | Order aktif provider |
| 17 | `idx_orders_status` | `orders` | `status` | B-tree | Filter order by status |
| 18 | `idx_order_items_oid` | `order_items` | `order_id` | B-tree | Item per order |
| 19 | `idx_order_locations_oid` | `order_locations` | `order_id` | B-tree | Lokasi per order |
| 20 | `idx_order_attachments_oid` | `order_attachments` | `order_id` | B-tree | Lampiran per order |
| 21 | `idx_order_extensions_oid` | `order_extensions` | `order_id` | B-tree | Ekstensi per order |
| 22 | `idx_payments_oid` | `payments` | `order_id` | B-tree | Pembayaran per order |
| 23 | `idx_provider_schedules_pid` | `provider_schedules` | `provider_id` | B-tree | Jadwal per provider |
| 24 | `idx_provider_schedules_date` | `provider_schedules` | `work_date` | B-tree | Jadwal per tanggal |
| 25 | (unique komposit) | `provider_schedules` | `provider_id, work_date` | B-tree UNIQUE | Satu provider = satu jadwal per hari |

### 4. Index pada Domain Custom Tasks

| No | Nama Index | Tabel | Kolom | Tipe | Kegunaan |
|---|---|---|---|---|---|
| 26 | `idx_custom_tasks_customer_id` | `custom_tasks` | `customer_id` | B-tree | Task per customer |
| 27 | `idx_custom_tasks_status` | `custom_tasks` | `status` | B-tree | Filter task by status |
| 28 | `idx_task_locations_tid` | `task_locations` | `task_id` | B-tree | Lokasi per task |
| 29 | `idx_task_providers_pid` | `task_providers` | `provider_id` | B-tree | Task per provider |
| 30 | (unique komposit) | `task_providers` | `task_id, provider_id` | B-tree UNIQUE | Satu provider = satu task sekali |

### 5. Index pada Domain Ulasan & Laporan

| No | Nama Index | Tabel | Kolom | Tipe | Kegunaan |
|---|---|---|---|---|---|
| 31 | `idx_reviews_customer_id` | `reviews` | `customer_id` | B-tree | Ulasan per customer |
| 32 | `idx_reviews_provider_id` | `reviews` | `provider_id` | B-tree | Ulasan per provider |
| 33 | (unique) | `reviews` | `order_id` | B-tree UNIQUE | Satu order = satu ulasan |
| 34 | `idx_reports_reporter_id` | `reports` | `reporter_id` | B-tree | Laporan per user |
| 35 | `idx_reports_status` | `reports` | `status` | B-tree | Filter laporan by status |

### 6. Index pada Domain Admin

| No | Nama Index | Tabel | Kolom | Tipe | Kegunaan |
|---|---|---|---|---|---|
| 36 | `idx_admin_bank_accounts_pid` | `admin_bank_accounts` | `provider_name` | B-tree | Cari rekening per bank |
| 37 | `idx_admin_ewallet_accounts_pid` | `admin_ewallet_accounts` | `provider_name` | B-tree | Cari rekening per e-wallet |
| 38 | `idx_admin_qris_accounts_pid` | `admin_qris_accounts` | `provider_name` | B-tree | Cari QRIS per provider |

---

## Analisis Index per Query Kritis

### Query 1: Login

```sql
SELECT id, role_id, password_hash, status
FROM users
WHERE email = 'user@example.com';
```

**Index:** `idx_users_email` (B-tree pada `email`)
**Estimasi:** ~1-2ms (index seek)
**Penting:** Ini adalah query paling kritis -- harus sangat cepat.

---

### Query 2: Cari Provider Terdekat

```sql
SELECT pp.id, pp.full_name, pp.rating,
       ST_Distance(pl.location::geography,
                   ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography) / 1000 AS km
FROM provider_services ps
JOIN provider_profiles pp ON ps.provider_id = pp.id
JOIN provider_locations pl ON pp.user_id = pl.provider_id
WHERE ps.service_id = :service_id
  AND pp.is_verified = true
  AND pp.is_active = true
  AND ST_DWithin(pl.location::geography,
                  ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography,
                  :radius)
ORDER BY km ASC
LIMIT 20;
```

**Index:** `provider_locations_geo_idx` (GIST pada `location`)
**Estimasi:** ~10-50ms (tergantung jumlah data)
**Tanpa index:** Full table scan + hitung jarak untuk SEMUA baris -- bisa 100x lebih lambat.

---

### Query 3: Riwayat Order Customer

```sql
SELECT o.id, o.status, o.total_price, o.created_at,
       pp.full_name AS provider_name
FROM orders o
JOIN provider_profiles pp ON o.provider_id = pp.id
WHERE o.customer_id = :profile_id
ORDER BY o.created_at DESC
LIMIT 20;
```

**Index:** `idx_orders_customer_id` (B-tree pada `customer_id`)
**Estimasi:** ~2-5ms
**Catatan:** ORDER BY `created_at DESC` bisa dioptimasi dengan index komposit `(customer_id, created_at DESC)`.

---

### Query 4: Pencarian Custom Task

```sql
SELECT ct.id, ct.title, ct.budget_per_person,
       ST_Distance(ct.location::geography,
                   ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography) / 1000 AS km
FROM custom_tasks ct
WHERE ct.status = 'open'
  AND ct.expires_at > NOW()
  AND ST_DWithin(ct.location::geography,
                  ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography,
                  :radius)
ORDER BY km ASC;
```

**Index:**
- `idx_custom_tasks_status` (B-tree pada `status`) -- filter awal
- PostGIS implicit index pada `location` (jika ada)
**Estimasi:** ~10-30ms

---

### Query 5: Cek Ketersediaan Jadwal

```sql
SELECT COUNT(*) FROM provider_schedules
WHERE provider_id = :provider_id
  AND work_date = :work_date
  AND is_booked = true;
```

**Index:** Unique komposit `(provider_id, work_date)`
**Estimasi:** ~1ms (index seek)
**Tanpa unique constraint:** Double booking bisa terjadi.

---

## Panduan Optimasi

### 1. Index yang Wajib Ada

| Index | Alasan | Dampak jika Hilang |
|---|---|---|
| `idx_users_email` | Login paling sering | Login lambat untuk banyak user |
| `provider_locations_geo_idx` | Pencarian terdekat | Pencarian provider lambat drastis |
| `idx_orders_customer_id` | Riwayat order | Customer tidak bisa melihat riwayat |
| `idx_orders_provider_id` | Order aktif | Provider tidak bisa melihat order |
| Unique komposit `provider_schedules` | Cegah double booking | Data inkonsisten |

### 2. Index yang Bisa Ditambahkan

| Tabel | Kolom yang Diusulkan | Alasan |
|---|---|---|
| `orders` | `(customer_id, created_at DESC)` | Riwayat order + sorting |
| `orders` | `(provider_id, status)` | Order aktif provider |
| `custom_tasks` | `(status, expires_at)` | Marketplace task |
| `reviews` | `(provider_id, created_at DESC)` | Ulasan terbaru per provider |

### 3. Query yang Harus Dioptimasi

**N+1 Problem:**

```sql
-- BAD: N+1 queries (N = jumlah order)
SELECT * FROM orders WHERE customer_id = :id;
-- Loop:
SELECT * FROM order_items WHERE order_id = :oid;  -- N kali!

-- GOOD: Single JOIN
SELECT o.*, oi.*, s.name
FROM orders o
LEFT JOIN order_items oi ON o.id = oi.order_id
LEFT JOIN services s ON oi.service_id = s.id
WHERE o.customer_id = :id;
```

**SELECT * Problem:**

```sql
-- BAD: Ambil semua kolom
SELECT * FROM provider_profiles WHERE is_verified = true;

-- GOOD: Ambil kolom yang diperlukan
SELECT id, full_name, rating, total_jobs, profile_photo
FROM provider_profiles
WHERE is_verified = true;
```

**Missing WHERE Problem:**

```sql
-- BAD: Tanpa filter status
SELECT * FROM orders ORDER BY created_at DESC;

-- GOOD: Filter hanya yang aktif
SELECT * FROM orders
WHERE status IN ('pending', 'confirmed', 'in_progress')
ORDER BY created_at DESC;
```

---

## Statistik Index

| Metrik | Nilai |
|---|---|
| Total index | 38 |
| B-tree index | 33 |
| GIST index | 1 |
| Unique index | 5 (komposit) + 2 (single) |
| Index per domain | Autentikasi: 8, Layanan: 6, Pesanan: 11, Custom Task: 5, Ulasan/Laporan: 5, Admin: 3 |

---

## Pertimbangan Storage

### 1. Ukuran Index

```
-- Estimasi ukuran index (per 1 juta baris):
-- B-tree UUID: ~40-60 MB
-- B-tree VARCHAR(255): ~50-80 MB
-- GIST geometry: ~100-200 MB (tergantung data)

-- Total estimasi untuk database Jasaku (100k user, 500k order):
-- B-tree index: ~500 MB - 1 GB
-- GIST index: ~100-200 MB
-- Total: ~600 MB - 1.2 GB
```

### 2. Write Performance

Setiap INSERT/UPDATE/DELETE harus update semua index yang terpengaruh. Trade-off:

- Lebih banyak index = lebih cepat SELECT, lebih lambat INSERT/UPDATE.
- Untuk Jasaku, read-heavy workload (banyak pencarian, banyak lihat data) justify banyak index.
- Write-heavy workload (real-time location update) menggunakan tabel terpisah (`provider_locations`) untuk meminimalkan dampak.

---

## Kesimpulan

1. **38 index** tersebar di seluruh domain database Jasaku.
2. **GIST index** pada `provider_locations` adalah yang paling kritis untuk fitur pencarian terdekat.
3. **Unique constraints** berfungsi ganda: integritas data + performa query.
4. **Denormalisasi** (`rating`, `total_jobs`, `reporter_role`) menghindari JOIN yang mahal.
5. **Trade-off** antara read performance dan write performance sudah di-tuning untuk workload Jasaku (read-heavy).
