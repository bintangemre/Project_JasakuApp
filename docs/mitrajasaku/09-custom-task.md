# 09 — Custom Task (Provider Side)

## Deskripsi

Custom Task adalah fitur yang memungkinkan customer membuat pekerjaan spesifik dengan budget sendiri, dan provider dapat menawarkan diri (bid) untuk mengerjakan task tersebut. Fitur ini berbeda dari order biasa — provider bersaing untuk mendapatkan task berdasarkan jarak dan kesesuaian keahlian.

### Komponen Utama

| File | Fungsi |
|---|---|
| `provider_available_tasks_page.dart` | Halaman task tersedia (dengan jarak) |
| `provider_my_bids_page.dart` | Halaman task yang sudah di-ambil |
| `task_detail_page.dart` | Detail lengkap sebuah task |
| `custom_tasks_repository.dart` | Repository network calls |
| `custom_task_model.dart` | Model data task |

## Flow

### 1. Task Tersedia

**Akses:** Dashboard → shortcut card "Task Tersedia" → `ProviderAvailableTasksPage`

**Memuat data:**
- `GET /api/custom-tasks/available?lat=X&lng=Y` — ambil task tersedia berdasarkan lokasi
- Lokasi provider diambil dari `locationTrackerProvider`

**Tampilan:**
- List task yang tersedia untuk di-bid
- Setiap card menampilkan:
  - Judul task
  - Deskripsi (singkat)
  - Budget per orang (format: "Rp 150.000/orang")
  - Jumlah orang yang dibutuhkan
  - Jarak dari lokasi provider (format: "2.3 km")
  - Alamat lokasi task
  - Tanggal publish

### 2. Menerima Task (Accept)

**Flow:**
1. Buka halaman task tersedia
2. Ketuk task untuk melihat detail
3. Ketuk tombol **"Ambil Task"** atau **"Terima"**
4. Request: `POST /api/custom-tasks/{taskId}/accept`
5. Task berpindah ke halaman "Task Saya"
6. Task muncul di dashboard sebagai custom task aktif

**Prasyarat:**
- Provider harus aktif (`is_active = true`)
- Task harus tersedia (belum penuh)

### 3. Task Saya

**Akses:** Dashboard → shortcut card "Task Saya" → `ProviderMyBidsPage`

**Memuat data:**
- `GET /api/custom-tasks/my-accepted` — task yang sudah diterima provider

**Tampilan:**
- List task yang sudah diambil
- Setiap card menampilkan:
  - Judul task
  - Status task
  - Budget
  - Tanggal

### 4. Task Aktif di Dashboard

Custom task yang sedang aktif muncul di dashboard sebagai kartu oranye (`#FFF7ED`):

- **Judul task**
- **Badge status** berwarna:
  - `on_the_way` → biru — "Dalam Perjalanan"
  - `arrived` → indigo — "Telah Tiba"
  - `in_progress` → biru tua — "Sedang Dikerjakan"
  - `completed` → hijau — "Selesai"
- **Nama customer**
- **Alamat** task
- **Jumlah titik lokasi** (titik tambahan selain lokasi utama)
- **Tombol aksi status** — progression yang sama dengan order biasa:
  - Default → "Berangkat" (on_the_way)
  - on_the_way → "Tiba di Lokasi" (arrived)
  - arrived → "Mulai Bekerja" (in_progress)
  - in_progress → "Selesaikan" (completed)
- **Mini-map** dengan:
  - Marker biru (lokasi provider)
  - Marker merah angka (lokasi utama + titik tambahan)
  - Polyline rute (dari ORS)
  - Ketuk → full-screen map

### 5. Progression Status Custom Task

| Status Saat Ini | Label Tombol | Status Berikutnya |
|---|---|---|
| `null` (belum mulai) | Berangkat | `on_the_way` |
| `on_the_way` | Tiba di Lokasi | `arrived` |
| `arrived` | Mulai Bekerja | `in_progress` |
| `in_progress` | Selesaikan | `completed` |

**Catatan:** Berbeda dengan order biasa, custom task **tidak memiliki operating hours gate** di tombol aksi. Tombol selalu aktif.

### 6. Rute Peta Custom Task

Untuk setiap custom task aktif:
1. Lokasi provider diambil dari GPS
2. Lokasi task diambil dari model (`lat`, `lng`)
3. Rute dihitung via ORS: `RoutingService.getRoute(providerPos, taskPos)`
4. Hasilnya di-cache dalam `_customTaskRoutes[taskId]`
5. Rute di-refresh bersamaan dengan dashboard (setiap 30 detik)

## API Endpoints

| Method | Endpoint | Fungsi |
|---|---|---|
| `GET` | `/api/custom-tasks/available` | Task tersedia (query: lat, lng, radius) |
| `GET` | `/api/custom-tasks/my-accepted` | Task yang sudah diterima provider |
| `GET` | `/api/custom-tasks/my-active` | Task aktif (sedang dikerjakan) |
| `GET` | `/api/custom-tasks/{taskId}` | Detail task |
| `POST` | `/api/custom-tasks/{taskId}/accept` | Terima/ambil task |
| `PATCH` | `/api/custom-tasks/{taskId}/work-status` | Update status kerja |
| `PATCH` | `/api/custom-tasks/{taskId}/complete` | Tandai task selesai |
| `POST` | `/api/custom-tasks/{taskId}/cancel` | Batalkan task |

## Provider State Management

### Custom Tasks di Dashboard

Custom task aktif diambil dari `DashboardState.activeCustomTasks`:
```dart
final activeCustomTasks = results[2] as List<CustomTaskModel>;
```

### CustomTaskModel

```dart
class CustomTaskModel {
  String id;
  String title;
  String? description;
  double? lat, lng;
  String? address;
  String? customerName;
  String? workStatus;  // on_the_way, arrived, in_progress, completed
  List<LocationModel> locations;  // titik tambahan
}
```

### CustomTasksRepository

```dart
class CustomTasksRepository {
  Future<List<CustomTaskModel>> getAvailableTasks({lat, lng, radius});
  Future<List<CustomTaskModel>> getMyAcceptedTasks();
  Future<List<CustomTaskModel>> getMyActiveTasks();
  Future<void> acceptTask(String taskId);
  Future<void> updateWorkStatus(String taskId, String workStatus);
  Future<void> completeTask(String taskId);
  Future<void> cancelTask(String taskId);
}
```

## Status

**POTENSI ERROR — SEDANG**

### Alasan:
1. **Multi-provider flow** — Satu task bisa membutuhkan beberapa provider. Koordinasi antar provider belum sepenuhnya ditangani di client.
2. **Payment manual** — Pembayaran custom task dilakukan secara manual (transfer bank), belum terintegrasi otomatis dengan payment gateway.
3. **Tidak ada operating hours gate** — Tombol aksi custom task selalu aktif, tidak seperti order biasa yang terbatas jam operasional.

### Solusi yang Disarankan:
1. Implementasi status real-time untuk multi-provider coordination
2. Integrasi payment gateway untuk custom task
3. Tambahkan operating hours gate untuk konsistensi
