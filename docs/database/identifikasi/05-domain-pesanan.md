# Domain: Pesanan (Orders)

> Analisis mendalam tentang desain tabel dalam domain pesanan Jasaku.
> Tabel: `orders`, `order_items`, `order_locations`, `order_attachments`, `order_extensions`, `provider_schedules`

---

## Ikhtisar Domain

Domain pesanan adalah **jantung** dari platform Jasaku — di sinilah interaksi antara customer dan provider terjadi. Setiap order melewati lifecycle: pending → confirmed → in_progress → completed → paid.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DOMAIN PESANAN (ORDERS)                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────┐           │
│  │                         orders                               │           │
│  │  ──────────────────────────────────────────────────────────  │           │
│  │  id │ customer_id │ provider_id │ status │ total_price      │           │
│  └──────────────┬───────────────────────────────────────────────┘           │
│                  │                                                          │
│     ┌────────────┼────────────┬──────────────┬──────────────┐              │
│     │            │            │              │              │               │
│  1:N│         1:1│         1:N│           1:N│           1:N│               │
│     ▼            ▼            ▼              ▼              ▼               │
│  ┌────────┐ ┌─────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐       │
│  │order_  │ │order_   │ │order_    │ │order_    │ │provider_     │       │
│  │items   │ │locations│ │attach-   │ │extensions│ │schedules     │       │
│  │        │ │         │ │ments     │ │          │ │              │       │
│  └───┬────┘ └─────────┘ └──────────┘ └──────────┘ └──────────────┘       │
│      │                                                                     │
│      ├── FK → services                                                     │
│      └── FK → pricing_types                                                │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────┐          │
│  │                    payments                                   │          │
│  │  FK → orders                                                 │          │
│  └──────────────────────────────────────────────────────────────┘          │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────┐          │
│  │                    reviews                                    │          │
│  │  FK → orders (one-to-one, UNIQUE)                            │          │
│  └──────────────────────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Mengapa Desain Ini Dipilih?

### 1. orders sebagai tabel sentral

**Pertanyaan:** Mengapa `orders` menjadi tabel terbesar dengan 7+ foreign key?

**Jawaban:** Order adalah **aggregate root** — entitas yang menghubungkan semua domain lain. Satu order menyimpan:

| FK / Relasi | Domain | Keterangan |
|---|---|---|
| `customer_id` → `profiles_customer` | Autentikasi | Siapa yang memesan |
| `provider_id` → `provider_profiles` | Autentikasi | Siapa yang mengerjakan |
| `custom_task_id` → `custom_tasks` | Custom Task | Asal task (opsional) |
| `task_provider_id` → `task_providers` | Custom Task | Relasi task spesifik (opsional) |
| `order_items` | Layanan | Layanan apa yang dipesan |
| `order_locations` | — | Di mana pekerjaan dilakukan |
| `order_attachments` | — | Lampiran terkait |
| `order_extensions` | — | Perpanjangan durasi |
| `payments` | Pembayaran | Status pembayaran |
| `reviews` | Ulasan | Ulasan setelah selesai |
| `provider_schedules` | Jadwal | Jadwal kerja provider |

**Mengapa tidak split jadi beberapa tabel?**

Split akan mempersulit query yang membutuhkan data gabungan (misal: "tampilkan semua order customer X beserta provider, layanan, dan status pembayaran"). Satu tabel `orders` memudikan JOIN untuk semua kebutuhan.

---

### 2. order_items (Tabel Terpisah dari orders)

**Pertanyaan:** Mengapa detail item order tidak disimpan sebagai JSONB array di `orders`?

```sql
-- Alternatif yang ditolak:
ALTER TABLE orders ADD COLUMN items JSONB;
-- [{"service_id": "xxx", "quantity": 1, "price": 200000}]
```

**Jawaban:**

| Aspek | JSONB Array | Tabel Terpisah (order_items) |
|---|---|---|
| Query by service_id | `WHERE items @> '[{"service_id":"xxx"}]'` — lambat | `WHERE service_id = 'xxx'` — cepat dengan index |
| Aggregate | `jsonb_array_elements` — kompleks | `SUM(subtotal)` — sederhana |
| Foreign key | Tidak bisa | Bisa (→ services, → pricing_types) |
| Referential integrity | Tidak ada | Ada (service_id harus valid) |
| Harga snapshot | Bisa, tapi tidak terstruktur | Kolom `price` yang jelas |

**Fitur yang menggunakan:**

- **Detail Order**: Menampilkan semua layanan yang dipesan.
- **Riwayat Harga**: `price` adalah snapshot harga saat order dibuat.
- **Laporan**: Query layanan paling populer (`GROUP BY service_id`).

---

