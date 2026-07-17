# Domain: Katalog Layanan

> Analisis mendalam tentang desain tabel dalam domain katalog layanan Jasaku.
> Tabel: `categories`, `services`, `pricing_types`, `provider_services`, `provider_service_prices`

---

## Ikhtisar Domain

Domain ini menangui semua aspek yang berkaitan dengan katalog layanan — dari definisi kategori, daftar layanan, jenis pricing, hingga harga spesifik yang ditawarkan oleh masing-masing provider.

```
┌────────────────────────────────────────────────────────────────────────┐
│                      DOMAIN KATALOG LAYANAN                            │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  ┌──────────────┐                                                      │
│  │  categories  │                                                      │
│  │  ─────────── │                                                      │
│  │  id (UUID)   │                                                      │
│  │  name        │                                                      │
│  │  description │                                                      │
│  │  icon_url    │                                                      │
│  └──────┬───────┘                                                      │
│         │                                                               │
│         ├──── 1:N ────▶ ┌──────────────┐                               │
│         │               │   services   │                               │
│         │               │   ────────── │                               │
│         │               │   id (UUID)  │                               │
│         │               │   name       │                               │
│         │               │   category_id│                               │
│         │               └──────┬───────┘                               │
│         │                      │                                       │
│         │                      ├──── 1:N ────▶ ┌──────────────────┐    │
│         │                      │               │ provider_services │    │
│         │                      │               │  ─────────────── │    │
│         │                      │               │  provider_id     │    │
│         │                      │               │  service_id      │    │
│         │                      │               └────────┬─────────┘    │
│         │                      │                        │               │
│         │                      │                   1:N  │               │
│         │                      │                        ▼               │
│         │                      │               ┌─────────────────────┐  │
│         │                      │               │provider_service_    │  │
│         │                      │               │     prices         │  │
│         │                      │               │  ────────────────  │  │
│         │                      │               │  price             │  │
│         │                      │               │  pricing_type_id   │──┼──▶ pricing_types
│         │                      │               │  provider_service_id│  │
│         │                      │               └─────────────────────┘  │
│         │                      │                                        │
│         └──── 1:N ────▶ ┌──────────────┐                               │
│                         │pricing_types │                               │
│                         │ ──────────── │                               │
│                         │ id (UUID)    │                               │
│                         │ name         │                               │
│                         │ default_unit │                               │
│                         │ category_id  │ (opsional)                    │
│                         └──────────────┘                               │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Hierarki Data

```
categories (Kategori)
├── services (Layanan)
│   ├── provider_services (Provider yang menawarkan layanan ini)
│   │   └── provider_service_prices (Harga per pricing type)
│   └── order_items (Order yang menggunakan layanan ini)
│
└── pricing_types (Jenis pricing untuk kategori ini)
    └── provider_service_prices (Harga dari provider untuk jenis pricing ini)
```

---

## Mengapa Desain Ini Dipilih?

### 1. categories → services (One-to-Many)

**Analogi:**

```
Kategori: "Rumah Tangga"
  ├── Layanan: Bersih-bersih
  ├── Layanan: Plumbing
  ├── Layanan: Perbaikan AC
  └── Layanan: Cuci Setrika

Kategori: "Renovasi"
  ├── Layanan: Cat Tembok
  ├── Layanan: Pasang Keramik
  └── Layanan: Pemasangan Pipa
```

**Mengapa tidak gabung jadi satu tabel?**

| Alternatif | Masalah |
|---|---|
| Satu tabel `services` dengan kolom `category` (VARCHAR) | Duplikasi nama kategori, tidak ada referential integrity |
| Satu tabel `services` dengan kolom `category_id` (INT) | Sama seperti desain aktual — ini memang benar |

Desain aktual sudah benar: `categories` adalah tabel referensi, `services` punya FK ke `categories`. Ini normalisasi dasar yang menghindari duplikasi.

**Penggunaan:**

- **API `GET /api/services/categories`**: Mengambil semua kategori → tampilkan di halaman utama.
- **API `GET /api/services/categories/:id`**: Mengambil layanan dalam kategori tertentu.

---

### 2. pricing_types (Dipisah dari services)

**Pertanyaan:** Mengapa jenis pricing (Per Hari, Per Meter, Flat) tidak di-hardcode di tabel `services`?

**Jawaban:** Pricing types bersifat **reusable** — "Per Hari" bisa dipakai untuk layanan apa saja.

**Contoh penggunaan:**

```
pricing_type: "Per Hari"
  → Digunakan untuk: Bersih-bersih (Rp 200rb/hari)
  → Digunakan untuk: Servis AC (Rp 150rb/hari)
  → Digunakan untuk: Tukang Las (Rp 300rb/hari)

