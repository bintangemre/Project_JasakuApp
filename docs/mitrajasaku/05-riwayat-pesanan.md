# 05 — Riwayat Pesanan

## Deskripsi

Riwayat pesanan menampilkan daftar order yang sudah selesai, dibatalkan, atau ditolak. Dapat diakses dari tab **"Riwayat"** di halaman Manajemen Orderan, atau dari link **"Manajemen Orderan"** di halaman Profil.

### Komponen Utama

| File | Fungsi |
|---|---|
| `provider_order_management_page.dart` | Tab "Riwayat" dalam Manajemen Orderan |
| `provider_order_list_page.dart` | Halaman riwayat standalone dari Profil |
| `provider_order_detail_page.dart` | Detail pesanan (tap card) |

## Flow

### 1. Membuka Riwayat

**Cara 1 — Dari Manajemen Orderan:**
1. Ketuk tab **"Orderan"** di bottom navigation
2. Ketuk tab **"Riwayat (N)"** di bagian atas

**Cara 2 — Dari Profil:**
1. Ketuk tab **"Profil"** di bottom navigation
2. Gulir ke bawah, ketuk **"Manajemen Orderan"**
3. Navigasi ke halaman `ProviderOrderListPage` (standalone, bukan tab)

### 2. Memuat Data

**Dari tab Riwayat:**
- `GET /api/orders/provider/orders?scope=history` — diambil bersamaan dengan today dan upcoming
- Tidak ada auto-refresh (hanya manual pull-to-refresh)

**Dari ProviderOrderListPage (Profil):**
- `GET /api/orders/provider/orders` — tanpa parameter scope
- Menampilkan semua order dalam satu list

### 3. Tampilan Card Riwayat

Setiap card menampilkan:
- **Badge status** berwarna:
  - `completed` → hijau — "Selesai"
  - `cancelled` → abu — "Dibatalkan"
  - `rejected` → merah — "Ditolak"
- **Tanggal kerja**
- **Deskripsi** pesanan
- **Nama customer**
- **Total harga** (format: "Rp 1.500.000")
- **Tombol aksi** — tidak ada (sudah selesai/batal)

### 4. Ketuk Card → Detail Order

Navigasi ke `ProviderOrderDetailPage` yang menampilkan:
- Semua informasi pesanan (status, customer, tanggal, lokasi, deskripsi, foto, layanan, harga)
- Tidak ada tombol aksi status (karena order sudah final)
- Jika status `completed` — dapat melihat review dari customer (jika ada)
- Jika ada attachment foto dari customer — dapat dilihat dalam gallery + full-screen

### 5. Informasi yang Ditampilkan di Riwayat

| Field | Keterangan |
|---|---|
| Status | Selesai / Dibatalkan / Ditolak |
| Tanggal kerja | Kapan pekerjaan dijadwalkan |
| Deskripsi | Keterangan dari customer |
| Customer | Nama customer |
| Harga | Total harga pesanan |
| Foto | Lampiran dari customer (jika ada) |
| Layanan | Daftar item layanan + harga |
| Review | Rating + ulasan dari customer (jika order selesai dan sudah di-review) |

## API Endpoints

| Method | Endpoint | Fungsi |
|---|---|---|
| `GET` | `/api/orders/provider/orders?scope=history` | Riwayat order (dari tab Riwayat) |
| `GET` | `/api/orders/provider/orders` | Semua order provider (dari Profil) |
| `GET` | `/api/orders/orders/{orderId}` | Detail order |

## Provider State Management

**Dari tab Riwayat di OrderManagementPage:**
- State gabungan bersama today dan upcoming orders
- Fetch parallel saat halaman dimuat

**Dari ProviderOrderListPage:**
- State lokal dengan `_orders` list
- Fetch saat `initState`

## Status

**SUKSES**

Riwayat pesanan berfungsi dengan baik. Card status, detail order, dan navigasi semuanya bekerja.