### 3. order_locations (PostGIS Terpisah)

**Pertanyaan:** Mengapa lokasi order tidak di kolom `latitude`/`longitude` biasa di `orders`?

**Jawaban:** PostGIS `geometry` memungkinkan query geospasial yang powerful:

```sql
-- Cari semua order dalam radius 10km dari titik tertentu
SELECT * FROM order_locations
WHERE ST_DWithin(
    location::geography,
    ST_SetSRID(ST_MakePoint(116.4074, -6.8241), 4326)::geography,
    10000
);
```

**Mengapa tabel terpisah dari `orders`?**

1. Kolom `geometry` PostGIS membutuhkan storage khusus — tidak efisien jika hanya 1 lokasi per order.
2. Mendukung multi-lokasi (order pindahan bisa punya origin + destination).
3. Index GIST spesial untuk spatial query tidak memperlambat operasi lain di `orders`.

---

### 4. order_extensions (Tabel Terpisah)

**Pertanyaan:** Mengapa perpanjangan durasi tidak di-update langsung di `orders.end_date`?

**Jawaban:** Perpanjangan membutuhkan **audit trail** dan **biaya tambahan**:

- Setiap ekstensi punya `additional_cost` dan `platform_fee_rate` tersendiri.
- Status ekstensi (pending/accepted/rejected) berbeda dari status order.
- Riwayat perubahan durasi perlu dicatat untuk laporan keuangan.

**Alur ekstensi:**

```
1. Provider minta perpanjangan → order_extensions (status: pending)
2. Customer terima → status: accepted
3. orders.end_date diperbarui
4. additional_cost ditambahkan ke total
```

---

## Struktur Tabel Secara Detail

### orders

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PRIMARY KEY | `uuid_generate_v4()` |
| `customer_id` | UUID | NOT NULL, FK → profiles_customer | Customer pemesan |
| `provider_id` | UUID | NOT NULL, FK → provider_profiles | Provider pekerja |
| `custom_task_id` | UUID | — | FK → custom_tasks (opsional) |
| `task_provider_id` | UUID | — | FK → task_providers (opsional) |
| `status` | VARCHAR(30) | DEFAULT 'pending' | Status order |
| `total_price` | DECIMAL(12,2) | — | Total harga |
| `platform_fee` | DECIMAL(12,2) | — | Biaya platform (5%) |
| `additional_fee` | DECIMAL(12,2) | DEFAULT 0 | Biaya tambahan |
| `description` | TEXT | — | Catatan customer |
| `work_date` | DATE | — | Tanggal pekerjaan |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Waktu order dibuat |
| `start_date` | TIMESTAMP | — | Waktu mulai pengerjaan |
| `end_date` | TIMESTAMP | — | Waktu selesai pengerjaan |
| `assignment_type` | VARCHAR(20) | DEFAULT 'manual' | manual / auto |
| `payout_confirmed` | BOOLEAN | DEFAULT FALSE | Payout sudah dikonfirmasi |
| `payout_at` | TIMESTAMP | — | Waktu payout |

**Status Order (Lifecycle):**

```
pending
  → confirmed (provider menerima)
    → in_progress (provider mulai kerja)
      → completed (pekerjaan selesai)
        → paid (pembayaran terverifikasi)

Tambahan status:
  → cancelled (customer/provider membatalkan)
  → rejected (provider menolak)
  → disputed (ada masalah)
```

**Diagram Lifecycle:**

```
                    ┌─────────────┐
                    │   pending   │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              ▼            │            ▼
     ┌────────────┐        │   ┌───────────┐
     │ confirmed  │        │   │ cancelled │
     └─────┬──────┘        │   └───────────┘
           │               │
           ▼               │
  ┌────────────────┐       │
  │  in_progress   │       │
  └───────┬────────┘       │
          │                │
          ▼                ▼
  ┌────────────┐   ┌───────────┐
  │ completed  │   │ disputed  │
  └─────┬──────┘   └───────────┘
        │
        ▼
  ┌──────────┐
  │  paid    │
  └──────────┘
```

**Penting:**

- `customer_id` merujuk ke `profiles_customer.id` (bukan `users.id`).
- `provider_id` merujuk ke `provider_profiles.id` (bukan `users.id`).
- `custom_task_id` dan `task_provider_id` NULLABLE — hanya terisi untuk order dari custom task.

---

### order_items

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PRIMARY KEY | `uuid_generate_v4()` |
| `order_id` | UUID | NOT NULL, FK → orders | Order induk |
| `service_id` | UUID | NOT NULL, FK → services | Layanan yang dipesan |
| `pricing_type_id` | UUID | NOT NULL, FK → pricing_types | Jenis pricing |
| `quantity` | INT | DEFAULT 1 | Kuantitas |
| `price` | DECIMAL(12,2) | — | Harga satuan (snapshot) |
| `subtotal` | DECIMAL(12,2) | — | Subtotal (quantity × price) |

