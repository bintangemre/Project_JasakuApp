# 03 — Manajemen Pesanan

## Deskripsi

Halaman manajemen pesanan memungkinkan provider mengelola semua pesanan yang masuk, terbagi dalam 3 tab: **Hari Ini**, **Akan Datang**, dan **Riwayat**. Setiap tab menampilkan daftar order dengan status badge dan tombol aksi status.

### Komponen Utama

| File | Fungsi |
|---|---|
| `provider_order_management_page.dart` | Halaman manajemen pesanan (3 tab) |
| `provider_order_detail_page.dart` | Detail lengkap sebuah pesanan |
| `provider_order_list_page.dart` | Daftar pesanan dari halaman profil |

## Flow

### 1. Membuka Manajemen Pesanan

Provider mengetuk tab **"Orderan"** di bottom navigation → masuk `ProviderOrderManagementPage`.

### 2. Memuat Data

Saat halaman dimuat:
1. Mengambil 3 data secara parallel via `Future.wait`:
   - `GET /api/orders/provider/orders?scope=today` → pesanan hari ini
   - `GET /api/orders/provider/orders?scope=upcoming` → pesanan akan datang
   - `GET /api/orders/provider/orders?scope=history` → riwayat pesanan
2. Setiap tab menampilkan jumlah pesanan di label tab (misal: "Hari Ini (3)")

### 3. Struktur Tab

#### Tab 1: Hari Ini
- Menampilkan order dengan `work_date` = hari ini
- Status bisa aktif (accepted, on_the_way, arrived, in_progress) atau sudah selesai/batal
- **Tombol aksi status** muncul untuk order aktif (hanya jika dalam jam operasional)
- Pull-to-refresh tersedia

#### Tab 2: Akan Datang
- Menampilkan order dengan `work_date` di masa depan
- Status umumnya `accepted` (sudah diterima tapi belum waktunya)
- Tidak ada tombol aksi status (belum waktunya)

#### Tab 3: Riwayat
- Menampilkan order dengan status `completed`, `cancelled`, atau `rejected`
- Tidak ada tombol aksi status

### 4. Order Card

Setiap order card menampilkan:
- **Badge status** berwarna:
  - `pending` → orange — "Menunggu"
  - `accepted` → biru — "Diterima"
  - `on_the_way` → biru muda — "Dalam Perjalanan"
  - `arrived` → indigo — "Tiba di Lokasi"
  - `in_progress` → ungu — "Sedang Bekerja"
  - `completed` → hijau — "Selesai"
  - `rejected` → merah — "Ditolak"
  - `cancelled` → abu — "Dibatalkan"
- **Tanggal kerja** (format: "15 Jul 2026")
- **Deskripsi** pesanan
- **Nama customer** (dari `profiles_customer.full_name`)
- **Total harga** (format: "Rp 1.500.000")
- **Tombol aksi status** (hanya di tab Hari Ini, hanya untuk order aktif)

### 5. Tombol Aksi Status

Tombol aksi berubah sesuai status saat ini dan **gated oleh jam operasional**:

| Status Saat Ini | Label Tombol | Status Berikutnya |
|---|---|---|
| `accepted` | Berangkat | `on_the_way` |
| `on_the_way` | Tiba di Lokasi | `arrived` |
| `arrived` | Mulai Bekerja | `in_progress` |
| `in_progress` | Selesaikan Pekerjaan | `completed` |

Jika di luar jam operasional:
- Tombol tidak ditampilkan
- Teks "Di luar jam operasional" ditampilkan dalam warna orange

### 6. Ketuk Order Card → Detail Order

Provider mengetuk card → navigasi ke `ProviderOrderDetailPage` yang menampilkan:

1. **Info status** — badge warna + tanggal
2. **Customer** — nama lengkap
3. **Tanggal kerja** — tanggal order
4. **Tanggal selesai** — jika ada (setelah ekstensi)
5. **Dibuat** — timestamp pembuatan
6. **Lokasi** — alamat lengkap + koordinat (lat, lng)
7. **Deskripsi** — teks bebas dari customer
8. **Foto dari customer** — horizontal scrollable gallery (ketuk untuk full-screen + zoom)
9. **Layanan** — daftar item layanan (nama, qty, harga satuan, subtotal)
10. **Biaya Tambahan** — jika ada additional_fee
11. **Total Bayaran** — total harga (hijau)
12. **Tombol aksi status** — sama seperti di card (gated jam operasional)

### 7. Update Status dari Detail Page

1. Ketuk tombol aksi (misal: "Berangkat")
2. Loading indicator muncul di tombol
3. PATCH request ke backend
4. Status di halaman di-update lokal
5. SnackBar sukses/gagal muncul

## API Endpoints

| Method | Endpoint | Fungsi |
|---|---|---|
| `GET` | `/api/orders/provider/orders?scope=today` | Order hari ini |
| `GET` | `/api/orders/provider/orders?scope=upcoming` | Order akan datang |
| `GET` | `/api/orders/provider/orders?scope=history` | Riwayat order |
| `GET` | `/api/orders/provider/orders?status=active` | Order aktif (digunakan di dashboard) |
| `PATCH` | `/api/orders/orders/{orderId}/status` | Update status order |
| `GET` | `/api/orders/orders/{orderId}` | Detail order lengkap |

## Provider State Management

Manajemen pesanan menggunakan **state lokal** (bukan Riverpod provider terpisah):

```dart
class _ProviderOrderManagementPageState {
  List<Map<String, dynamic>> _todayOrders = [];
  List<Map<String, dynamic>> _upcomingOrders = [];
  List<Map<String, dynamic>> _historyOrders = [];
  bool _loading = true;
  final Dio _dio = ApiClient().dio;
}
```

- Data di-fetch langsung via Dio
- Refresh manual via pull-to-refresh
- Tidak ada auto-refresh timer (berbeda dengan dashboard)

## Status

**SUKSES**

Manajemen pesanan berfungsi dengan baik. Tiga tab terpisah, status badge, tombol aksi, dan detail order lengkap semuanya bekerja.
