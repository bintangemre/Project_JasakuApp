# 10 — Lokasi dan Tracking

## Deskripsi

Sistem lokasi dan tracking memungkinkan provider mengirimkan lokasi GPS secara real-time ke server, yang kemudian digunakan oleh customer untuk melacak posisi provider saat dalam perjalanan. Tracking berjalan di background dengan interval 30 detik.

### Komponen Utama

| File | Fungsi |
|---|---|
| `location_tracker_provider.dart` | LocationTrackerNotifier (GPS tracking) |
| `location_service.dart` | Helper service lokasi |
| `provider_dashboard.dart` | Menampilkan marker provider + rute |
| `provider_full_map_page.dart` | Full-screen map dengan tracking |
| `order_tracking_page.dart` | Tracking map untuk customer |

## Flow

### 1. Memulai Tracking

Tracking dimulai otomatis saat `ProviderShell` diinisialisasi:

```dart
// provider_shell.dart → initState()
ref.read(locationTrackerProvider.notifier).startTracking();
```

### 2. Proses startTracking()

1. **Request permission GPS**: `Geolocator.requestPermission()`
   - Jika ditolak → log error, return
   - Jika granted → lanjut

2. **Ambil posisi awal**: `Geolocator.getCurrentPosition()`
   - Simpan ke state: `LocationTrackerState(currentPosition: pos, isTracking: true)`
   - Kirim posisi awal ke server: `_sendLocation()`

3. **Setup GPS stream**: `Geolocator.getPositionStream(locationSettings:)`
   - Accuracy: `LocationAccuracy.high`
   - Distance filter: 10 meter (hanya update jika berpindah ≥ 10m)
   - Stream listener update state setiap kali posisi berubah

4. **Setup timer kirim ke server**: `Timer.periodic(Duration(seconds: 30))`
   - Setiap 30 detik, panggil `_sendLocation()`

### 3. Mengirim Lokasi ke Server

```dart
Future<void> _sendLocation() async {
  final pos = state.currentPosition;
  if (pos == null) return;
  await _dio.put(
    ApiEndpoints.updateLocation,  // PUT /api/locations/update
    data: {'lat': pos.latitude, 'lng': pos.longitude},
  );
}
```

**Payload:**
```json
{
  "lat": -6.2088,
  "lng": 106.8456
}
```

### 4. Menghentikan Tracking

Tracking dihentikan otomatis saat `ProviderShell` di-dispose:

```dart
// provider_shell.dart → dispose()
ref.read(locationTrackerProvider.notifier).stopTracking();
```

**Proses stopTracking():**
1. Cancel GPS stream subscription
2. Cancel timer
3. Reset state ke default

### 5. Penggunaan Lokasi di Dashboard

Lokasi provider digunakan di dashboard untuk:

#### Marker Provider (Biru)
```dart
final providerPos = trackerState.currentPosition;
final providerLatLng = providerPos != null
    ? LatLng(providerPos.latitude, providerPos.longitude)
    : null;
```
- Marker lingkaran biru dengan ikon motor
- Border putih 2.5px
- Ukuran: 30x30 px

#### Rute ke Customer
1. Ambil lokasi customer dari order locations
2. Ambil lokasi provider dari tracker
3. Hitung rute via ORS: `RoutingService.getRoute(providerLatLng, customerLatLng)`
4. Tampilkan sebagai polyline biru di peta
5. Refresh setiap 30 detik

#### Auto-move Map
```dart
if (providerLatLng != null && _lastProviderPos != providerLatLng) {
  _lastProviderPos = providerLatLng;
  _mapController.move(providerLatLng, 15.0);  // Zoom level 15
}
```
Peta bergerak mengikuti posisi provider terkini.

### 6. Custom Task Tracking

Untuk custom task, rute juga dihitung dari lokasi provider ke lokasi task:
- Lokasi task: `task.lat`, `task.lng` + `task.locations` (titik tambahan)
- Rute di-cache per taskId dalam `_customTaskRoutes`
- Tersedia di mini-map dashboard dan full-screen map

### 7. Data Flow

```
GPS Provider → Geolocator stream → LocationTrackerState
                                        ↓
                    Timer 30s → PUT /api/locations/update → Backend (PostGIS)
                                        ↓
                    GET /api/locations/provider/{id} → Customer app (live tracking)
```

### 8. Permission Management

- Permission diminta saat pertama kali `startTracking()`
- Jika ditolak → tracking tidak aktif, tapi aplikasi tetap berjalan
- Provider dapat mengaktifkan GPS manual dari pengaturan HP
- Tidak ada blocking UI jika permission ditolak

## API Endpoints

| Method | Endpoint | Fungsi |
|---|---|---|
| `PUT` | `/api/locations/update` | Kirim lokasi provider |
| Body | `{ "lat": X, "lng": Y }` | Koordinat GPS |
| `GET` | `/api/locations/provider/{providerId}` | Ambil lokasi provider (untuk customer) |

## Provider State Management

### `locationTrackerProvider` (StateNotifierProvider)

```dart
class LocationTrackerState {
  final Position? currentPosition;  // Posisi GPS terkini
  final bool isTracking;             // Apakah tracking aktif
}

class LocationTrackerNotifier {
  StreamSubscription<Position>? _subscription;  // GPS stream
  Timer? _updateTimer;                          // Timer 30s kirim ke server
  
  Future<void> startTracking();  // Mulai tracking
  void stopTracking();            // Hentikan tracking
  Future<void> _sendLocation();   // Kirim ke server
}
```

**Properties yang di-expose:**
- `currentPosition` — `Position?` dari Geolocator (latitude, longitude, accuracy, speed, timestamp)
- `isTracking` — boolean status tracking

## Status

**POTENSI ERROR — RENDAH**

### Alasan:
1. **Akurasi GPS bervariasi** — Tergantung perangkat (HP), kondisi (indoor/outdoor), dan provider GPS (Google/Apple). Di dalam ruangan, akurasi bisa turun drastis.
2. **Battery drain** — GPS stream aktif terus dengan `LocationAccuracy.high` dan `distanceFilter: 10` dapat menguras baterai. Timer 30 detik menambah overhead network.
3. **Permission ditolak** — Jika user menolak izin GPS, tracking tidak aktif tapi tidak ada error handling yang visible ke user.

### Solusi yang Disarankan:
1. Pertimbangkan `LocationAccuracy.medium` untuk hemat baterai saat idle
2. Tambahkan UI notifikasi jika GPS tidak aktif
3. Implementasi adaptive interval (lebih sering saat aktif, jarang saat idle)
