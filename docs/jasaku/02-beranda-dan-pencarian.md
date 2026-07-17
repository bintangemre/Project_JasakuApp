# Beranda dan Pencarian

## Deskripsi

Halaman Beranda adalah dashboard utama customer setelah login. Menampilkan sapaan personal, bar pencarian, grid kategori layanan, banner promo, dan daftar pesanan terbaru. Fitur pencarian memungkinkan customer mencari kategori dan layanan secara real-time.

## Flow

### 1. Halaman Beranda (CustomerHome)

1. Customer login → masuk ke tab **Beranda** di bottom navigation
2. **Header biru gradient** ditampilkan:
   - Sapaan: "Halo, {nama_depan}!" (dari `authState.user.displayName`)
   - Subtitle: "Apa yang bisa kami bantu?"
   - Ikon notifikasi dengan badge unread count
3. **Bar pencarian** ("Cari layanan...") → tap navigasi ke `CustomerSearchPage`
4. **Grid kategori layanan**:
   - `GET /api/services/categories` dipanggil via `FutureBuilder`
   - Menampilkan maksimal 6 kategori + 1 tombol "Custom Task" + 1 tombol "Lainnya"
   - Setiap kategori memiliki ikon, warna, dan label
   - Tap kategori → navigasi ke `CustomerProvidersByCategory` (daftar layanan dalam kategori)
   - Tap "Custom Task" → navigasi ke `CustomerMyTasksPage`
   - Tap "Lainnya" → navigasi ke `CustomerServices` (semua kategori)
5. **Banner promo horizontal**: kartu "Jasaku Mitra" dan "Custom Task"
6. **Pesanan Terbaru**:
   - `GET /api/orders/customer/orders` → ambil 3 pesanan teratas
   - Menampilkan kartu pesanan: nama provider, status (badge warna), tanggal, harga
   - Jika status `completed` → tombol **"Beri Rating"** (buka `ReviewBottomSheet`)
   - Link **"Lihat Semua"** → navigasi ke `CustomerOrderListPage`
7. **Pull-to-refresh** untuk memperbarui data

### 2. Halaman Pencarian (CustomerSearchPage)

1. Customer tap bar pencarian di Beranda → navigasi ke `CustomerSearchPage`
2. TextField autofocus, minimal 2 karakter untuk pencarian
3. Pencarian real-time via `customerSearchProvider`
4. `GET /api/services/services/search?q={query}`
5. Hasil ditampilkan dalam dua bagian:
   - **Kategori** → tap navigasi ke `CustomerProvidersByCategory`
   - **Layanan** → tap navigasi ke `CustomerProvidersByCategory` (berdasarkan kategori layanan)
6. Jika tidak ada hasil → tampilkan pesan "Tidak ditemukan"

### 3. Daftar Provider per Kategori (CustomerProvidersByCategory)

1. Dari grid kategori atau hasil pencarian, customer tap kategori
2. `GET /api/services/categories/{categoryId}` → ambil detail kategori + daftar layanan
3. Header oranye dengan nama kategori
4. Daftar layanan dalam kategori ditampilkan sebagai kartu
5. Tap layanan → navigasi ke `ProviderListScreen` (daftar mitra yang menyediakan layanan tersebut)

### 4. Daftar Mitra (ProviderListScreen)

1. `GET /api/services/services/providers/non-location/{serviceId}` → ambil daftar provider
2. **Hitung jarak** dari lokasi customer ke lokasi provider menggunakan `latlong2.Distance()`
3. **Urutkan** berdasarkan jarak terdekat
4. Setiap kartu provider menampilkan:
   - Foto profil (atau placeholder)
   - Nama + badge verifikasi hijau
   - Lokasi + jarak
   - Rating + jumlah ulasan + pekerjaan selesai
   - Harga mulai dari
   - Tombol **"Lihat Profil"** → buka `DetailProviderSheet` (bottom sheet)
5. Provider yang tidak aktif ditampilkan dengan opacity 0.5 + banner "Sedang tidak tersedia"

### 5. Detail Provider (DetailProviderSheet)

Bottom sheet `DraggableScrollableSheet` yang menampilkan:

1. **Header**: Foto profil, nama, badge verifikasi, lokasi, jarak
2. **Warning** (jika ada):
   - Mitra tidak tersedia (merah)
   - Tidak bisa order hari ini, sudah ada order aktif (merah)
   - Di luar jam operasional 08:00-16:00 WITA (oranye)
3. **Statistik**: Rating, Ulasan, Job selesai, Pengalaman
4. **Tab Info**:
   - Tentang Mitra (`aboutMe`)
   - Portofolio (gambar horizontal scrollable)
   - Jadwal Mitra (lihat tanggal yang sudah dibooking)
5. **Tab Ulasan**:
   - 3 ulasan terbaru + link **"Lihat Semua Ulasan"**
   - Tap navigasi ke `CustomerProviderReviewsPage`
6. Tombol **"Pesan Sekarang"** (hanya jika provider aktif & tersedia)

## API Endpoints

| Endpoint | Method | Keterangan |
|---|---|---|
| `/api/services/categories` | GET | Semua kategori layanan |
| `/api/services/categories/{id}` | GET | Detail kategori + layanan |
| `/api/services/services/search?q=` | GET | Pencarian kategori & layanan |
| `/api/services/services/providers/non-location/{serviceId}` | GET | Daftar provider per layanan |
| `/api/orders/provider/{providerId}/status` | GET | Status provider (aktif, ada order aktif?) |
| `/api/orders/provider/{providerId}/schedule` | GET | Jadwal provider yang sudah dibooking |
| `/api/orders/customer/orders` | GET | Pesanan customer (untuk card terbaru) |

## Provider State Management

| Provider | Tipe | Keterangan |
|---|---|---|
| `customerSearchProvider` | `StateNotifier<CustomerSearchNotifier>` | State pencarian kategori & layanan |
| `customerHomeOrdersProvider` | `FutureProvider<List<OrderModel>>` | 3 pesanan terbaru di Beranda |

### CustomerSearchState

```dart
class SearchState {
  final String query;
  final bool isLoading;
  final List<SearchResultCategory> categories;
  final List<SearchResultService> services;
}
```

## Screen Files

| Screen | Path |
|---|---|
| Beranda | `features/customer/presentation/screens/customer_home.dart` |
| Pencarian | `features/customer/presentation/screens/customer_search_page.dart` |
| Kategori | `features/customer/presentation/screens/customer_providers_by_category.dart` |
| Daftar Provider | `features/customer/presentation/screens/customer_provider_list.dart` |
| Semua Layanan | `features/customer/presentation/screens/customer_services.dart` |

## Status

**(SUKSES)** — Semua alur beranda, pencarian, dan pemilihan provider berfungsi. Grid kategori dimuat dinamis dari database. Jarak provider dihitung menggunakan rumus haversine via `latlong2`.
