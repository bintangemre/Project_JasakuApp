# Domain: Pembayaran

> Dokumentasi lengkap sistem pembayaran Jasaku — meliputi model rekber (rekening bersama), alur pembayaran, dan desain keputusan.

---

## Daftar Isi

1. [Tabel yang Terlibat](#1-tabel-yang-terlibat)
2. [Mengapa 3 Tabel Admin Accounts?](#2-mengapa-3-tabel-admin-accounts)
3. [Alur Pembayaran (Rekber)](#3-alur-pembayaran-rekber)
4. [Metode Pembayaran](#4-metode-pembayaran)
5. [Deskripsi Kolom Penting](#5-deskripsi-kolom-penting)
6. [Flow Pembayaran Ekstensi](#6-flow-pembayaran-ekstensi)
7. [Payout ke Provider](#7-payout-ke-provider)
8. [Trade-off dan Pertimbangan Desain](#8-trade-off-dan-pertimbangan-desain)

---

## 1. Tabel yang Terlibat

| Tabel | Peran | Sifat |
|---|---|---|
| `payments` | Record pembayaran per order | Satu order = satu payment |
| `admin_bank_accounts` | Rekening bank admin (untuk transfer) | CRU oleh admin |
| `admin_ewallet_accounts` | E-wallet admin (GoPay, OVO, Dana) | CRU oleh admin |
| `admin_qris_accounts` | QR code QRIS admin | CRU oleh admin |
| `provider_payout_methods` | Rekening tujuan payout ke provider | Dibuat oleh provider |

### ER Ringkas

```
orders (1) ──< payments (1)
payments.method ←── admin_bank_accounts (prefix: transfer_)
payments.method ←── admin_ewallet_accounts (prefix: ewallet_)
payments.method ←── admin_qris_accounts (prefix: qris_)
provider_profiles (1) ──< provider_payout_methods (N)
```

---

## 2. Mengapa 3 Tabel Admin Accounts?

### Perbandingan Struktur

| Kolom | `admin_bank_accounts` | `admin_ewallet_accounts` | `admin_qris_accounts` |
|---|---|---|---|
| `provider_name` | BCA, Mandiri, dll | GoPay, OVO, Dana | QRIS Mandiri, dll |
| `account_number` | Nomor rekening | Nomor HP/akun | **Tidak ada** |
| `account_name` | Nama pemilik rekening | Nama pemilik akun | **Tidak ada** |
| `qris_image_url` | Tidak ada | Tidak ada | URL gambar QR code |
| `is_active` | Boolean | Boolean | Boolean |
| `created_at` | Timestamp | Timestamp | Timestamp |
| `updated_at` | Timestamp | Timestamp | Timestamp |

### Mengapa tidak satu tabel?

1. **Struktur data berbeda:** QRIS tidak punya `account_number` atau `account_name` — hanya punya `qris_image_url`. Jika digabung, kolom `account_number` dan `account_name` harus nullable, dan validitas data menjadi ambigu.

2. **Validitas data:** Dengan tabel terpisah, admin bank WAJIB isi `account_number` + `account_name`. Admin QRIS WAJIB isi `qris_image_url`. Tidak ada keraguan.

3. **Query sederhana:** 
   ```typescript
   // Ambil semua metode bayar — 3 parallel queries
   const [banks, ewallets, qris] = await Promise.all([
       prisma.admin_bank_accounts.findMany({ where: { is_active: true } }),
       prisma.admin_ewallet_accounts.findMany({ where: { is_active: true } }),
       prisma.admin_qris_accounts.findMany({ where: { is_active: true } }),
   ]);
   ```
   Tidak perlu `WHERE type = 'bank'` atau polymorphic discrimination.

4. **Ekstensi masa depan:** Jika ada metode bayar baru (misal: kartu kredit), cukup buat tabel baru tanpa mengubah tabel yang sudah ada.

### Trade-off

- **Kelebihan:** Struktur jelas, validasi ketat, query sederhana.
- **Kekurangan:** 3 tabel untuk data yang konsepnya serupa. Saat admin mengelola "rekening pembayaran", harus handle 3 tabel secara terpisah.
- **Mengapa worth it:** Dalam konteks Jasaku, admin mengelola rekening jarang (hanya saat awal setup). Konsistensi data lebih penting daripada kemudahan administrasi.

---

## 3. Alur Pembayaran (Rekber)

### Konsep Rekber

**Rekber = Rekening Bersama.** Jasaku bertindak sebagai perantara:
1. Customer bayar ke rekening admin Jasaku
2. Admin verifikasi bukti bayar
3. Setelah pekerjaan selesai, admin cairkan ke rekening provider

Ini memastikan **customer tidak kehilangan uang** jika provider tidak kerja, dan **provider tidak rugi** jika customer tidak bayar.

### Alur Lengkap

```
┌─────────────────────────────────────────────────────────────────┐
│                        ALUR PEMBAYARAN                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Admin buat rekening pembayaran                              │
│     POST /api/admin/payment-accounts                            │
│     → admin_bank_accounts / admin_ewallet_accounts /             │
│       admin_qris_accounts                                       │
│                                                                 │
│  2. Customer pilih metode bayar                                 │
│     GET /api/payments/methods                                   │
│     → Tampilkan rekening admin yang aktif                       │
│                                                                 │
│  3. Customer transfer ke rekening admin                         │
│     (Di luar sistem — manual)                                   │
│                                                                 │
│  4. Customer upload bukti bayar                                 │
│     PATCH /api/payments/:orderId/proof                          │
│     → payments.payment_proof = URL gambar                       │
│                                                                 │
│  5. Admin konfirmasi pembayaran                                 │
│     PATCH /api/admin/orders/:orderId/confirm-payment            │
│     → orders.status: pending_payment → pending                  │
│     → payments.status: pending → paid                           │
│     → payments.paid_at = NOW()                                 │
│     → provider_schedules: is_booked = true                      │
│     → Notifikasi ke provider: "Pesanan Baru Masuk!"            │
│     → Notifikasi ke customer: "Pembayaran Dikonfirmasi"        │
│                                                                 │
│  6. Provider kerjakan order                                     │
│     pending → accepted → on_the_way → arrived → in_progress    │
│                                                                 │
│  7. Provider selesai                                            │
│     → orders.status: completed                                  │
│     → provider_profiles.total_jobs: +1                         │
│     → Notifikasi ke customer: "Pesanan Selesai"               │
│                                                                 │
│  8. Customer beri rating                                        │
│     POST /api/reviews                                           │
│     → reviews (rating 1-5, review text)                        │
│     → provider_profiles.rating: recomputed                     │
│                                                                 │
│  9. Admin konfirmasi pencairan                                  │
│     PATCH /api/admin/orders/:orderId/confirm-payout             │
│     → orders.payout_confirmed: true                            │
│     → orders.payout_at: NOW()                                  │
│     → Notifikasi ke provider: "Pencairan Dana Berhasil"       │
│                                                                 │
│  10. Admin transfer ke rekening provider                        │
│      (Di luar sistem — manual)                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Status Pembayaran

| Status | Arti | Siapa yang set |
|---|---|---|
| `pending` | Menunggu pembayaran dari customer | Backend (otomatis saat order dibuat) |
| `paid` | Pembayaran dikonfirmasi admin | Admin (via `confirmPaymentByAdmin`) |

### Bagaimana method di-link ke admin account?

Metode pembayaran disimpan di `payments.method` sebagai **string dengan prefix**:

| Prefix | Arti | Contoh |
|---|---|---|
| `transfer_` + UUID | Bank transfer | `transfer_abc123...` |
| `ewallet_` + UUID | E-wallet | `ewallet_def456...` |
| `qris_` + UUID | QRIS | `qris_ghi789...` |
| `extension` | Pembayaran ekstensi | `extension` |
| `rekber` | Pembayaran custom task | `rekber` |

**Mengapa tidak FK langsung?** Karena ada 3 tabel berbeda. Prefix membedakan tabel mana yang di-link. Service `resolvePaymentMethodLabel()` di `admin.service.ts:8-29` menerjemahkan prefix ini ke label yang bisa dibaca manusia.

---

## 4. Metode Pembayaran

### bank_transfer

- **Deskripsi:** Transfer bank manual
- **Data yang ditampilkan:** Nama bank, nomor rekening, nama pemilik rekening
- **Contoh:** "BCA - 1234567890 - PT Jasaku Bersama"

### e_wallet

- **Deskripsi:** E-wallet (GoPay, OVO, Dana, LinkAja)
- **Data yang ditampilkan:** Nama provider, nomor HP/akun, nama pemilik
- **Contoh:** "GoPay - 081234567890 - Budi Santoso"

### qris

- **Deskripsi:** QR code payment
- **Data yang ditampilkan:** Nama provider, URL gambar QR code
- **Contoh:** Gambar QR code dari "QRIS Mandiri"

---

## 5. Deskripsi Kolom Penting

### payments

| Kolom | Tipe | Nullable | Penjelasan |
|---|---|---|---|
| `id` | UUID | No | Primary key |
| `order_id` | UUID (FK) | No | Relasi ke orders |
| `method` | VARCHAR(50) | Ya | Metode bayar (prefix + UUID) |
| `status` | VARCHAR(30) | Ya | `pending` atau `paid` |
| `amount` | DECIMAL(12,2) | Ya | Jumlah yang harus dibayar |
| `paid_at` | TIMESTAMP | Ya | Waktu pembayaran dikonfirmasi |
| `payment_proof` | TEXT | Ya | URL gambar bukti bayar |

### Mengapa `payment_proof` TEXT?

- **Bukan file reference:** Karena payment proof berupa **URL gambar** yang diupload ke cloud storage (Supabase Storage).
- **TEXT cukup:** URL rata-rata 100–200 karakter. TEXT tidak membatasi panjang.
- **Bukan file binary:** File tidak disimpan di database — hanya URL referensi.
- **Ekstensi:** Di masa depan bisa ditambah kolom `proof_type`, `proof_verified_at`, dll. tanpa mengubah kolom yang ada.

### orders (kolom terkait pembayaran)

| Kolom | Tipe | Penjelasan |
|---|---|---|
| `total_price` | DECIMAL(12,2) | Total harga order |
| `platform_fee` | DECIMAL(12,2) | Fee platform (Rp 2.000 flat untuk order biasa) |
| `additional_fee` | DECIMAL(12,2) | Biaya tambahan dari ekstensi waktu |
| `payout_confirmed` | BOOLEAN | Apakah payout sudah dikonfirmasi admin |
| `payout_at` | TIMESTAMP | Kapan payout dikonfirmasi |

### Perhitungan total biaya customer

```
total_biaya = total_price + additional_fee
```

### Perhitungan payout ke provider

```
payout = total_price + additional_fee - platform_fee
```

**Catatan:** `platform_fee` adalah hak platform, bukan bagian dari payout provider.

---

## 6. Flow Pembayaran Ekstensi

### Langkah-langkah

```
1. Provider request extension
   → order_extensions (status: pending_customer)
   ↓
2. Customer approve
   → order_extensions (status: pending_payment)
   → payments (method: 'extension', status: 'pending', amount: additional_cost)
   ↓
3. Customer bayar ke rekening admin
   (Di luar sistem)
   ↓
4. Admin konfirmasi pembayaran extension
   → payments.status: 'paid'
   → order_extensions.status: 'active'
   → orders.additional_fee: +additional_cost
   → orders.end_date: +extension_days
   → provider_schedules: upsert untuk hari ekstensi
   ↓
5. Notifikasi ke provider dan customer: "Ekstensi Aktif"
```

### Perhitungan biaya ekstensi

```typescript
// orders.service.ts:937-939
const platformFeeRate = Math.min(totalRequestedDays * 2, 5);
const additionalCost = Number(order.total_price) * platformFeeRate / 100;
```

| Total Hari Ekstensi | Fee Rate | Contoh (order Rp 100.000) |
|---|---|---|
| 1 hari | 2% | Rp 2.000 |
| 2 hari | 4% | Rp 4.000 |
| 3 hari | 5% (max) | Rp 5.000 |

---

## 7. Payout ke Provider

### Order Biasa

```
1. Order selesai (status: completed)
   ↓
2. Admin lihat halaman "Pencairan Dana"
   GET /api/admin/orders/completed-pending-payout
   ↓
3. Admin konfirmasi pencairan
   PATCH /api/admin/orders/:orderId/confirm-payout
   → orders.payout_confirmed: true
   → orders.payout_at: NOW()
   → Notifikasi ke provider: "Pencairan Dana Berhasil"
   ↓
4. Admin transfer manual ke rekening provider
   (Dilihat dari provider_payout_methods)
```

**Data yang ditampilkan admin:**
- Nama provider
- Total harga order
- Platform fee (potongan)
- Nomor rekening provider (dari `provider_payout_methods`)

### Custom Task

```
1. Semua provider selesai (task_providers.status: completed)
   ↓
2. Customer upload bukti bayar task
   → custom_tasks.payment_proof: URL
   → custom_tasks.payment_status: 'proof_uploaded'
   ↓
3. Admin konfirmasi pembayaran task
   → custom_tasks.payment_status: 'paid'
   → custom_tasks.status: 'active'
   → Semua order: status → 'accepted'
   → Semua payments: status → 'paid'
   ↓
4. Provider kerjakan task
   on_the_way → arrived → in_progress → completed
   ↓
5. Admin konfirmasi payout per provider
   → task_providers.payout_confirmed: true
   ↓
6. Jika semua provider sudah payout confirmed
   → custom_tasks.status: 'fulfilled'
```

### Perhitungan payout custom task

```
budget_per_person = Rp X (ditentukan customer)
platform_fee = budget_per_person × 5%
total_harga = budget_per_person + platform_fee
payout_provider = budget_per_person (setelah dipotong platform_fee)
```

---

## 8. Trade-off dan Pertimbangan Desain

### Mengapa pembayaran manual (di luar sistem)?

**Saat ini:** Jasaku tidak terintegrasi dengan payment gateway (Midtrans, Xendit, dll).

**Alasan:**
- **Biaya:** Payment gateway memotong 2-3% dari setiap transaksi. Jasaku masih MVP.
- **Kontrol:** Admin bisa verifikasi manual sebelum dana dicairkan.
- **Fleksibilitas:** Bisa support metode bayar apapun (transfer bank, e-wallet, QRIS) tanpa integrasi teknis.

**Trade-off:**
- **Kelebihan:** Biaya operasional rendah, kontrol penuh, tidak ada integrasi teknis.
- **Kekurangan:** Proses manual (lambat), human error, tidak real-time. Customer harus upload bukti bayar secara manual.

### Mengapa satu payments per order?

**Keputusan:** `orders (1) ──< payments (1)` — satu order hanya punya satu payment record.

**Alasan:**
- Model bisnis Jasaku: satu order = satu transaksi pembayaran.
- Tidak ada skenario split payment (bayar sebagian dulu, sisanya nanti).
- Jika di masa depan ada cicilan, cukup tambah tabel `payment_installments` yang link ke `payments`.

**Trade-off:** Jika ada kebutuhan partial payment di masa depan, schema harus di-migrate. Tapi untuk MVP, ini cukup.

### Mengapa `payment_proof` TEXT bukan file?

**Keputusan:** Simpan URL, bukan binary data.

**Alasan:**
- Database PostgreSQL tidak efisien untuk menyimpan binary data besar (gambar 1-5 MB).
- Cloud storage (Supabase Storage) lebih suitable: CDN, caching, akses cepat.
- URL bisa di-share, di-cache, dan di-revoke tanpa mengubah database.

### Mengapa `provider_payout_methods` terpisah dari `provider_profiles`?

**Keputusan:** Provider punya tabel sendiri untuk metode pencairan dana.

**Alasan:**
- Provider mungkin punya beberapa rekening (BCA dan Mandiri).
- Data rekening sensitif — pisahkan dari data profil.
- Provider bisa update rekening tanpa mengubah profil.

### Mengapa `admin_bank_accounts` punya `is_active`?

**Keputusan:** Soft toggle, bukan hard delete.

**Alasan:**
- Jika rekening admin dihapus, payment lama yang link ke rekening tersebut akan kehilangan referensi.
- `is_active: false` menyembunyikan rekening dari customer, tapi data tetap ada untuk audit.
- Admin bisa menonaktifkan rekening sementara (misal: rekening sedang bermasalah).

### Potensi error

| Error | Kemungkinan | Dampak |
|---|---|---|
| Customer bayar tapi tidak upload bukti | Tinggi | Order stuck di `pending_payment`, auto-cancel 5 menit |
| Admin salah konfirmasi | Rendah | Uang customer hilang, perlu manual reversal |
| Payment gateway timeout | N/A (manual) | Tidak applicable |
| Provider rekening salah | Rendah | Payout gagal, admin perlu hubungi provider |
| Bukti bayar palsu | Rendah | Admin harus cek manual, bisa reject |