**Penting:**

- `price` adalah **snapshot** — tidak berubah meski harga provider berubah.
- `subtotal` dihitung saat insert: `quantity × price`.
- `service_id` dan `pricing_type_id` adalah FK ke tabel referensi — memastikan data valid.

**Query perhitungan total order:**

```sql
SELECT SUM(subtotal) AS total FROM order_items WHERE order_id = :order_id;
```

---

### order_locations

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PRIMARY KEY | `uuid_generate_v4()` |
| `order_id` | UUID | NOT NULL, FK → orders | Order terkait |
| `address` | TEXT | — | Alamat teks |
| `location` | GEOMETRY(Point, 4326) | — | Koordinat GPS |

**Penggunaan:**

- **Peta Order**: Menampilkan lokasi order di peta.
- **Navigasi Provider**: Provider melihat rute ke lokasi customer.
- **Pencarian Order**: Admin mencari order berdasarkan area geografis.

---

### order_attachments

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PRIMARY KEY | `uuid_generate_v4()` |
| `order_id` | UUID | NOT NULL, FK → orders | Order terkait |
| `file_url` | TEXT | NOT NULL | URL file (Supabase Storage) |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Waktu upload |

**Penggunaan:**

- **Foto Kondisi Awal**: Customer mengunggah foto sebelum pekerjaan dimulai.
- **Foto Hasil Kerja**: Provider mengunggah foto setelah pekerjaan selesai.
- **Bukti Pendukung**: Bukti untuk klaim/sengketa.

---

### order_extensions

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PRIMARY KEY | `uuid_generate_v4()` |
| `order_id` | UUID | NOT NULL, FK → orders | Order terkait |
| `provider_id` | UUID | NOT NULL | Provider yang meminta |
| `customer_id` | UUID | NOT NULL | Customer yang menentukan |
| `requested_date` | DATE | NOT NULL | Tanggal yang diminta |
| `additional_cost` | DECIMAL(12,2) | NOT NULL | Biaya tambahan |
| `platform_fee_rate` | DECIMAL(3,2) | NOT NULL | Rate biaya platform |
| `extension_count` | INT | DEFAULT 1 | Urutan ekstensi |
| `status` | VARCHAR(20) | DEFAULT 'pending' | pending/accepted/rejected |
| `response_note` | TEXT | — | Catatan respons |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Waktu pengajuan |

**Status Ekstensi:**

```
pending → accepted (customer menyetujui)
pending → rejected (customer menolak)
```

**Penggunaan:**

- **Perpanjangan Waktu**: Provider minta tambah waktu → customer setuju/tolak.
- **Biaya Tambahan**: Setiap ekstensi bisa menambah biaya.
- **Riwayat Perubahan**: Semua perubahan durasi tercatat.

---

### provider_schedules

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PRIMARY KEY | `uuid_generate_v4()` |
| `provider_id` | UUID | NOT NULL, FK → provider_profiles | Provider |
| `work_date` | DATE | NOT NULL | Tanggal kerja |
| `is_booked` | BOOLEAN | DEFAULT FALSE | Sudah dibooking |
| `order_id` | UUID | — | FK → orders (opsional) |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Waktu pembuatan |

**Unique Constraint:**

```sql
UNIQUE(provider_id, work_date)
-- Satu provider hanya punya satu record per tanggal
```

**Penggunaan:**

- **Cek Ketersediaan**: Customer melihat tanggal yang tersedia untuk provider tertentu.
- **Booking**: Saat order dibuat, `is_booked = true` dan `order_id` diisi.
- **Dashboard Provider**: Provider melihat jadwal kerja.

---

## Alur Lengkap: Customer Membuat Order

```
1. Customer pilih layanan & provider
2. Customer pilih tanggal kerja
3. Backend cek: apakah jadwal provider sudah dibooking?
   → SELECT * FROM provider_schedules 
     WHERE provider_id = :pid AND work_date = :date AND is_booked = true
   → Jika sudah: "Provider tidak tersedia"
4. Backend buat order:
   → INSERT INTO orders (customer_id, provider_id, status, ...)
   → INSERT INTO order_items (order_id, service_id, price, ...)
   → INSERT INTO order_locations (order_id, address, location)
   → INSERT INTO provider_schedules (provider_id, work_date, is_booked=true, order_id)
5. Backend kirim notifikasi ke provider (FCM)
6. Response: order_id, status: pending
```

---

## Alur Lengkap: Provider Menyelesaikan Order

