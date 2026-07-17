# Daftar Pesanan

## Deskripsi

Halaman daftar pesanan menampilkan semua pesanan customer dengan filter (Semua, Aktif, Selesai). Setiap pesanan dapat dibuka detailnya melalui bottom sheet, termasuk opsi lacak provider, batalkan pesanan, dan beri rating.

## Flow

### 1. Memuat Daftar Pesanan

1. Customer buka tab **Pesanan** atau tap **"Lihat Semua"** di Beranda
2. `customerOrderListProvider` memanggil `GET /api/orders/customer/orders`
3. Data dikonversi menjadi `List<OrderModel>`
4. Daftar pesanan ditampilkan dalam kartu

### 2. Filter Pesanan

Tiga chip filter di bagian atas:

| Filter | Keterangan |
|---|---|
| **Semua** | Tampilkan semua pesanan |
| **Aktif** | Sembunyikan pesanan `completed`, `cancelled`, `rejected` |
| **Selesai** | Hanya tampilkan pesanan `completed` |

### 3. Kartu Pesanan

Setiap kartu menampilkan:
- **Ikon status** (colored container)
- **Nama provider**
- **Tanggal** kerja
- **Badge status** (warna sesuai status)
- **Harga total**

### 4. Status Pesanan dan Warna

| Status | Label | Warna |
|---|---|---|
| `pending` | Menunggu | Oranye |
| `pending_payment` | Menunggu Pembayaran | Oranye |
| `accepted` | Diterima | Biru |
| `on_the_way` | Dalam Perjalanan | Biru tua |
| `arrived` | Tiba | Indigo |
| `in_progress` | Sedang Dikerjakan | Ungu |
| `completed` | Selesai | Hijau |
| `rejected` | Ditolak | Merah |
| `cancelled` | Dibatalkan | Abu-abu |

### 5. Detail Pesanan (Bottom Sheet)

Ketika customer tap kartu pesanan → `showModalBottomSheet`:

**Informasi yang ditampilkan:**
- Nama provider + badge status
- Tanggal kerja
- Deskripsi pekerjaan
- Total harga

**Ekstensi (Perpanjangan Waktu):**
- Mengambil data ekstensi: `GET /api/orders/orders/{orderId}/extensions`
- Jika ada ekstensi dengan status `pending_customer`:
  - Tampilkan banner oranye: "Permintaan Perpanjangan Waktu"
  - Rincian biaya: harga provider + fee aplikasi
  - Tombol **"Tolak"** dan **"Setujui & Bayar"**
- Jika ekstensi `pending_payment`:
  - Tampilkan banner biru: "Menunggu pembayaran"
  - Tombol "Lihat Petunjuk Pembayaran" → tampilkan dialog rekening admin
- Jika ekstensi `active`:
  - Tampilkan banner hijau: "Perpanjangan X hari aktif"

**Aksi yang tersedia:**

| Tombol | Kondisi | Aksi |
|---|---|---|
| **Lacak Provider** | Status: `on_the_way`, `arrived`, `in_progress` | Navigasi ke `OrderTrackingPage` |
| **Batalkan Pesanan** | Status: `pending_payment`, `pending`, `accepted` | Konfirmasi → `POST /api/orders/orders/{id}/cancel` |
| **Beri Rating & Review** | Status: `completed` | Buka `ReviewBottomSheet` |
| **Setujui & Bayar** | Ekstensi `pending_customer` | `POST /api/orders/extensions/{extId}/respond` |
| **Tolak** | Ekstensi `pending_customer` | `POST /api/orders/extensions/{extId}/respond` |

### 6. Pembatalan Pesanan

1. Tap **"Batalkan Pesanan"** → dialog konfirmasi
2. "Yakin ingin membatalkan pesanan dari {provider}?"
3. Jika ya → `POST /api/orders/orders/{orderId}/cancel`
4. SnackBar "Pesanan berhasil dibatalkan"
5. Refresh daftar pesanan

### 7. Pembayaran Ekstensi

1. Customer setujui ekstensi → `POST /api/orders/extensions/{extId}/respond` dengan `action: "approved"`
2. `GET /api/orders/payment-accounts` → ambil rekening admin
3. Dialog menampilkan daftar rekening (bank, e-wallet, QRIS)
4. Customer pilih → lihat detail rekening + total transfer
5. Customer transfer manual → hubungi admin untuk konfirmasi

## API Endpoints

| Endpoint | Method | Keterangan |
|---|---|---|
| `/api/orders/customer/orders` | GET | Semua pesanan customer |
| `/api/orders/orders/{orderId}/extensions` | GET | Daftar ekstensi pesanan |
| `/api/orders/orders/{orderId}/cancel` | POST | Batalkan pesanan |
| `/api/orders/extensions/{extensionId}/respond` | POST | Respon ekstensi (approve/reject) |
| `/api/orders/payment-accounts` | GET | Rekening admin |

## Provider State Management

| Provider | Tipe | Keterangan |
|---|---|---|
| `customerOrderListProvider` | `StateNotifier<OrderListNotifier, OrderListState>` | Daftar pesanan + filter |

### OrderListState

```dart
class OrderListState {
  final bool isLoading;
  final String? error;
  final List<OrderModel> orders;
}
```

## Screen Files

| Screen | Path |
|---|---|
| Daftar Pesanan | `features/orders/presentation/pages/customer_order_list_page.dart` |
| Order List Provider | `features/orders/presentation/providers/order_list_provider.dart` |

## Status

**(SUKSES)** — Daftar pesanan dengan filter, detail bottom sheet, ekstensi waktu, pembatalan, dan integrasi pembayaran berfungsi penuh.