pricing_type: "Per Meter"
  → Digunakan untuk: Cat Tembok (Rp 5rb/m²)
  → Digunakan untuk: Pasang Keramik (Rp 80rb/m²)

pricing_type: "Flat"
  → Digunakan untuk: Plumbing (Rp 350rb/panggilan)
  → Digunakan untuk: Servis AC (Rp 250rb/unit)
```

**Mengapa tidak di-hardcode?**

| Hardcoding | Masalah |
|---|---|
| Kolom `pricing_type` VARCHAR di `services` | Duplikasi string, tidak bisa mengubah nama pricing type tanpa update banyak baris |
| Enum di aplikasi | Tidak bisa ditambah tanpa deploy ulang, tidak bisa dikustomisasi per kategori |

**Desain aktual:**

- `pricing_types.category_id` opsional: Jika NULL, pricing type berlaku global. Jika diisi, spesifik untuk kategori.
- "Per Hari" (`category_id = NULL`) → berlaku untuk semua kategori.
- "Per Meter Persegi" (`category_id = 'renovasi'`) → hanya untuk kategori Renovasi.

**Penggunaan:**

- **API `GET /api/services/pricing-types`**: Mengambil semua pricing type yang tersedia.
- **API `GET /api/services/pricing-types?category_id=xxx`**: Mengambil pricing type untuk kategori tertentu (+ yang global).

---

### 3. provider_services + provider_service_prices (Dua Tabel Junction)

**Pertanyaan:** Mengapa butuh dua tabel junction? Mengapa tidak satu?

**Jawaban:** Satu provider bisa menawarkan satu layanan dengan **beberapa pricing type** sekaligus.

**Contoh nyata:**

```
Provider "Budi" menawarkan layanan "Bersih-bersih":
  → Per Hari: Rp 200.000
  → Per Meter: Rp 5.000/m²

Provider "Andi" menawarkan layanan "Bersih-bersih":
  → Per Hari: Rp 180.000
  → Per Meter: Rp 4.500/m²
```

**Jika hanya satu tabel junction:**

```
┌─────────────────────────────────────┐
│ provider_services (satu tabel)       │
├─────────────────────────────────────┤
│ provider_id │ service_id │ price    │
│ budi        │ bersih     │ 200000   │  ← Per Hari
│ budi        │ bersih     │ 5000     │  ← Per Meter ← DUPLIKASI provider_id + service_id!
└─────────────────────────────────────┘

-- Masalah: Tidak bisa unique constraint (provider_id, service_id)
-- karena ada dua baris untuk kombinasi yang sama!
```

**Dengan dua tabel:**

```
┌──────────────────────────┐     ┌───────────────────────────────────┐
│ provider_services        │     │ provider_service_prices            │
├──────────────────────────┤     ├───────────────────────────────────┤
│ id: ps-001               │────▶│ id: psp-001                       │
│ provider_id: budi        │     │ provider_service_id: ps-001       │
│ service_id: bersih       │     │ pricing_type_id: per-hari         │
│                          │     │ price: 200000                     │
│                          │     │                                   │
│                          │────▶│ id: psp-002                       │
│                          │     │ provider_service_id: ps-001       │
│                          │     │ pricing_type_id: per-meter        │
│                          │     │ price: 5000                       │
└──────────────────────────┘     └───────────────────────────────────┘

-- Unique constraint: (provider_id, service_id) di provider_services ✓
-- Tidak ada duplikasi!
```

**Kapan desain ini berguna?**

1. **Saat provider mengatur harga**: Provider memilih layanan → menambahkan beberapa opsi pricing.
2. **Saat customer memesan**: Customer memilih salah satu pricing type → harga ditampilkan.
3. **Saat admin melihat data**: Admin bisa melihat semua opsi harga per layanan per provider.

---

### 4. Harga Snapshot di order_items

**Pertanyaan:** Mengapa harga disimpan di `order_items` (snapshot) bukan di-query dari `provider_service_prices`?

**Jawaban:** Harga **bisa berubah sewaktu-waktu**. Jika provider menaikkan harga dari Rp 200rb ke Rp 250rb, order yang sudah dibuat tidak boleh berubah.

```sql
-- order_items menyimpan snapshot harga saat order dibuat
INSERT INTO order_items (order_id, service_id, pricing_type_id, quantity, price, subtotal)
VALUES ('order-xxx', 'bersih-id', 'per-hari-id', 1, 200000, 200000);

