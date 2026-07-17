# Potensi Error & Masalah Database

> Dokumentasi komprehensif semua potensi error, race condition, dan masalah yang teridentifikasi di database Jasaku.
> Tiap masalah mencakup: level risiko, deskripsi, kapan terjadi, solusi, dan status mitigasi.
> Terakhir diperbarui: Juli 2026

---

## Daftar Isi

1. [Double-Booking Race Condition](#1-double-booking-race-condition)
2. [Order Status Race Condition](#2-order-status-race-condition)
3. [Payment Proof URL Validation](#3-payment-proof-url-validation)
4. [Custom Task Expiry Race Condition](#4-custom-task-expiry-race-condition)
5. [Rating Calculation Consistency](#5-rating-calculation-consistency)
6. [Provider Schedule Cleanup](#6-provider-schedule-cleanup)
7. [Payment Amount Consistency](#7-payment-amount-consistency)
8. [PostgreSQL Array Query Limitation](#8-postgresql-array-query-limitation)
9. [DECIMAL Precision untuk Extension Fee](#9-decimal-precision-untuk-extension-fee)
10. [Missing Foreign Key Indexes](#10-missing-foreign-key-indexes)
11. [Tidak Ada CHECK Constraint untuk Status](#11-tidak-ada-check-constraint-untuk-status)
12. [Large JSONB Columns](#12-large-jsonb-columns)

---

## 1. Double-Booking Race Condition

**Level: SEDANG**

### Deskripsi

Dua request hampir bersamaan bisa melewati pengecekan `provider_schedules` sebelum yang pertama selesai commit. Ini menciptakan situasi di mana satu provider menerima dua order untuk tanggal yang sama.

### Kapan Terjadi

Saat customer membuat order pada waktu yang bersamaan untuk provider yang sama di tanggal yang sama.

**Timeline Race Condition:**

```
Time    Customer A                    Customer B
-----   -------------------------    -------------------------
T1      SELECT FROM provider_         (idle)
        schedules WHERE
        provider_id = X
        AND work_date = Y
        -> hasil: 0 baris (kosong)

T2      (idle)                        SELECT FROM provider_schedules
                                       WHERE provider_id = X
                                       AND work_date = Y
                                       -> hasil: 0 baris (kosong)

T3      INSERT INTO provider_         (idle)
        schedules ...

T4      COMMIT                        INSERT INTO provider_schedules ...
                                       -> GAGAL! Unique constraint violation

T5      (berhasil)                    ROLLBACK (atau error handling)
```

### Solusi

**Sudah diimplementasi**: Unique constraint `(provider_id, work_date)` di `provider_schedules` secara otomatis menolak insert kedua. Database akan mengembalikan error `unique_violation` yang bisa ditangani oleh backend.

```sql
-- Unique constraint yang sudah ada
UNIQUE(provider_id, work_date)
```

**Peningkatan yang mungkin diperlukan**:
- Gunakan `SELECT ... FOR UPDATE` dalam transaction untuk mengunci baris sebelum insert
- Gunakan `INSERT ... ON CONFLICT DO NOTHING` untuk pendekatan yang lebih clean
- Tampilkan pesan error yang user-friendly ke customer ("Provider sudah tidak tersedia di tanggal ini")

### Status: MITIGATED

Unique constraint mencegah double insert, tapi error message mungkin kurang user-friendly jika tidak di-handle dengan baik di backend.

### Lokasi Terkait

- `schema.prisma:232-233` — `@@unique([provider_id, work_date])`
- `jasaku_ddl.sql:246` — `UNIQUE(provider_id, work_date)`

---

## 2. Order Status Race Condition

**Level: SEDANG**

### Deskripsi

Dua provider bisa mencoba accept order yang sama secara bersamaan. Order status harus transisi dari `pending` ke `accepted` secara atomic.

### Kapan Terjadi

Saat dua provider klik tombol "Accept" hampir bersamaan untuk order yang sama.

**Timeline Race Condition:**

```
Time    Provider A                    Provider B
-----   -------------------------    -------------------------
T1      UPDATE orders SET             (idle)
        status = 'accepted'
        WHERE id = X
        AND status = 'pending'
        -> 1 row affected

T2      COMMIT                        UPDATE orders SET
                                       status = 'accepted'
                                       WHERE id = X
                                       AND status = 'pending'
                                       -> 0 rows affected (sudah 'accepted')

T3      (berhasil)                    (gagal - order sudah diambil)
```

### Solusi

**Sudah diimplementasi**: Atomic `updateMany` dengan WHERE clause `status = 'pending'` di `orders.service.ts`. Hanya satu provider yang berhasil update (mendapat 1 row affected), provider lain mendapat 0 row affected.

```typescript
// Contoh implementasi di orders.service.ts
const result = await prisma.orders.updateMany({
  where: {
    id: orderId,
    status: 'pending'  // Cek status masih pending
  },
  data: {
    status: 'accepted',
    provider_id: currentProviderId
  }
});

if (result.count === 0) {
  // Order sudah diambil provider lain
  throw new ConflictException('Order sudah diterima provider lain');
}
```

**Peningkatan yang mungkin diperlukan**:
- Gunakan `SELECT ... FOR UPDATE` untuk mengunci baris order sebelum update
- Tambahkan logging untuk audit trail siapa yang accept kapan

### Status: MITIGATED

Sudah pakai atomic `updateMany` yang memastikan hanya satu provider yang berhasil accept.

### Lokasi Terkait

- `jasaku-backend/src/modules/orders/orders.service.ts` — logic accept order

---

## 3. Payment Proof URL Validation

**Level: RENDAH**

### Deskripsi

Kolom `payment_proof` di tabel `payments` dan `custom_tasks` disimpan sebagai `TEXT`. Tidak ada validasi format URL di database level.

### Kapan Terjadi

Jika client mengirim string yang bukan URL valid (misal: `"bukan url"`, `"<script>alert(1)</script>"`, atau string kosong).

### Risiko

- **XSS**: Jika URL ditampilkan di frontend tanpa sanitasi, script berbahaya bisa di-inject
- **Broken UI**: Gambar/bukti tidak bisa ditampilkan karena URL tidak valid
- **Storage waste**: String acak memakan storage tanpa manfaat

### Solusi

**Sudah diimplementasi**: Validasi URL di application layer (backend). Backend memastikan `payment_proof` adalah URL valid sebelum disimpan ke database.

```typescript
// Validasi di backend (contoh)
if (paymentProof && !isValidUrl(paymentProof)) {
  throw new BadRequestException('Payment proof harus berupa URL valid');
}
```

**Peningkatan yang mungkin diperlukan**:
- Tambahkan CHECK constraint di database: `CHECK (payment_proof ~* '^https?://.*')`
- Validasi URL harus mengarah ke domain yang trusted (Supabase storage, Cloudinary, dll)
- Batasi ukuran URL (misal: max 2048 karakter)

### Status: MITIGATED

Backend validation ada, tapi tidak ada defense-in-depth di database level.

### Lokasi Terkait

- `payments.payment_proof TEXT` — `schema.prisma:181`
- `custom_tasks.payment_proof TEXT` — `schema.prisma:67`

---

## 4. Custom Task Expiry Race Condition

**Level: RENDAH**

### Deskripsi

Custom task expired berdasarkan cron job atau periodic check. Jika check terlambat (backend restart, delay, atau cron miss), task bisa masih "open" meskipun sudah lewat `expires_at`.

### Kapan Terjadi

Saat backend restart atau delay dalam menjalankan cron job. Task seharusnya expired tetapi masih muncul di daftar available tasks.

**Timeline:**

```
Time    Event
-----   ---------------------------
T1      Task expires_at = 2026-07-15 15:00:00
T2      Backend restart (15:05)
T3      Cron job terlambat (running 15:10)
T4      Selama T2-T3: task masih "open" meskipun expired
```

### Solusi

**Sudah diimplementasi**: Query `getAvailableTasks()` di backend selalu mengecek `expires_at` — hanya return task yang belum expired.

```typescript
// Query selalu filter expired
const availableTasks = await prisma.custom_tasks.findMany({
  where: {
    status: 'open',
    expires_at: {
      gt: new Date()  // Hanya task yang belum expired
    }
  }
});
```

**Peningkatan yang mungkin diperlukan**:
- Jalankan cron job lebih sering (setiap menit instead of setiap 5 menit)
- Tambahkan database trigger yang otomatis update status task saat `expires_at` terlewati
- Tambahkan index pada `(status, expires_at)` untuk query yang lebih cepat

### Status: MITIGATED

Query-level check memastikan task expired tidak ditampilkan, meskipun status di database belum diupdate.

### Lokasi Terkait

- `custom_tasks.expires_at` — `schema.prisma:66`
- `custom_tasks.status` — bisa berisi `"open"`, `"expired"`

---

## 5. Rating Calculation Consistency

**Level: SEDANG**

### Deskripsi

Rating di `provider_profiles.rating` dan `provider_profiles.total_reviews` dihitung dari tabel `reviews`. Jika review dihapus (atau order yang direview dihapus), rating tidak otomatis update.

### Kapan Terjadi

Saat admin menghapus review atau order yang sudah direview dihapus. Rating provider akan tetap tinggi meskipun review sudah tidak ada.

**Skenario:**

```
1. Provider A punya 10 review, rating 4.5
2. Admin menghapus 3 review yang rating rendah
3. Seharusnya rating naik ke 4.8, tapi tetap 4.5
4. Data tidak konsisten
```

### Solusi

**Belum diimplementasi secara penuh**. Saat ini:
- Review ditambahkan: rating di-recompute (sudah ada)
- Review dihapus: rating TIDAK di-recompute (belum ada fitur hapus review)

**Yang perlu ditambahkan**:

```typescript
// Saat review ditambah/dihapus, recompute rating
async function recomputeProviderRating(providerId: string) {
  const result = await prisma.reviews.aggregate({
    where: { provider_id: providerId },
    _avg: { rating: true },
    _count: { rating: true }
  });

  await prisma.provider_profiles.update({
    where: { id: providerId },
    data: {
      rating: result._avg.rating ?? 0,
      total_reviews: result._count.rating
    }
  });
}
```

**Peningkatan yang mungkin diperlukan**:
- Panggil `recomputeProviderRating()` setiap kali review ditambah/dihapus
- Pertimbangkan scheduled job untuk recompute semua rating secara berkala
- Cache rating untuk performa (rating jarang berubah)

### Status: POTENSI ERROR

Saat ini tidak ada fitur hapus review, jadi masalah ini belum terjadi di production. Tapi jika fitur tersebut ditambahkan nanti, rating akan menjadi tidak konsisten.

### Lokasi Terkait

- `provider_profiles.rating DECIMAL(2,1)` — `schema.prisma:395`
- `provider_profiles.total_reviews INT` — `schema.prisma:399`
- `reviews` — `schema.prisma:422-434`

---

## 6. Provider Schedule Cleanup

**Level: RENDAH**

### Deskripsi

Tabel `provider_schedules` untuk order yang dibatalkan tidak selalu di-cleanup. Jika order dibatalkan, schedule harus di-set `is_booked = false` dan `order_id = null`.

### Kapan Terjadi

Saat order cancelled oleh customer atau provider, schedule harus dikembalikan ke status "available".

**Skenario:**

```
1. Provider A booking tanggal 15 Juli
2. Customer cancel order
3. provider_schedules masih: is_booked = true, order_id = X
4. Tanggal 15 Juli terlihat "booked" meskipun order sudah cancelled
5. Customer lain tidak bisa pilih provider A di tanggal tersebut
```

### Solusi

**Sudah diimplementasi**: Fungsi `cancelOrder()` di backend sudah menangani cleanup:

```typescript
// Di cancelOrder()
await prisma.provider_schedules.updateMany({
  where: { order_id: orderId },
  data: {
    is_booked: false,
    order_id: null
  }
});
```

**Peningkatan yang mungkin diperlukan**:
- Pastikan semua path cancel order (customer cancel, provider reject, admin cancel) melakukan cleanup
- Tambahkan cron job untuk cleanup schedule yang orphaned (order_id menunjuk order yang sudah tidak ada)
- Tambahkan constraint: `CHECK (is_booked = false OR order_id IS NOT NULL)`

### Status: MITIGATED

Sudah dihandle di `cancelOrder()`, tapi perlu dipastikan semua cancel path melakukan cleanup.

### Lokasi Terkait

- `provider_schedules.is_booked` — `schema.prisma:226`
- `provider_schedules.order_id` — `schema.prisma:227`

---

## 7. Payment Amount Consistency

**Level: SEDANG**

### Deskripsi

`payments.amount` harus sama dengan `orders.total_price + orders.platform_fee + orders.additional_fee`. Tidak ada CHECK constraint di database yang memastikan konsistensi ini.

### Kapan Terjadi

Jika ada bug di application layer yang menghitung jumlah pembayaran salah, atau jika ada direct database manipulation.

**Skenario:**

```
1. Order: total_price = 100000, platform_fee = 5000, additional_fee = 0
2. Seharusnya: payment amount = 105000
3. Bug di backend: payment amount = 100000 (lupa platform_fee)
4. Provider kehilangan 5000 (platform fee tidak terbayar)
```

### Solusi

**Belum diimplementasi** di database level. Validasi hanya di application layer:

```typescript
// Validasi di backend (contoh)
const expectedAmount = order.total_price
  + order.platform_fee
  + order.additional_fee;

if (payment.amount !== expectedAmount) {
  throw new BadRequestException(
    'Jumlah pembayaran tidak sesuai'
  );
}
```

**Peningkatan yang mungkin diperlukan**:
- Gunakan trigger PostgreSQL untuk validasi saat insert/update payments
- Audit secara berkala: `SELECT o.id, o.total_price + o.platform_fee + o.additional_fee AS expected, p.amount FROM orders o JOIN payments p ON o.id = p.order_id WHERE o.total_price + o.platform_fee + o.additional_fee != p.amount`
- Pertimbangkan generated column di orders untuk menyimpan total yang diharapkan

### Status: POTENSI ERROR

Saat ini reliance pada application layer. Jika ada bug, jumlah pembayaran bisa salah tanpa deteksi di database.

### Lokasi Terkait

- `payments.amount DECIMAL(12,2)` — `schema.prisma:178`
- `orders.total_price DECIMAL(12,2)` — `schema.prisma:148`
- `orders.platform_fee DECIMAL(12,2)` — `schema.prisma:149`
- `orders.additional_fee DECIMAL(12,2)` — `schema.prisma:150`

---

## 8. PostgreSQL Array Query Limitation

**Level: RENDAH**

### Deskripsi

Beberapa tabel menggunakan PostgreSQL array (`TEXT[]`) untuk menyimpan data multi-value:
- `provider_profiles.portfolios` — daftar URL portofolio
- `reports.attachments` — daftar URL lampiran

Array tidak bisa di-query dengan efisien seperti tabel terpisah.

### Kapan Terjadi

Saat perlu query "find all reports dengan attachment tertentu" atau "find all providers dengan portfolio tertentu".

**Contoh query yang tidak efisien:**

```sql
-- Tidak bisa pakai index dengan efisien
SELECT * FROM reports
WHERE 'https://example.com/file.jpg' = ANY(attachments);

-- Tidak bisa JOIN
SELECT * FROM reports r
JOIN ??? ON r.attachments = ???.url;  -- Tidak ada cara
```

### Solusi

**Accepted trade-off**. Untuk use case saat ini (display only), array cukup:
- `portfolios` hanya ditampilkan di profil provider, tidak perlu di-query
- `attachments` di reports hanya ditampilkan di admin dashboard, tidak perlu di-query

**Peningkatan yang mungkin diperlukan** (jika diperlukan di masa depan):

```sql
-- Jika perlu query attachments, buat tabel terpisah
CREATE TABLE report_attachments (
    id UUID PRIMARY KEY,
    report_id UUID REFERENCES reports(id),
    file_url TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);
```

### Status: ACCEPTED

Trade-off yang disadari. Saat ini tidak ada kebutuhan query pada array columns.

### Lokasi Terkait

- `provider_profiles.portfolios TEXT[]` — `schema.prisma:400`
- `reports.attachments TEXT[]` — `schema.prisma:267`

---

## 9. DECIMAL Precision untuk Extension Fee

**Level: RENDAH**

### Deskripsi

Extension fee dihitung sebagai 2% per hari dari `total_price`, dengan maksimum 5%. Kalkulasi percentage pada DECIMAL bisa menghasilkan pembulatan yang sedikit berbeda.

### Kapan Terjadi

Saat menghitung biaya ekstensi untuk order dengan harga tertentu.

**Contoh:**

```
total_price = 100000
2% per hari = 2000
5% maksimum = 5000

Hari 1: 2000 (benar)
Hari 2: 4000 (benar)
Hari 3: 6000 -> harusnya 5000 (max 5%)

Pembulatan desimal:
total_price = 33333
2% = 666.66 (harusnya 666.66)
Dalam DECIMAL(12,2): 666.66 (benar, presisi 2 desimal)
```

### Solusi

**Sudah diimplementasi**: Gunakan `ROUND()` di query atau application layer untuk memastikan konsistensi pembulatan.

```typescript
// Contoh kalkulasi extension fee
const dailyRate = 0.02; // 2%
const maxRate = 0.05;   // 5%
const days = Math.min(extensionDays, Math.ceil(maxRate / dailyRate));
const fee = Math.min(
  totalPrice * dailyRate * days,
  totalPrice * maxRate
);
const roundedFee = Math.round(fee * 100) / 100; // 2 desimal
```

**Peningkatan yang mungkin diperlukan**:
- Pastikan `ROUND()` selalu dipanggil untuk konsistensi
- Pertimbangkan CHECK constraint: `CHECK (additional_fee >= 0 AND additional_fee <= total_price * 0.05)`
- Audit kalkulasi secara berkala

### Status: ACCEPTED

Pembulatan ke 2 desimal sudah acceptable untuk monetary values.

### Lokasi Terkait

- `orders.additional_fee DECIMAL(12,2)` — `schema.prisma:150`
- `order_extensions.additional_cost DECIMAL(12,2)` — `schema.prisma:286`
- `order_extensions.platform_fee_rate DECIMAL(3,2)` — `schema.prisma:287`

---

## 10. Missing Foreign Key Indexes

**Level: RENDAH**

### Deskripsi

Beberapa foreign key columns tidak punya index explicit. Prisma tidak otomatis membuat index untuk foreign keys (berbeda dengan beberapa ORM lain).

### Kapan Terjadi

Saat query performance menurun di scale besar. JOIN tanpa index pada foreign key akan melakukan sequential scan.

**Tabel yang belum punya explicit FK index:**

| Tabel | FK Column | Status |
|-------|-----------|--------|
| `orders` | `customer_id` | Sudah ada idx |
| `orders` | `provider_id` | Sudah ada idx |
| `orders` | `custom_task_id` | Belum ada idx |
| `orders` | `task_provider_id` | Belum ada idx |
| `payments` | `order_id` | Sudah ada idx |
| `order_items` | `order_id` | Sudah ada idx |
| `order_items` | `service_id` | Belum ada idx |
| `order_items` | `pricing_type_id` | Belum ada idx |
| `order_locations` | `order_id` | Sudah ada idx |
| `order_attachments` | `order_id` | Sudah ada idx |
| `reviews` | `customer_id` | Sudah ada idx |
| `reviews` | `provider_id` | Sudah ada idx |
| `custom_tasks` | `customer_id` | Sudah ada idx |
| `task_providers` | `provider_id` | Sudah ada idx |
| `provider_services` | `provider_id` | Sudah ada idx |
| `provider_services` | `service_id` | Belum ada idx |

### Solusi

**Monitoring query performance**. Jika query tertentu mulai lambat, tambahkan index secara manual:

```sql
-- Contoh index yang mungkin diperlukan di masa depan
CREATE INDEX idx_orders_custom_task_id ON orders(custom_task_id);
CREATE INDEX idx_orders_task_provider_id ON orders(task_provider_id);
CREATE INDEX idx_order_items_service_id ON order_items(service_id);
CREATE INDEX idx_order_items_pricing_type_id ON order_items(pricing_type_id);
CREATE INDEX idx_provider_services_service_id ON provider_services(service_id);
```

**Cara monitor:**
- Jalankan `EXPLAIN ANALYZE` pada query yang mencurigakan
- Cari sequential scan pada tabel besar
- Cek `pg_stat_user_indexes` untuk melihat index usage

### Status: ACCEPTED

Premature optimization untuk scale saat ini. Database masih relatif kecil (< 1 juta baris di semua tabel).

### Lokasi Terkait

- `jasaku_ddl.sql:420-461` — daftar index yang sudah ada

---

## 11. Tidak Ada CHECK Constraint untuk Status

**Level: SEDANG**

### Deskripsi

Status columns (`orders.status`, `payments.status`, `custom_tasks.status`, `task_providers.status`, dll) menggunakan `VARCHAR` tanpa CHECK constraint. Application layer harus memastikan value valid.

### Kapan Terjadi

Jika ada bug yang mengirim status invalid, atau ada direct database manipulation dengan status yang tidak dikenal.

**Status values yang diharapkan:**

| Tabel | Kolom | Values Valid |
|-------|-------|-------------|
| `orders` | `status` | `pending`, `accepted`, `in_progress`, `completed`, `cancelled`, `expired` |
| `payments` | `status` | `pending`, `paid`, `verified`, `rejected` |
| `custom_tasks` | `status` | `open`, `in_progress`, `active`, `completed`, `fulfilled`, `expired`, `cancelled` |
| `custom_tasks` | `payment_status` | `unpaid`, `proof_uploaded`, `paid` |
| `task_providers` | `status` | `accepted`, `completed` |
| `task_providers` | `work_status` | `null`, `on_the_way`, `arrived`, `in_progress`, `completed` |
| `order_extensions` | `status` | `pending`, `approved`, `rejected` |
| `reports` | `status` | `open`, `in_progress`, `resolved`, `closed` |
| `identity_verifications` | `face_match_status` | `pending`, `matched`, `not_matched` |
| `identity_verifications` | `liveness_status` | `pending`, `passed`, `failed` |

### Solusi

**Sudah diimplementasi di application layer**: Validasi transisi status di backend menggunakan `VALID_TRANSITIONS` map di `orders.service.ts`.

```typescript
// Contoh validasi transisi status
const VALID_TRANSITIONS: Record<string, string[]> = {
  'pending': ['accepted', 'cancelled'],
  'accepted': ['in_progress', 'cancelled'],
  'in_progress': ['completed'],
  'completed': [],
  'cancelled': [],
};
```

**Peningkatan yang mungkin diperlukan** — CHECK constraint di database:

```sql
-- Contoh CHECK constraint untuk orders.status
ALTER TABLE orders ADD CONSTRAINT chk_orders_status
CHECK (status IN (
  'pending', 'accepted', 'in_progress',
  'completed', 'cancelled', 'expired'
));

-- Contoh CHECK constraint untuk payments.status
ALTER TABLE payments ADD CONSTRAINT chk_payments_status
CHECK (status IN (
  'pending', 'paid', 'verified', 'rejected'
));
```

**Manfaat CHECK constraint:**
- Database langsung menolak status invalid, regardless of application bugs
- Dokumentasi eksplisit di database tentang values yang valid
- Mencegah data corrupt dari direct database manipulation

### Status: POTENSI ERROR

Saat ini reliance pada application layer. Jika ada bug yang bypass validasi backend, status invalid bisa masuk ke database.

### Lokasi Terkait

- `orders.status VARCHAR(30)` — `schema.prisma:147`
- `payments.status VARCHAR(30)` — `schema.prisma:177`
- `custom_tasks.status VARCHAR(30)` — `schema.prisma:70`
- `jasaku-backend/src/modules/orders/orders.service.ts` — VALID_TRANSITIONS map

---

## 12. Large JSONB Columns

**Level: RENDAH**

### Deskripsi

Kolom `ocr_raw_result` dan `liveness_data` di tabel `identity_verifications` bisa sangat besar. Data OCR dari provider bisa berisi ratusan field JSON dengan nested objects.

### Kapan Terjadi

Jika OCR provider mengembalikan data sangat detail, atau jika liveness check mengembalikan metadata lengkap.

**Contoh ukuran:**
- OCR KTP: ~2-5 KB per scan
- OCR selfie: ~1-3 KB per scan
- Liveness data: ~5-10 KB per check
- Total per verifikasi: ~10-20 KB

### Dampak

- **Storage**: Jika ada 1000 provider, total ~10-20 MB untuk JSONB columns saja
- **Query performance**: Query yang tidak menggunakan `->` atau `->>` operator akan memindahkan seluruh JSONB
- **Backup**: Backup size meningkat signifikan
- **Replication**: Replication ke standby server membutuhkan lebih banyak bandwidth

### Solusi

**Sudah diimplementasi**: Batasi ukuran di application layer.

```typescript
// Batasi ukuran OCR result
if (JSON.stringify(ocrResult).length > 50000) { // 50 KB
  throw new BadRequestException('OCR result terlalu besar');
}
```

**Peningkatan yang mungkin diperlukan**:
- Pertimbangkan kompresi JSONB (PostgreSQL sudah otomatis kompresi, tapi bisa lebih aggressive)
- Gunakan TOAST storage (PostgreSQL otomatis memindahkan kolom besar ke TOAST)
- Pertimbangkan arsitektur event sourcing untuk data OCR (simpan di object storage, reference di DB)

### Status: ACCEPTED

Ukuran saat ini masih dalam batas wajar. Monitoring diperlukan seiring pertumbuhan data.

### Lokasi Terkait

- `identity_verifications.ocr_raw_result JSONB` — `schema.prisma:447`
- `identity_verifications.liveness_data JSONB` — `schema.prisma:450`

---

## Ringkasan Potensi Error

| # | Masalah | Level | Status |
|---|---------|-------|--------|
| 1 | Double-booking race condition | SEDANG | MITIGATED |
| 2 | Order status race condition | SEDANG | MITIGATED |
| 3 | Payment proof URL validation | RENDAH | MITIGATED |
| 4 | Custom task expiry race | RENDAH | MITIGATED |
| 5 | Rating calculation consistency | SEDANG | POTENSI ERROR |
| 6 | Provider schedule cleanup | RENDAH | MITIGATED |
| 7 | Payment amount consistency | SEDANG | POTENSI ERROR |
| 8 | PostgreSQL array query | RENDAH | ACCEPTED |
| 9 | DECIMAL precision | RENDAH | ACCEPTED |
| 10 | Missing FK indexes | RENDAH | ACCEPTED |
| 11 | No CHECK constraint on status | SEDANG | POTENSI ERROR |
| 12 | Large JSONB columns | RENDAH | ACCEPTED |

### Statistik

- **Total masalah teridentifikasi**: 12
- **SEDANG**: 5 (42%)
- **RENDAH**: 7 (58%)
- **MITIGATED**: 5 (42%)
- **POTENSI ERROR**: 3 (25%)
- **ACCEPTED**: 4 (33%)

### Prioritas Perbaikan

| Prioritas | Masalah | Tindakan |
|-----------|---------|----------|
| 1 | Rating calculation consistency | Implementasi recompute saat review dihapus |
| 2 | CHECK constraint untuk status | Tambahkan CHECK constraint untuk semua status columns |
| 3 | Payment amount consistency | Audit query + pertimbangkan trigger |
| 4 | Missing FK indexes | Monitor query performance, tambah jika diperlukan |
| 5 | Provider schedule cleanup | Pastikan semua cancel path melakukan cleanup |

---

## Referensi

- [09-design-decisions.md](./09-design-decisions.md) — Keputusan desain di balik database
- [00-database-overview.md](./00-database-overview.md) — Overview arsitektur database
- `jasaku_ddl.sql` — DDL statements untuk seluruh tabel
- `schema.prisma` — Prisma schema (source of truth)