```
1. Provider mulai kerja:
   → UPDATE orders SET status = 'in_progress', start_date = NOW()
2. Provider selesai kerja:
   → UPDATE orders SET status = 'completed', end_date = NOW()
3. Customer buat review:
   → INSERT INTO reviews (order_id, customer_id, provider_id, rating, review)
   → UPDATE provider_profiles SET 
       rating = (new avg), 
       total_jobs = total_jobs + 1,
       total_reviews = total_reviews + 1
4. Customer bayar:
   → INSERT INTO payments (order_id, method, amount, status = 'paid')
   → UPDATE orders SET status = 'paid'
5. Admin proses payout:
   → UPDATE orders SET payout_confirmed = true, payout_at = NOW()
   → UPDATE provider_profiles SET total_jobs = total_jobs (sudah di-update di step 3)
```

---

## Query Penting

### 1. Riwayat Order Customer

```sql
SELECT o.id, o.status, o.total_price, o.created_at,
       pp.full_name AS provider_name,
       s.name AS service_name
FROM orders o
JOIN provider_profiles pp ON o.provider_id = pp.id
JOIN order_items oi ON o.id = oi.order_id
JOIN services s ON oi.service_id = s.id
WHERE o.customer_id = :customer_profile_id
ORDER BY o.created_at DESC;
```

### 2. Order Aktif Provider

```sql
SELECT o.id, o.status, o.work_date, o.total_price,
       pc.full_name AS customer_name,
       ol.address AS work_location
FROM orders o
JOIN profiles_customer pc ON o.customer_id = pc.id
LEFT JOIN order_locations ol ON o.id = ol.order_id
WHERE o.provider_id = :provider_profile_id
  AND o.status IN ('pending', 'confirmed', 'in_progress')
ORDER BY o.work_date ASC;
```

### 3. Statistik Order (Admin Dashboard)

```sql
SELECT 
  status,
  COUNT(*) AS count,
  SUM(total_price) AS total_revenue,
  AVG(total_price) AS avg_order_value
FROM orders
WHERE created_at >= :start_date
GROUP BY status
ORDER BY count DESC;
```

---

## Pertimbangan Keamanan & Integrity

### 1. Orphan Prevention

- `orders.customer_id` FK ke `profiles_customer` dengan `ON DELETE NoAction` — order tidak boleh orphän.
- `orders.provider_id` FK ke `provider_profiles` dengan `ON DELETE NoAction` — sama.
- `order_items.order_id` FK ke `orders` dengan `ON DELETE NoAction` — item tidak boleh orphän.

### 2. Double Booking Prevention

```sql
-- Cek sebelum buat order
SELECT COUNT(*) FROM provider_schedules
WHERE provider_id = :provider_id 
  AND work_date = :work_date 
  AND is_booked = true;
-- Jika > 0: provider sudah dibooking
```

### 3. Harga Validation

```sql
-- Validasi harga saat buat order
SELECT psp.price FROM provider_service_prices psp
JOIN provider_services ps ON psp.provider_service_id = ps.id
WHERE ps.provider_id = :provider_id
  AND ps.service_id = :service_id
  AND psp.pricing_type_id = :pricing_type_id;
-- Bandingkan dengan harga yang dikirim client
```

---

## Pertimbangan Performa

### 1. Index pada orders

| Index | Kolom | Kegunaan |
|---|---|---|
| `idx_orders_customer_id` | customer_id | Riwayat order customer |
| `idx_orders_provider_id` | provider_id | Order aktif provider |
| `idx_orders_status` | status | Filter by status (admin) |

### 2. Index pada order_items

| Index | Kolom | Kegunaan |
|---|---|---|
| `idx_order_items_oid` | order_id | Item per order |

### 3. Query N+1 Prevention

```sql
-- BAD: N+1 queries
-- SELECT * FROM orders WHERE customer_id = ? (N queries)
-- For each order: SELECT * FROM order_items WHERE order_id = ? (N queries)

-- GOOD: Single JOIN query
SELECT o.*, oi.*, s.name AS service_name
FROM orders o
LEFT JOIN order_items oi ON o.id = oi.order_id
LEFT JOIN services s ON oi.service_id = s.id
WHERE o.customer_id = :customer_id;
```

---

## Kesimpulan

Domain pesanan dirancang untuk:

1. **Flexibility**: Mendukung order manual, custom task, multi-item, multi-lokasi.
2. **Data Integrity**: Snapshot harga, audit trail ekstensi, status lifecycle yang ketat.
3. **Performance**: Index yang tepat untuk query paling sering.
4. **Geospasial**: Integrasi PostGIS untuk lokasi order dan navigasi.
5. **Auditability**: Semua perubahan (ekstensi, status, pembayaran) tercatat.