-- Sekarang provider naikkan harga ke 250000 di provider_service_prices
-- Order lama TETAP 200000 — tidak berubah!
```

**Penggunaan:**

- **Detail Order**: Menampilkan harga historis yang benar.
- **Pembayaran**: Menghitung total berdasarkan harga saat order, bukan harga saat ini.
- **Laporan Keuangan**: Revenue dihitung dari harga snapshot.

---

## Struktur Tabel Secara Detail

### categories

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PRIMARY KEY | `uuid_generate_v4()` |
| `name` | VARCHAR(100) | NOT NULL | Nama kategori |
| `description` | TEXT | — | Deskripsi kategori |
| `icon_url` | TEXT | — | URL icon kategori |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Waktu pembuatan |

**Contoh data:**

```sql
INSERT INTO categories (name, description, icon_url) VALUES
  ('Rumah Tangga', 'Layanan untuk kebutuhan rumah tangga sehari-hari', 'household.png'),
  ('Renovasi', 'Layanan renovasi dan perbaikan rumah', 'renovation.png'),
  ('Kebersihan', 'Layanan kebersihan dan pencucian', 'cleaning.png'),
  ('Elektronik', 'Layanan perbaikan elektronik', 'electronic.png');
```

---

### services

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PRIMARY KEY | `uuid_generate_v4()` |
| `category_id` | UUID | NOT NULL, FK → categories | Kategori induk |
| `name` | VARCHAR(150) | NOT NULL | Nama layanan |
| `description` | TEXT | — | Deskripsi layanan |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Waktu pembuatan |

**Contoh data:**

```sql
-- Asumsi: category_id untuk "Rumah Tangga" = 'cat-001'
INSERT INTO services (category_id, name, description) VALUES
  ('cat-001', 'Bersih-bersih', 'Layanan pembersihan rumah menyeluruh'),
  ('cat-001', 'Plumbing', 'Perbaikan saluran air dan pipa'),
  ('cat-001', 'Servis AC', 'Perawatan dan perbaikan AC'),
  ('cat-001', 'Cuci Setrika', 'Layanan pencucian dan penyetrikaan pakaian'),
  ('cat-002', 'Cat Tembok', 'Pengecatan interior dan eksterior'),
  ('cat-002', 'Pasang Keramik', 'Pemasangan dan perbaikan keramik');
```

**Query menampilkan layanan per kategori:**

```sql
SELECT s.id, s.name, s.description, c.name AS category
FROM services s
JOIN categories c ON s.category_id = c.id
WHERE c.id = 'cat-001'
ORDER BY s.name;
```

---

### pricing_types

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PRIMARY KEY | `uuid_generate_v4()` |
| `name` | VARCHAR(50) | NOT NULL | Nama pricing type |
| `description` | TEXT | — | Deskripsi |
| `default_unit` | VARCHAR | — | Satuan default (hari, meter, m², dll) |
| `category_id` | UUID | — | FK → categories (opsional, NULL = global) |

**Contoh data:**

```sql
INSERT INTO pricing_types (name, description, default_unit, category_id) VALUES
  ('Per Hari', 'Harga per hari kerja', 'hari', NULL),           -- global
  ('Per Meter', 'Harga per meter panjang', 'meter', NULL),       -- global
  ('Per Meter Persegi', 'Harga per meter persegi', 'm²', NULL),  -- global
  ('Flat', 'Harga tetap per panggilan/paket', NULL, NULL),       -- global
  ('Per Unit', 'Harga per unit barang', 'unit', NULL),           -- global
  ('Per Jam', 'Harga per jam kerja', 'jam', NULL);               -- global
```

**Pricing type global vs spesifik kategori:**

```sql
-- Global (category_id = NULL)
-- Berlaku untuk semua kategori layanan
('Per Hari', ..., NULL)

