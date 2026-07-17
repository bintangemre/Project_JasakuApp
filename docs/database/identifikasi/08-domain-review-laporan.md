# Domain: Ulasan & Laporan

> Dokumentasi lengkap domain ulasan (reviews) dan laporan (reports) Jasaku — meliputi tabel, desain keputusan, dan alur operasional.

---

## Daftar Isi

1. [Tabel yang Terlibat](#1-tabel-yang-terlibat)
2. [Reviews (Ulasan)](#2-reviews-ulasan)
3. [Mengapa customer_id dan provider_id di reviews pakai users.id?](#3-mengapa-customer_id-dan-provider_id-di-reviews-pakai-usersid)
4. [Flow Review](#4-flow-review)
5. [Reports (Laporan)](#5-reports-laporan)
6. [Mengapa reports.order_id nullable?](#6-mengapa-reportsorder_id-nullable)
7. [Flow Laporan](#7-flow-laporan)
8. [Trade-off dan Pertimbangan Desain](#8-trade-off-dan-pertimbangan-desain)

---

## 1. Tabel yang Terlibat

| Tabel | Peran | Sifat |
|---|---|---|
| `reviews` | Ulasan dan rating dari customer untuk provider | One review per order |
| `reports` | Laporan dari customer atau provider ke admin | Bisa terkait order atau umum |

### ER Ringkas

```
reviews (1) ──> orders (1)          [unique: order_id]
reviews (N) ──> users (1)           [customer_id → users.id]
reviews (N) ──> users (1)           [provider_id → users.id]
reviews (N) ──> provider_profiles (0) [implicit: provider_id = users.id]

reports (N) ──> users (1)           [reporter_id → users.id]
reports (N) ──> orders? (0..1)      [order_id → orders.id, nullable]
```

---

## 2. Reviews (Ulasan)

### Struktur Tabel

```sql
CREATE TABLE reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID UNIQUE NOT NULL,     -- One review per order
    customer_id UUID NOT NULL,          -- users.id (bukan profiles_customer.id)
    provider_id UUID NOT NULL,          -- users.id (bukan provider_profiles.id)
    rating INT NOT NULL,                -- 1-5
    review TEXT,                        -- Optional text
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);
```

### Constraint Penting

| Constraint | Kolom | Penjelasan |
|---|---|---|
| `@@unique([order_id])` | `order_id` | Satu order hanya boleh punya satu review |
| `CHECK (rating >= 1 AND rating <= 5)` | `rating` | Rating harus antara 1-5 |
| `fk_review_customer` | `customer_id` → `users.id` | Customer yang review |
| `fk_review_provider` | `provider_id` → `users.id` | Provider yang di-review |
| `fk_review_order` | `order_id` → `orders.id` | Order yang di-review |

### Kolom Detail

| Kolom | Tipe | Nullable | Penjelasan |
|---|---|---|---|
| `id` | UUID | No | Primary key |
| `order_id` | UUID (FK, UNIQUE) | No | Order yang di-review — hanya 1 review per order |
| `customer_id` | UUID (FK) | No | ID user customer |
| `provider_id` | UUID (FK) | No | ID user provider |
| `rating` | INT | No | Rating 1-5 |
| `review` | TEXT | Ya | Teks ulasan (opsional) |
| `created_at` | TIMESTAMP | Ya | Waktu review dibuat |
| `updated_at` | TIMESTAMP | Ya | Waktu review terakhir diupdate |

### Kalkulasi Ulang Rating Provider

Setiap kali review baru dibuat, rating provider di-recompute:

```typescript
// reviews.service.ts:17-29
const agg = await prisma.reviews.aggregate({
    where: { provider_id: providerId },
    _avg: { rating: true },
    _count: true
});

await prisma.provider_profiles.update({
    where: { user_id: providerId },
    data: {
        rating: agg._avg.rating ?? 0,
        total_reviews: agg._count
    }
});
```

**Field yang diupdate di `provider_profiles`:**

| Field | Tipe | Penjelasan |
|---|---|---|
| `rating` | DECIMAL(2,1) | Rata-rata rating (0.0 - 5.0) |
| `total_reviews` | INT | Jumlah total review |

**Catatan:** `total_jobs` TIDAK diupdate saat review — hanya diupdate saat order selesai (`completed`).

---

## 3. Mengapa customer_id dan provider_id di reviews pakai users.id?

### Struktur Relasi

```
reviews.customer_id → users.id    (bukan profiles_customer.id)
reviews.provider_id → users.id    (bukan provider_profiles.id)
```

### Alasan

1. **Konsistensi identitas:** `users.id` adalah identitas universal di Jasaku. Semua role (customer, provider, admin) punya `users.id`. Review adalah tabel independen yang tidak spesifik untuk role tertentu.

2. **Flexibility:** Jika di masa depan ada role baru yang bisa review (misal: vendor, agen), tidak perlu ubah schema reviews. Cukup tambah role di `roles` table.

3. **JOIN yang lebih sederhana:**
   ```sql
   -- Untuk ambil nama customer yang review
   SELECT r.*, pc.full_name
   FROM reviews r
   JOIN users u ON r.customer_id = u.id
   JOIN profiles_customer pc ON u.id = pc.user_id
   ```

4. **Prisma relation:** Prisma mendefinisikan dua relasi ke `users`:
   ```prisma
   model reviews {
       users_reviews_customer_idTousers users @relation("reviews_customer_idTousers")
       users_reviews_provider_idTousers users @relation("reviews_provider_idTousers")
   }
   ```
   Ini memungkinkan query seperti:
   ```typescript
   prisma.reviews.findMany({
       select: {
           users_reviews_customer_idTousers: {
               select: { profiles_customer: { select: { full_name: true } } }
           }
       }
   })
   ```

### Trade-off

- **Kelebihan:** Identitas konsisten, flexible, query mudah.
- **Kekurangan:** JOIN lebih dalam (reviews → users → profiles_customer) dibandingkan langsung ke profiles_customer. Tapi perbedaan performanya minimal untuk ukuran data Jasaku.

---

## 4. Flow Review

### Siapa yang bisa review?

**Hanya customer** yang sudah menyelesaikan order.

### Kapan bisa review?

Setelah order status `completed` dan belum ada review sebelumnya (unique constraint pada `order_id`).

### Alur

```
1. Order selesai (status: completed)
   → Notifikasi ke customer: "Pesanan Anda telah selesai. Silakan beri rating."
   ↓
2. Customer buat review
   POST /api/reviews
   {
       orderId: "...",
       rating: 5,
       review: "Service sangat baik!"
   }
   ↓
3. Backend validasi
   - Order ada dan status: completed
   - customer_id cocok dengan customer order
   - Belum ada review untuk order ini (unique constraint)
   - Rating: 1-5
   ↓
4. Buat review record
   ↓
5. Recompute rating provider
   - AVG(rating) → provider_profiles.rating
   - COUNT(*) → provider_profiles.total_reviews
   ↓
6. Notifikasi ke provider
   "Review Baru" - "Anda mendapat review 5 bintang dari customer."
```

### Contoh Query

**Ambil semua review untuk provider tertentu:**

```typescript
// reviews.service.ts:43-67
const profile = await prisma.provider_profiles.findUnique({
    where: { id: providerId },
    select: { user_id: true }
});
const userId = profile?.user_id ?? providerId;

return await prisma.reviews.findMany({
    where: { provider_id: userId },
    select: {
        id: true,
        rating: true,
        review: true,
        created_at: true,
        users_reviews_customer_idTousers: {
            select: {
                id: true,
                profiles_customer: {
                    select: { full_name: true, avatar_url: true }
                }
            }
        }
    }
});
```

**Cek apakah order sudah di-review:**

```typescript
// reviews.service.ts:71-74
return await prisma.reviews.findUnique({
    where: { order_id: orderId }
});
```

### Batasan

- **Satu review per order** — tidak bisa review ulang
- **Hanya customer** — provider tidak bisa review customer
- **Rating wajib** — review text opsional

---

## 5. Reports (Laporan)

### Struktur Tabel

```sql
CREATE TABLE reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reporter_id UUID NOT NULL,          -- users.id
    reporter_role VARCHAR(20) NOT NULL, -- 'customer' atau 'provider'
    order_id UUID,                      -- Nullable
    subject VARCHAR(200) NOT NULL,      -- Judul laporan
    description TEXT NOT NULL,          -- Isi laporan
    attachments TEXT[] DEFAULT '{}',     -- PostgreSQL array of URLs
    status VARCHAR(20) DEFAULT 'open',  -- 'open', 'resolved', 'dismissed'
    admin_response TEXT,                -- Tanggapan admin
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    resolved_at TIMESTAMP               -- Kapan laporan diselesaikan
);
```

### Kolom Detail

| Kolom | Tipe | Nullable | Penjelasan |
|---|---|---|---|
| `id` | UUID | No | Primary key |
| `reporter_id` | UUID (FK) | No | User yang melapor |
| `reporter_role` | VARCHAR(20) | No | `customer` atau `provider` |
| `order_id` | UUID (FK) | Ya | Order terkait (opsional) |
| `subject` | VARCHAR(200) | No | Judul laporan |
| `description` | TEXT | No | Deskripsi detail |
| `attachments` | TEXT[] | Ya | Array URL lampiran |
| `status` | VARCHAR(20) | Ya | Status laporan |
| `admin_response` | TEXT | Ya | Tanggapan admin |
| `created_at` | TIMESTAMP | Ya | Waktu laporan dibuat |
| `updated_at` | TIMESTAMP | Ya | Waktu terakhir diupdate |
| `resolved_at` | TIMESTAMP | Ya | Waktu laporan diselesaikan |

### Status Laporan

| Status | Arti | Transisi ke |
|---|---|---|
| `open` | Laporan baru, menunggu tanggapan admin | `resolved`, `dismissed` |
| `resolved` | Laporan sudah ditanggapi admin | _(terminal)_ |
| `dismissed` | Laporan ditutup tanpa tindakan | _(terminal)_ |

### Index

```sql
@@index([reporter_id])
@@index([status])
```

**Mengapa index di `status`?** Admin sering query `WHERE status = 'open'` untuk melihat laporan baru.

### attachments (PostgreSQL array)

**Keputusan:** Gunakan PostgreSQL native array (`TEXT[]`), bukan tabel terpisah.

**Alasan:**
- Attachments hanya berisi **URL strings** — tidak perlu metadata tambahan (created_at, file_type).
- Jumlah attachment relatif sedikit (biasanya 1-3 file).
- PostgreSQL array mendukung query `WHERE attachments @> ARRAY['url']`.
- Lebih sederhana daripada tabel terpisah untuk data yang sederhana.

**Trade-off:**
- **Kelebihan:** Query sederhana, tidak perlu JOIN, cukup untuk kebutuhan saat ini.
- **Kekurangan:** Tidak bisa tambah metadata per attachment tanpa migrasi. Tidak ada foreign key constraint ke storage.

---

## 6. Mengapa reports.order_id nullable?

### Alasan

Laporan bisa tentang hal umum yang **tidak terkait order tertentu**:

| Jenis Laporan | order_id |
|---|---|
| "Provider tidak datang" | `orders.uuid` |
| "Aplikasi error" | `NULL` |
| "Saran fitur baru" | `NULL` |
| "Provider kasar" | `orders.uuid` |
| "Bug di halaman pembayaran" | `NULL` |
| "Minta refund" | `orders.uuid` |

### Query

**Semua laporan open:**
```sql
SELECT * FROM reports WHERE status = 'open' ORDER BY created_at DESC
```

**Laporan yang terkait order:**
```sql
SELECT * FROM reports WHERE order_id IS NOT NULL AND status = 'open'
```

**Laporan umum (tanpa order):**
```sql
SELECT * FROM reports WHERE order_id IS NULL AND status = 'open'
```

---

## 7. Flow Laporan

### Siapa yang bisa melapor?

- **Customer:** Melapor tentang provider, bug, saran, dll.
- **Provider:** Melapor tentang customer, bug, saran, dll.

### Alur

```
1. User buat laporan
   POST /api/reports
   {
       subject: "Provider tidak datang",
       description: "Provider tidak datang sesuai jadwal...",
       orderId: "...",    // optional
       attachments: ["url1", "url2"]  // optional
   }
   ↓
2. Backend buat report record
   → reports.status: 'open'
   ↓
3. Admin melihat laporan
   GET /api/admin/reports/open
   → Tampilkan semua laporan dengan status 'open'
   ↓
4. Admin tanggapi
   PATCH /api/admin/reports/:reportId/respond
   {
       response: "Kami sudah menghubungi provider...",
       status: "resolved"  // atau "dismissed"
   }
   ↓
5. Backend update laporan
   → reports.status: 'resolved'/'dismissed'
   → reports.admin_response: response
   → reports.resolved_at: NOW()
   ↓
6. Notifikasi ke pelapor
   "Laporan terselesaikan" - "Laporan '...' telah terselesaikan oleh admin."
   → type: 'REPORT_RESPONDED'
```

### Contoh Query Admin

**Daftar laporan open:**
```typescript
// admin.service.ts:419-427
return await prisma.reports.findMany({
    where: { status: 'open' },
    orderBy: { created_at: 'desc' },
    include: {
        users: { select: { id: true, email: true } }
    }
});
```

**Hitung laporan open (untuk badge notifikasi):**
```typescript
// admin.service.ts:645
prisma.reports.count({ where: { status: 'open' } })
```

---

## 8. Trade-off dan Pertimbangan Desain

### Reviews: Mengapa tidak ada "reply" dari provider?

**Saat ini:** Provider tidak bisa membalas review.

**Alasan:**
- MVP scope — fokus pada core functionality
- Reply bisa menambah kompleksitas (threading, notifikasi, moderasi)
- Di masa depan: tambah tabel `review_replies` atau kolom `provider_reply` di `reviews`

### Reviews: Mengapa rating di-recompute langsung?

**Keputusan:** Setiap review baru → langsung hitung ulang AVG dan UPDATE `provider_profiles.rating`.

**Alasan:**
- Rating provider harus selalu up-to-date untuk ditampilkan di pencarian
- Jumlah review per provider relatif sedikit (ratusan, bukan jutaan) — recompute tidak mahal
- Alternativ: materialized view atau cache — terlalu kompleks untuk MVP

**Trade-off:** Jika ada banyak concurrent reviews, bisa ada race condition. Tapi untuk ukuran Jasaku, ini acceptable.

### Reports: Mengapa PostgreSQL array untuk attachments?

**Keputusan:** `TEXT[]` bukan tabel terpisah.

**Alasan:**
- Attachments hanya URL strings — tidak perlu relasi atau constraint
- Jumlah sedikit (biasanya 1-3)
- Query sederhana: `WHERE attachments @> ARRAY['url']`

**Alternativ yang ditolak:**
- Tabel `report_attachments` — over-engineering untuk data sederhana
- JSON column — tidak bisa array-specific query

### Reports: Mengapa `reporter_role` ada?

**Keputusan:** Kolom `VARCHAR(20)` menyimpan role pelapor.

**Alasan:**
- Tidak perlu JOIN ke `users` + `roles` hanya untuk mengetahui siapa yang melapor
- Admin bisa filter: "Laporan dari provider" atau "Laporan dari customer"
- Mempercepat query admin panel

**Trade-off:** Redundansi data — `reporter_role` bisa disimpulkan dari `reporter_id → users → roles`. Tapi ini trade-off yang worth it untuk performa.

### Reports: Mengapa `resolved_at` terpisah dari `updated_at`?

**Keputusan:** Kolom terpisah untuk waktu penyelesaian.

**Alasan:**
- `updated_at` berubah setiap kali ada perubahan (termasuk minor)
- `resolved_at` spesifik untuk kapan laporan diselesaikan
- Admin bisa query: "Laporan yang diselesaikan dalam 24 jam terakhir"
- Analytics: average resolution time

### Potensi error

| Error | Kemungkinan | Dampak |
|---|---|---|
| Customer review order yang belum selesai | Rendah | Dicegah dengan validasi status |
| Double review | Rendah | Dicegah dengan unique constraint `order_id` |
| Laporan spam | Sedang | Admin perlu filter manual, bisa tambah rate limiting |
| Admin tidak tanggapi laporan | Sedang | Pelapor kecewa, bisa tambah SLA reminder |
| Review palsu | Rendah | Tidak ada mekanisme verifikasi saat ini |
