# 04 — Permintaan Masuk (Incoming Requests)

## Deskripsi

Halaman permintaan masuk menampilkan daftar pesanan baru yang belum diterima oleh provider. Setiap permintaan memiliki batas waktu **5 menit** untuk diterima atau ditolak. Jika tidak ada respons, pesanan akan otomatis dibatalkan (auto-cancel oleh backend).

### Komponen Utama

| File | Fungsi |
|---|---|
| `provider_requests_page.dart` | Halaman permintaan masuk |

## Flow

### 1. Membuka Halaman Permintaan

Provider mengetuk tab **"Permintaan"** di bottom navigation → masuk `ProviderRequestsPage`.

### 2. Memuat Data

1. Fetch permintaan: `GET /api/orders/provider/requests`
2. Auto-refresh setiap **30 detik** via `Timer.periodic`
3. Pull-to-refresh tersedia

### 3. Struktur Halaman

- **AppBar** dengan judul "Permintaan"
- **ListView** berisi request cards
- **Empty state** jika tidak ada permintaan: ikon inbox + "Tidak ada permintaan"
- **Error state** jika gagal memuat: ikon cloud off + tombol "Coba Lagi"

### 4. Request Card

Setiap card menampilkan:

#### Header
- **Nama customer** (dari `profiles_customer.full_name`) + ikon person
- **Alamat** (dari `order_locations[0].address`) + ikon lokasi
- **Countdown timer** di pojok kanan atas:
  - Waktu tersisa dihitung dari `created_at` + 5 menit
  - Format: `MM:SS`
  - Warna orange jika > 1 menit tersisa
  - Warna merah jika < 1 menit tersisa
  - Label "Kadaluarsa" (merah) jika waktu habis

#### Body
- **Deskripsi** pesanan (jika ada) + ikon deskripsi
- **Total harga** (hijau, bold) dan **tanggal kerja** (abu-abu)

#### Footer — Tombol Aksi
- **"Tolak"** — tombol outlined merah
- **"Terima"** — tombol filled hijau

### 5. Menerima Pesanan

1. Ketuk tombol **"Terima"**
2. Request: `PATCH /api/orders/orders/{orderId}/status` dengan body `{ "status": "accepted" }`
3. SnackBar hijau: "Pesanan diterima"
4. List permintaan di-refresh
5. Pesanan berpindah ke tab "Hari Ini" di Manajemen Orderan

### 6. Menolak Pesanan

1. Ketuk tombol **"Tolak"**
2. Dialog konfirmasi muncul:
   - Judul: "Tolak Pesanan?"
   - Pesan: "Anda yakin ingin menolak pesanan ini?"
   - Tombol: "Batal" / "Tolak" (merah)
3. Jika konfirmasi → Request: `PATCH /api/orders/orders/{orderId}/status` dengan body `{ "status": "rejected" }`
4. SnackBar orange: "Pesanan ditolak"
5. List permintaan di-refresh

### 7. Countdown Timer

Timer countdown dihitung di **client-side**:

```dart
Duration _remainingTime(String createdAtStr) {
  final created = DateTime.parse(createdAtStr);
  final deadline = created.add(const Duration(minutes: 5));
  final remaining = deadline.difference(DateTime.now());
  return remaining.isNegative ? Duration.zero : remaining;
}
```

**Catatan penting**: Timer ini dihitung dari waktu `created_at` order. Visual countdown di-update setiap kali widget rebuild (karena `Timer.periodic` 30 detik). **Bukan real-time per detik** — update terjadi setiap 30 detik saat data di-refresh.

### 8. Ketuk Card → Detail Order

Mengetuk card permintaan → navigasi ke `ProviderOrderDetailPage` dengan data raw order. Dari detail, provider dapat melihat info lengkap termasuk foto customer, layanan, dan lokasi.

### 9. Setelah 5 Menit (Auto-Cancel)

- Backend melakukan auto-cancel jika pending order tidak diterima dalam 5 menit
- Pada refresh berikutnya (30 detik), permintaan yang sudah di-cancel tidak akan muncul lagi
- Timer di UI menunjukkan "Kadaluarsa" jika waktu sudah habis

## API Endpoints

| Method | Endpoint | Fungsi |
|---|---|---|
| `GET` | `/api/orders/provider/requests` | Daftar permintaan masuk (status: pending) |
| `PATCH` | `/api/orders/orders/{orderId}/status` | Terima (`accepted`) atau tolak (`rejected`) pesanan |

## Provider State Management

State lokal (bukan Riverpod provider):

```dart
class _ProviderRequestsPageState {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;  // 30 detik auto-refresh
}
```

## Status

**SUKSES**

Fitur permintaan masuk berfungsi dengan baik. Countdown timer, auto-refresh, accept/reject, dan navigasi ke detail order semuanya bekerja.