-- Spesifik kategori (category_id diisi)
-- Hanya berlaku untuk kategori tertentu
('Per Meter Kabel', ..., 'category-listrik-id')
```

---

### provider_services

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PRIMARY KEY | `uuid_generate_v4()` |
| `provider_id` | UUID | NOT NULL | FK → provider_profiles |
| `service_id` | UUID | NOT NULL | FK → services |
| `description` | TEXT | — | Deskripsi khusus provider |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Waktu pendaftaran layanan |

**Unique constraint (di DDL):**

```sql
-- Satu provider hanya bisa mendaftarkan satu layanan sekali
-- (tapi dengan beberapa pricing type)
CREATE UNIQUE INDEX idx_provider_services_unique 
ON provider_services(provider_id, service_id);
```

**Contoh data:**

```sql
-- Provider "Budi" mendaftarkan layanan "Bersih-bersih"
INSERT INTO provider_services (provider_id, service_id, description)
VALUES ('provider-budi-id', 'bersih-bersih-id', 'Bersih-bersih rumah tinggal');

-- Provider "Budi" juga mendaftarkan layanan "Servis AC"
INSERT INTO provider_services (provider_id, service_id, description)
VALUES ('provider-budi-id', 'servis-ac-id', 'Servis AC split dan window');
```

**Query mencari provider untuk layanan tertentu:**

```sql
SELECT pp.id, pp.full_name, pp.rating, pp.total_jobs,
       ps.description AS provider_service_desc
FROM provider_services ps
JOIN provider_profiles pp ON ps.provider_id = pp.id
WHERE ps.service_id = 'bersih-bersih-id'
  AND pp.is_verified = true
  AND pp.is_active = true
  AND pp.service_available = true
ORDER BY pp.rating DESC;
```

---

### provider_service_prices

| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| `id` | UUID | PRIMARY KEY | `uuid_generate_v4()` |
| `provider_service_id` | UUID | NOT NULL | FK → provider_services |
| `pricing_type_id` | UUID | NOT NULL | FK → pricing_types |
| `price` | DECIMAL(12,2) | NOT NULL | Harga |
| `unit` | VARCHAR | — | Satuan (opsional, override dari pricing_types.default_unit) |
| `created_at` | TIMESTAMP | DEFAULT NOW() | Waktu pembuatan |

**Unique constraint (di DDL):**

```sql
-- Satu provider service hanya bisa punya satu harga per pricing type
CREATE UNIQUE INDEX idx_provider_service_prices_unique
ON provider_service_prices(provider_service_id, pricing_type_id);
```

**Contoh data:**

```sql
-- Provider Budi: Bersih-bersih → Per Hari = Rp 200.000
INSERT INTO provider_service_prices (provider_service_id, pricing_type_id, price, unit)
VALUES ('ps-budi-bersih-id', 'per-hari-id', 200000, 'hari');

-- Provider Budi: Bersih-bersih → Per Meter = Rp 5.000/m²
INSERT INTO provider_service_prices (provider_service_id, pricing_type_id, price, unit)
VALUES ('ps-budi-bersih-id', 'per-meter-id', 5000, 'm²');

-- Provider Budi: Servis AC → Flat = Rp 150.000
INSERT INTO provider_service_prices (provider_service_id, pricing_type_id, price, unit)
VALUES ('ps-budi-servis-ac-id', 'flat-id', 150000, NULL);
```

**Query menampilkan opsi harga untuk satu layanan provider:**

```sql
SELECT pt.name AS pricing_type, 
       pt.default_unit,
       psp.price,
       psp.unit AS override_unit
FROM provider_service_prices psp
JOIN pricing_types pt ON psp.pricing_type_id = pt.id
WHERE psp.provider_service_id = 'ps-budi-bersih-id'
ORDER BY pt.name;
```

---

## Alur Data: Saat Customer Membuat Order

### Langkah 1: Pilih Kategori

```
Customer membuka app → melihat daftar kategori

API: GET /api/services/categories

Response:
[
  { "id": "cat-001", "name": "Rumah Tangga", "icon_url": "household.png" },
  { "id": "cat-002", "name": "Renovasi", "icon_url": "renovation.png" },
  ...
]
```

### Langkah 2: Pilih Layanan dalam Kategori

```
Customer memilih "Rumah Tangga" → melihat daftar layanan

API: GET /api/services/categories/:categoryId

Response:
{
  "category": { "id": "cat-001", "name": "Rumah Tangga" },
  "services": [
    { "id": "svc-001", "name": "Bersih-bersih", "description": "..." },
    { "id": "svc-002", "name": "Plumbing", "description": "..." },
    ...
  ]
}
```

### Langkah 3: Cari Provider untuk Layanan

```
Customer memilih "Bersih-bersih" → sistem mencari provider terdekat

API: GET /api/services/services/providers
     ?service_id=svc-001
     &latitude=-6.8241
     &longitude=116.4074
     &radius=5000

