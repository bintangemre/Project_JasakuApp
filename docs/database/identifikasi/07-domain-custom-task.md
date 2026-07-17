# Domain: Custom Tasks

> Dokumentasi lengkap sistem custom tasks (tender/job posting) Jasaku — meliputi tabel, alur, dan perbedaan dengan order biasa.

---

## Daftar Isi

1. [Tabel yang Terlibat](#1-tabel-yang-terlibat)
2. [Mengapa Custom Task Berbeda dari Order?](#2-mengapa-custom-task-berbeda-dari-order)
3. [Relasi antara Custom Task dan Orders](#3-relasi-antara-custom-task-dan-orders)
4. [State Machine Custom Task](#4-state-machine-custom-task)
5. [Alur Lengkap Custom Task](#5-alur-lengkap-custom-task)
6. [Multi-Provider (Multi-Stop)](#6-multi-provider-multi-stop)
7. [Platform Fee Custom Task](#7-platform-fee-custom-task)
8. [Desain Keputusan](#8-desain-keputusan)

---

## 1. Tabel yang Terlibat

| Tabel | Peran | Relasi |
|---|---|---|
| `custom_tasks` | Tabel utama — "wadah" atau "tender" | — |
| `task_locations` | Lokasi multi-stop untuk task | `task_locations.task_id → custom_tasks.id` |
| `task_providers` | Provider yang menerima task | `task_providers.task_id → custom_tasks.id` |
| `orders` | Order per provider (dibuat otomatis) | `orders.custom_task_id → custom_tasks.id` |
| `payments` | Pembayaran per order | `payments.order_id → orders.id` |

### ER Ringkas

```
custom_tasks (1) ──< task_locations (N)     [multi-stop]
custom_tasks (1) ──< task_providers (N)     [provider yang accept]
custom_tasks (1) ──< orders (N)             [1 order per provider]
custom_tasks (N) ──> users (1)              [customer yang buat task]
task_providers (N) ──> provider_profiles (1)
task_providers (1) ──< orders (0..1)        [order dari task ini]
orders (N) ──> custom_tasks? (0..1)         [link ke task induk]
orders (N) ──> task_providers? (0..1)       [link ke relasi provider-task]
```

---

## 2. Mengapa Custom Task Berbeda dari Order?

### Perbandingan

| Aspek | Order Biasa | Custom Task |
|---|---|---|
| **Siapa yang pilih provider?** | Customer pilih langsung | Customer buat task, provider bid/accept |
| **Berapa provider?** | SATU provider | BISA lebih dari satu (`required_people`) |
| **Flow pembayaran** | Customer → Admin → Provider | Customer → Admin → Multiple Providers |
| **Platform fee** | Rp 2.000 flat | 5% dari budget_per_person |
| **Lokasi** | Satu lokasi | Bisa multi-stop (`task_locations`) |
| **Status tracking** | Di `orders.status` | Di `custom_tasks.status` + `task_providers.work_status` |

### Kapan pakai custom task?

- Customer butuh **banyak provider** sekaligus (misal: pindahan rumah, acara besar)
- Customer tidak yakin ingin memilih provider mana — biarkan provider yang bid
- Task butuh **multi-stop** (kunjungan ke beberapa lokasi)
- Customer ingin menentukan **budget sendiri** per provider

### Kapan pakai order biasa?

- Customer sudah tahu ingin provider mana
- Hanya butuh satu provider
- Flow lebih cepat dan sederhana

---

## 3. Relasi antara Custom Task dan Orders

### Mengapa orders juga terhubung ke custom_tasks?

Setiap provider yang diterima untuk custom task akan membuat **order terpisah**:

```sql
-- Saat provider accept task (custom-tasks.service.ts:435-448)
INSERT INTO orders (
    customer_id, provider_id, total_price, platform_fee,
    description, work_date, status, assignment_type,
    custom_task_id, task_provider_id
) VALUES (
    <customer_profile_id>, <provider_profile_id>,
    <budget + fee>, <fee>,
    <task_title>, CURRENT_DATE, 'pending_payment', 'custom_task',
    <task_id>, <task_provider_id>
);
```

**Kolom link:**
- `orders.custom_task_id → custom_tasks.id` — order ini berasal dari task mana
- `orders.task_provider_id → task_providers.id` — relasi provider-task yang spesifik

### Mengapa tidak gabung saja?

**Alasan:**
1. **Order adalah unit transaksi standar.** Semua logika pembayaran, status tracking, dan ekstensi waktu berjalan di level order.
2. **Custom task hanya "wadah"** — dia mengkoordinasi banyak provider, tapi setiap provider punya order sendiri-sendiri.
3. **Reuse kode:** Semua service yang handle order (payment confirmation, status transition, review) otomatis berfungsi untuk custom task order.
4. **Admin monitoring:** Admin bisa melihat semua order di satu tempat, termasuk yang dari custom task (dengan filter `assignment_type = 'custom_task'`).

### Query "Order dari custom task"

```sql
-- Ambil semua order dari custom task tertentu
SELECT o.*, tp.status as tp_status
FROM orders o
JOIN task_providers tp ON o.task_provider_id = tp.id
WHERE o.custom_task_id = ?
```

---

## 4. State Machine Custom Task

### Status Custom Tasks

| Status | Arti | Transisi ke |
|---|---|---|
| `open` | Task aktif, menunggu provider accept | `in_progress`, `cancelled`, `expired` |
| `in_progress` | Semua kuota terpenuhi, menunggu pembayaran | `active` |
| `active` | Pembayaran dikonfirmasi, provider bekerja | `completed` |
| `completed` | Semua provider selesai mengerjakan | `fulfilled` |
| `fulfilled` | Semua payout sudah dikonfirmasi admin | _(terminal)_ |
| `expired` | Waktu publish habis, tidak ada provider yang accept | _(terminal)_ |
| `cancelled` | Dibatalkan oleh customer | _(terminal)_ |

### Diagram Transisi

```
open ──→ in_progress ──→ active ──→ completed ──→ fulfilled
 │            │             │
 ↓            ↓             ↓
cancelled   expired       (loop: provider complete satu-satu)
```

### Work Status (per provider)

`task_providers.work_status` melacak progress individual provider:

```
null → on_the_way → arrived → in_progress → completed
```

| Work Status | Arti |
|---|---|
| `null` | Belum mulai kerja (menunggu pembayaran dikonfirmasi) |
| `on_the_way` | Provider dalam perjalanan |
| `arrived` | Provider sampai di lokasi |
| `in_progress` | Provider sedang mengerjakan |
| `completed` | Provider selesai mengerjakan |

### Payment Status Custom Task

| Status | Arti |
|---|---|
| `unpaid` | Belum ada bukti bayar |
| `proof_uploaded` | Customer sudah upload bukti bayar |
| `paid` | Admin sudah konfirmasi pembayaran |

---

## 5. Alur Lengkap Custom Task

### Langkah 1: Customer Membuat Task

```
POST /api/custom-tasks
{
    title: "Pindahan Rumah",
    description: "Butuh 2 orang untuk bantu pindah",
    budget_per_person: 150000,
    required_people: 2,
    address: "Jl. Sudirman No. 123",
    lat: -5.1234, lng: 115.5678,
    publish_days: 3,
    locations: [
        { label: "Rumah Lama", address: "Jl. Sudirman No. 123", lat: -5.1234, lng: 115.5678 },
        { label: "Rumah Baru", address: "Jl. Gatot Subroto No. 456", lat: -5.2345, lng: 115.6789 }
    ]
}
```

**Backend melakukan:**
1. Buat `custom_tasks` record (status: `open`)
2. Set `expires_at = now + publish_days × 24 jam`
3. Set lokasi utama via PostGIS: `ST_SetSRID(ST_MakePoint(lng, lat), 4326)`
4. Buat `task_locations` untuk setiap lokasi (multi-stop)
5. Kirim notifikasi ke provider dalam radius 20km

### Langkah 2: Provider Menerima Task

```
POST /api/custom-tasks/:taskId/accept
```

**Backend melakukan (dalam transaction):**
1. Validasi:
   - Task masih `open`
   - Kuota belum penuh (`accepted_count < required_people`)
   - Provider bukan customer yang sama
   - Provider belum accept task ini
2. Atomic increment `accepted_count`
3. Jika kuota penuh → set `custom_tasks.status = 'in_progress'`
4. Buat `task_providers` record (status: `accepted`)
5. Buat `orders` record (status: `pending_payment`, assignment_type: `custom_task`)
6. Buat `payments` record (method: `rekber`, status: `pending`)
7. Notifikasi customer: "Task Diterima Provider!"

### Langkah 3: Customer Bayar

```
Customer upload bukti bayar → custom_tasks.payment_status: 'proof_uploaded'
Admin konfirmasi → custom_tasks.payment_status: 'paid', status: 'active'
→ Semua orders: status → 'accepted'
→ Semua payments: status → 'paid'
→ Notifikasi ke semua provider: "Pembayaran Dikonfirmasi!"
```

### Langkah 4: Provider Kerjakan Task

Setiap provider mengupdate `work_status` secara individual:

```
Provider A: on_the_way → arrived → in_progress → completed
Provider B: on_the_way → arrived → in_progress → completed
```

**Saat provider selesai:**
1. `task_providers.status: 'completed'`
2. `task_providers.completed_at: NOW()`
3. `orders.status: 'completed'` (via `updateMany` di `custom-tasks.service.ts:537-540`)
4. `provider_profiles.total_jobs: +1`
5. Cek apakah semua provider selesai → jika ya: `custom_tasks.status: 'completed'`

### Langkah 5: Admin Konfirmasi Payout

```
Admin konfirmasi payout per provider:
→ task_providers.payout_confirmed: true
→ task_providers.payout_at: NOW()
→ Jika semua provider sudah payout confirmed:
  → custom_tasks.status: 'fulfilled'
```

---

## 6. Multi-Provider (Multi-Stop)

### Multi-Provider

Custom task bisa diterima oleh **banyak provider** sekaligus:

```
required_people: 3
accepted_count: 0 → 1 → 2 → 3 (→ status: in_progress)
```

**Validasi:**
- `accepted_count` tidak boleh melebihi `required_people`
- Satu provider hanya bisa accept satu kali (unique constraint: `task_providers.task_id_provider_id`)
- Saat kuota penuh, status otomatis berubah ke `in_progress`

**Unique constraint:**
```sql
@@unique([task_id, provider_id])
@@index([provider_id])
```

### Multi-Stop (task_locations)

Custom task bisa punya **banyak lokasi**:

```sql
-- Struktur task_locations
CREATE TABLE task_locations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    task_id UUID NOT NULL,
    label VARCHAR(100),           -- "Rumah Lama", "Rumah Baru"
    address TEXT NOT NULL,
    location geometry,             -- PostGIS
    stop_order INT DEFAULT 0      -- Urutan kunjungan
);
```

**Query multi-stop:**
```sql
SELECT id, label, address,
    ST_Y(location::geometry) as lat,
    ST_X(location::geometry) as lng,
    stop_order
FROM task_locations
WHERE task_id = ?
ORDER BY stop_order ASC;
```

**Mengapa multi-stop?**
- Beberapa task butuh kunjungan ke beberapa lokasi (pindahan, survey, inspeksi)
- `stop_order` menentukan urutan kunjungan
- Setiap lokasi punya label untuk kemudahan identifikasi

---

## 7. Platform Fee Custom Task

### Perbandingan dengan Order Biasa

| Aspek | Order Biasa | Custom Task |
|---|---|---|
| **Platform fee** | Rp 2.000 flat | 5% dari `budget_per_person` |
| **Siapa yang bayar?** | Customer (sudah termasuk di total_price) | Customer (dihitung per provider) |

### Perhitungan

```
budget_per_person = Rp 150.000
platform_fee_rate = 5%
platform_fee = 150.000 × 5% = Rp 7.500
total_harga_per_provider = 150.000 + 7.500 = Rp 157.500

Jika required_people = 3:
total_pembayaran_customer = 157.500 × 3 = Rp 472.500
total_platform_fee = 7.500 × 3 = Rp 22.500
```

### Di kode

```typescript
// custom-tasks.service.ts:421-425
const budgetPerPerson = Number(task.budget_per_person) || 0;
const feeRate = Number(task.platform_fee_rate) || 5;
const totalPrice = budgetPerPerson;
const platformFee = Math.round(budgetPerPerson * feeRate / 100);
const finalPrice = totalPrice + platformFee;
```

---

## 8. Desain Keputusan

### Mengapa `accepted_count` di tabel `custom_tasks`?

**Keputusan:** Counter denormalisasi, bukan COUNT query.

**Alasan:**
- Query `accepted_count < required_people` lebih cepat daripada `COUNT(*) FROM task_providers WHERE task_id = ?`
- Dalam transaksi concurrent (banyak provider accept bersamaan), atomic increment mencegah race condition
- Trade-off: data bisa stale jika ada error — tapi dengan `$transaction`, ini diminimalisir

### Mengapa `platform_fee_rate` disimpan di `custom_tasks`?

**Keputusan:** Rate disimpan per task, bukan dihitung setiap saat.

**Alasan:**
- Jika rate berubah di masa depan (misal: 5% → 7%), task yang sudah ada tetap pakai rate lama
- Transparansi: customer bisa lihat berapa persen fee sebelum bayar
- Rate saat ini: 5.00 (5%)

### Mengapa `assignment_type` di orders?

**Keputusan:** Kolom `assignment_type` (VARCHAR(20)) di `orders` membedakan order biasa dari custom task.

**Nilai:**
- `manual` (default) — order biasa, customer pilih provider langsung
- `custom_task` — order yang berasal dari custom task

**Mengapa?** Agar admin bisa filter:
- Halaman "Semua Order" → `WHERE task_provider_id IS NULL` (hanya order biasa)
- Halaman "Custom Tasks" → `WHERE assignment_type = 'custom_task'`

### Mengapa `payment_proof` ada di `custom_tasks`?

**Keputusan:** Satu bukti bayar untuk seluruh task (bukan per provider).

**Alasan:**
- Customer bayar SEKALIGUS untuk semua provider
- `payment_proof` adalah URL gambar bukti transfer
- Status: `unpaid` → `proof_uploaded` → `paid`

**Trade-off:** Jika ada kebutuhan bayar per provider di masa depan, schema harus di-migrate.

### Mengapa `publish_days` di `custom_tasks`?

**Keputusan:** Customer menentukan berapa lama task "hidup" (1-3 hari).

**Alasan:**
- Task yang terlalu lama aktif bisa menumpuk
- `expires_at` dihitung otomatis: `now + publish_days × 24 jam`
- Task expired otomatis tidak muncul di daftar task tersedia

### Mengapa provider dalam radius 20km?

**Keputusan:** Notifikasi dikirim ke provider yang lokasinya dalam 20km dari task.

**Alasan:**
- Relevansi: provider yang terlalu jauh kemungkinan kecil bisa hadir
- Efisiensi: tidak semua provider perlu tahu setiap task
- Query geospatial: `ST_DWithin(location, task_location, 20 / 111.3199)`

### Potensi error

| Error | Kemungkinan | Dampak |
|---|---|---|
| Semua provider reject | Rendah | Task expired, customer bisa republish |
| Provider accept tapi tidak kerja | Rendah | Task stuck, admin perlu intervensi |
| Customer tidak bayar setelah provider accept | Sedang | Task stuck di `in_progress`, provider menunggu |
| Provider selesai tapi admin belum payout | Normal | Provider tidak terima dana, tapi work sudah dilakukan |
| Race condition double-accept | Rendah | Dicegah dengan atomic increment + unique constraint |
