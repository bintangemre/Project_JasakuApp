# 02 — Dashboard Provider (Beranda)

## Deskripsi

Dashboard provider adalah halaman utama setelah login, diakses melalui tab **Beranda** di bottom navigation. Dashboard menampilkan ringkasan profil, pekerjaan aktif, lokasi customer di peta, custom task aktif, dan penghasilan bulanan.

### Komponen Utama

| File | Fungsi |
|---|---|
| `provider_dashboard.dart` | Halaman dashboard (ProviderHomePage) |
| `provider_dashboard_provider.dart` | State management dashboard (Riverpod) |
| `provider_dashboard_repository.dart` | Repository network calls |
| `provider_full_map_page.dart` | Full-screen map untuk rute |
| `location_tracker_provider.dart` | Tracking lokasi provider real-time |

## Flow

### 1. Memuat Dashboard

Ketika ProviderShell dimuat:
1. `locationTrackerProvider.notifier.startTracking()` — mulai GPS tracking
2. `_fetchCounts()` — ambil jumlah pending requests, today orders, dll
3. `dashboardProvider.notifier.loadDashboard()` — muat semua data dashboard

`loadDashboard()` memanggil 3 API secara parallel via `Future.wait`:
1. `getProfile()` — data profil provider
2. `getOrders()` — daftar semua order
3. `getActiveCustomTasks()` — custom task yang sedang aktif

### 2. Komponen Dashboard

#### Header (Profil Singkat)
- **Foto profil** lingkaran (dari URL backend)
- **Nama lengkap** + ikon centang (terverifikasi)
- **Jumlah layanan tersedia** atau nickname

#### Statistik (3 kartu)
- **Rating** (bintang + angka, misal: 4.5)
- **Selesai** (jumlah pekerjaan selesai)
- **Performa** (persentase completion rate)

#### Status Ketersediaan
- Toggle **Switch** untuk aktif/nonaktif menerima pesanan
- Label: "Anda sedang menerima pesanan" / "Anda sedang tidak menerima pesanan"
- Toggle memanggil `PATCH /api/provider/profile/availability`

#### Pekerjaan Aktif
Kartu biru (`#EFF6FF`) menampilkan:
- **Nama layanan** (dari `order_items[0].services.name`)
- **Nama customer** (dari `profiles_customer.full_name`)
- **Alamat** customer (dari `order_locations[0].address`)
- **Badge status** berwarna sesuai status:
  - `accepted` → kuning — "Diterima"
  - `on_the_way` → biru — "Dalam Perjalanan"
  - `arrived` → indigo — "Telah Tiba"
  - `in_progress` → biru tua — "Sedang Dikerjakan"
- **Tombol aksi status** (gated oleh jam operasional):
  - `accepted` → "Berangkat"
  - `on_the_way` → "Tiba di Lokasi"
  - `arrived` → "Mulai Bekerja"
  - `in_progress` → "Selesaikan Pekerjaan"
- **Info ekstensi** jika ada (menunggu respon customer / menunggu pembayaran / ekstensi aktif)
- **Tombol "Minta Perpanjangan Waktu"** jika status `in_progress` dan belum ada ekstensi pending

#### Map Rute Lokasi Customer
- **Marker biru** — lokasi provider (live dari GPS)
- **Marker merah** — lokasi customer
- **Polyline biru** — rute dari ORS (OpenRouteService)
- Ketuk peta → buka `ProviderFullMapPage` (full-screen)
- Rute di-refresh setiap **30 detik**

#### Pekerjaan Custom Task Aktif
Kartu oranye (`#FFF7ED`) untuk setiap custom task aktif:
- Judul task
- Badge status (sama seperti order biasa)
- Nama customer
- Alamat
- Jumlah titik lokasi
- Tombol aksi status (Berangkat → Tiba → Mulai → Selesai)
- Mini-map dengan rute
- Marker biru (provider) + marker merah angka (lokasi tambahan)

#### Shortcut Cards
- **Task Tersedia** → navigasi ke `ProviderAvailableTasksPage` + badge jumlah
- **Task Saya** → navigasi ke `ProviderMyBidsPage` + badge jumlah

#### Penghasilan Bulanan
- **Total penghasilan** dalam format Rp (dari order completed bulan ini - platform fee)
- Label "Pendapatan bulan ini" dengan ikon trending up

### 3. Auto-Refresh

- **Dashboard data**: refresh setiap **30 detik** (`_dataTimer`)
- **Rute peta**: refresh setiap **30 detik** (`_routeTimer`)
- **Counts**: refresh setiap **30 detik** (di ProviderShell)

### 4. Operating Hours Gate

Tombol aksi status **hanya aktif** dalam jam operasional (08:00 - 16:00 WITA):

```dart
if (OperatingHours.isWithinOperatingHours())
  // Tampilkan tombol aksi
else
  // Tampilkan label "Di luar jam operasional" (abu-abu, disabled)
```

## API Endpoints

| Method | Endpoint | Fungsi |
|---|---|---|
| `GET` | `/api/provider/profile` | Ambil data profil provider |
| `GET` | `/api/orders/provider/orders` | Ambil semua order provider |
| `GET` | `/api/provider/counts` | Jumlah pending requests, today/upcoming orders, tasks |
| `GET` | `/api/custom-tasks/my-active` | Custom task yang sedang dikerjakan |
| `PATCH` | `/api/orders/orders/{orderId}/status` | Update status order |
| `PATCH` | `/api/custom-tasks/{taskId}/work-status` | Update status kerja custom task |
| `PATCH` | `/api/provider/profile/availability` | Toggle aktif/nonaktif |
| `POST` | `/api/orders/orders/{orderId}/extend` | Minta perpanjangan waktu |
| `GET` | `/api/orders/orders/{orderId}/extensions` | Cek status ekstensi |

## Provider State Management

### `dashboardProvider` (StateNotifierProvider)

```dart
class DashboardState {
  bool isLoading;
  String? error;
  // Profil
  String? fullName, nickname, profilePhoto;
  double rating;
  int totalJobs, totalReviews, servicesCount;
  bool isActive, taskAvailable;
  // Orders
  List<Map<String, dynamic>> orders;
  // Custom Tasks
  List<CustomTaskModel> activeCustomTasks;
}
```

**Computed properties:**
- `activeOrder` — order pertama dengan status aktif (`accepted`/`on_the_way`/`arrived`/`in_progress`) dan `work_date` = hari ini
- `monthlyEarnings` — total (harga - fee) dari order completed bulan ini
- `performance` — persentase `completed / total orders * 100`

**Methods:**
- `loadDashboard()` — fetch profile + orders + active custom tasks
- `toggleAvailability()` — toggle `is_active`
- `toggleTaskAvailability()` — toggle `task_available`

### `providerCountsProvider` (StateProvider)

```dart
class ProviderCounts {
  int pendingRequests;
  int todayOrders;
  int upcomingOrders;
  int availableTasks;
  int myAcceptedTasks;
}
```

### `locationTrackerProvider` (StateNotifierProvider)

Menyimpan `Position? currentPosition` dan `bool isTracking`. GPS stream aktif terus selama provider login.

## Status

**SUKSES**

Dashboard berfungsi dengan baik. Semua komponen — profil, statistik, pekerjaan aktif, peta, custom task, dan penghasilan — ditampilkan dan di-refresh secara otomatis.