Internal Query:
  1. Cari provider yang menawarkan layanan ini (provider_services)
  2. Filter yang terverifikasi dan aktif (provider_profiles)
  3. Hitung jarak dari lokasi customer (provider_locations + PostGIS)
  4. Urutkan berdasarkan jarak + rating

Response:
[
  {
    "provider_id": "prov-budi",
    "full_name": "Budi Santoso",
    "rating": 4.8,
    "total_jobs": 127,
    "distance_km": 1.2,
    "services": [
      { "service_id": "svc-001", "name": "Bersih-bersih" }
    ]
  },
  ...
]
```

### Langkah 4: Pilih Provider → Lihat Opsi Harga

```
Customer memilih "Budi Santoso" untuk layanan "Bersih-bersih"
→ melihat opsi pricing yang tersedia

API: GET /api/services/services/:providerId/:serviceId/options

Internal Query:
  1. Dapatkan provider_service record (provider_services)
  2. Dapatkan semua opsi harga (provider_service_prices + pricing_types)

Response:
{
  "provider": {
    "id": "prov-budi",
    "full_name": "Budi Santoso",
    "rating": 4.8
  },
  "service": {
    "id": "svc-001",
    "name": "Bersih-bersih"
  },
  "pricing_options": [
    {
      "pricing_type_id": "pt-001",
      "pricing_type_name": "Per Hari",
      "price": 200000,
      "unit": "hari"
    },
    {
      "pricing_type_id": "pt-002",
      "pricing_type_name": "Per Meter Persegi",
      "price": 5000,
      "unit": "m²"
    }
  ]
}
```

### Langkah 5: Pilih Pricing Type → Isi Detail

```
Customer memilih "Per Hari" → harga Rp 200.000/hari
Customer mengisi:
  - Jumlah hari: 1
  - Tanggal kerja: 2024-01-15
  - Catatan: "Rumah 2 lantai, ada 3 kamar tidur"
```

### Langkah 6: Buat Order

```
Customer menekan "Pesan Sekarang"

API: POST /api/orders/orders

Payload:
{
  "provider_id": "prov-budi",
  "items": [
    {
      "service_id": "svc-001",
      "pricing_type_id": "pt-001",
      "quantity": 1,
      "price": 200000
    }
  ],
  "work_date": "2024-01-15",
  "description": "Rumah 2 lantai, ada 3 kamar tidur",
  "location": {
    "latitude": -6.8241,
    "longitude": 116.4074,
    "address": "Jl. Sudirman No. 123"
  }
}

Internal Process:
  1. Validasi: Provider masih aktif? Harga masih sesuai?
  2. Insert ke orders (status: pending)
  3. Insert ke order_items (snapshot harga)
  4. Insert ke order_locations
  5. Buat provider_schedules (is_booked = true)
  6. Kirim notifikasi ke provider (FCM)
  7. Response: { "order_id": "ord-xxx", "status": "pending" }
```

---

## Query Penting

### 1. Cari Provider Terdekat untuk Layanan Tertentu

```sql
-- Query utama untuk pencarian provider
SELECT 
  pp.id AS provider_id,
  pp.full_name,
  pp.rating,
  pp.total_jobs,
  pp.profile_photo,
  ST_Distance(
    pl.location::geography,
    ST_SetSRID(ST_MakePoint(:longitude, :latitude), 4326)::geography
  ) / 1000 AS distance_km
FROM provider_services ps
JOIN provider_profiles pp ON ps.provider_id = pp.id
JOIN provider_locations pl ON pp.user_id = pl.provider_id
WHERE ps.service_id = :service_id
  AND pp.is_verified = true
  AND pp.is_active = true
  AND pp.service_available = true
  AND ST_DWithin(
    pl.location::geography,
    ST_SetSRID(ST_MakePoint(:longitude, :latitude), 4326)::geography,
    :radius_meters
  )
ORDER BY distance_km ASC, pp.rating DESC
LIMIT :limit;
```

### 2. Tampilkan Semua Opsi Harga untuk Layanan Provider

```sql
SELECT 
  pt.name AS pricing_type_name,
  pt.default_unit,
  psp.price,
  COALESCE(psp.unit, pt.default_unit) AS effective_unit
FROM provider_service_prices psp
JOIN pricing_types pt ON psp.pricing_type_id = pt.id
WHERE psp.provider_service_id = :provider_service_id
ORDER BY pt.name;
```

### 3. Dashboard Admin: Statistik Layanan

```sql
-- Jumlah provider per layanan
SELECT 
  s.name AS service_name,
  c.name AS category_name,
  COUNT(DISTINCT ps.provider_id) AS provider_count
FROM services s
JOIN categories c ON s.category_id = c.id
LEFT JOIN provider_services ps ON s.id = ps.service_id
GROUP BY s.id, s.name, c.name
ORDER BY provider_count DESC;
```

---

## Pertimbangan Desain

### 1. Menambah Layanan Baru

```
Admin menambah layanan baru:
  1. INSERT ke categories (jika kategori baru)
  2. INSERT ke services (layanan baru)
  3. (Opsional) INSERT ke pricing_types (jika jenis pricing baru)
  4. Provider mendaftarkan diri → INSERT ke provider_services
  5. Provider mengatur harga → INSERT ke provider_service_prices
```

### 2. Mengubah Harga

```
Provider mengubah harga:
  1. UPDATE provider_service_prices SET price = :new_price
     WHERE provider_service_id = :id AND pricing_type_id = :pt_id;
  2. Order LAMA tidak terpengaruh (harga sudah di-snapshot di order_items)
  3. Order BARU akan menggunakan harga baru
```

### 3. Menghapus Layanan

```
Menghapus layanan yang sudah ada order:
  - TIDAK BISA hapus dari services (ON DELETE NoAction dari orders)
  - Alternatif: Set flag `is_active` atau soft delete
  - Provider bisa nonaktifkan layanan (UPDATE provider_services)
```

### 4. Menambah Jenis Pricing Baru

```
Admin menambah jenis pricing:
  1. INSERT ke pricing_types (nama, deskripsi, default_unit)
  2. Jika spesifik kategori: set category_id
  3. Jika global: category_id = NULL
  4. Provider bisa langsung menambahkan opsi harga baru ke layanan mereka
```

---

## Statistik Domain

| Metrik | Nilai |
|---|---|
| Jumlah tabel | 5 |
| Jumlah relasi | 6 |
| Unique constraints | 2 (provider_services, provider_service_prices) |
| Foreign keys | 6 |
| Index | 6 |
| Nullable columns | 2 (pricing_types.category_id, provider_services.description) |
| Kolom dengan default | 3 (services.created_at, pricing_types —, provider_services.created_at) |

---

## Ringkasan: Alur Data Lengkap

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        ALUR DATA KATALOG LAYANAN                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ADMIN                     PROVIDER                   CUSTOMER          │
│    │                          │                          │              │
│    ├─ Buat kategori ──▶ categories                      │              │
│    ├─ Buat layanan ──▶ services                         │              │
│    ├─ Buat pricing type ──▶ pricing_types               │              │
│    │                          │                          │              │
│    │                    Daftar layanan ──▶ provider_services            │
│    │                    Atur harga ──▶ provider_service_prices          │
│    │                          │                          │              │
│    │                          │                    Pilih kategori        │
│    │                          │                    GET /categories       │
│    │                          │                          │              │
│    │                          │                    Pilih layanan         │
│    │                          │                    GET /categories/:id   │
│    │                          │                          │              │
│    │                          │                    Cari provider         │
│    │                          │                    GET /services/        │
│    │                          │                    providers             │
│    │                          │                          │              │
│    │                          │                    Pilih provider        │
│    │                          │                    Lihat opsi harga      │
│    │                          │                    GET /services/:id/:   │
│    │                          │                    serviceId/options     │
│    │                          │                          │              │
│    │                          │                    Pilih pricing type    │
│    │                          │                    Buat order            │
│    │                          │                    POST /orders          │
│    │                          │                          │              │
│    │                          │                    order_items dibuat    │
│    │                          │                    (snapshot harga)      │
│    │                          │                          │              │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Kesimpulan

Desain domain katalog layanan Jasaku mengikuti prinsip:

1. **Normalisasi**: Setiap entitas punya tabel sendiri — tidak ada duplikasi data.
2. **Reusable Components**: Pricing types bisa dipakai oleh layanan/kategori mana pun.
3. **Multi-Pricing**: Dua tabel junction memungkinkan satu layanan punya banyak opsi harga.
4. **Price Snapshots**: Harga order di-snapshot untuk menjaga integritas data historis.
5. **Geospasial Search**: Integrasi PostGIS untuk pencarian provider terdekat.
6. **Flexibility**: `category_id` opsional di `pricing_types` memungkinkan pricing global maupun spesifik kategori.
