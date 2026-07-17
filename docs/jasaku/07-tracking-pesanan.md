# Tracking Pesanan

## Deskripsi

Halaman tracking memungkinkan customer melacak lokasi provider secara real-time saat pesanan sedang berlangsung. Menggunakan peta FlutterMap dengan polling setiap 5 detik untuk memperbarui posisi provider dan menggambar rute dari provider ke customer.

## Flow

### 1. Akses Tracking

1. Dari detail pesanan (bottom sheet), customer tap **"Lacak Provider"**
2. Hanya tersedia untuk status: `on_the_way`, `arrived`, `in_progress`
3. Navigasi ke `OrderTrackingPage(orderId: order.id)`

### 2. Memuat Data Tracking

1. `GET /api/orders/orders/{orderId}/tracking`
2. Response berisi:
   - `providerLocation`: `{ lat, lng }` — posisi terkini provider
   - `orderLocation`: `{ lat, lng }` — lokasi pengerjaan (customer)
   - `providerName`: nama provider
   - `status`: status pesanan saat ini

### 3. Polling Real-Time

1. `Timer.periodic(Duration(seconds: 5))` → `_fetchTracking()` setiap 5 detik
2. Setiap polling memanggil API tracking
3. Peta diperbarui dengan posisi terbaru provider
4. Rute dihitung ulang menggunakan OpenRouteService

### 4. Tampilan Peta

**Layer Peta:**
- **Tile Layer**: OpenStreetMap (`tile.openstreetmap.org`)
- **Polyline Layer**: Rute dari provider ke customer (garis biru, strokeWidth 4)
- **Marker Layer**:
  - **Marker Biru** (provider): Ikon motor (on_the_way) atau tangan melambai (arrived/in_progress)
  - **Marker Merah** (customer): Ikon `person_pin_circle`

**Info Panel** (di bagian bawah peta):
- Status pesanan + warna indikator
- Koordinat posisi provider
- Koordinat lokasi customer

### 5. Label Status

| Status | Label | Warna Indikator |
|---|---|---|
| `on_the_way` | Provider dalam perjalanan | Biru |
| `arrived` | Provider telah tiba | Indigo |
| `in_progress` | Pekerjaan sedang berlangsung | Hijau |

### 6. Menghitung Rute (OpenRouteService)

1. `RoutingService.getRoute(providerPos, orderPos)` dipanggil
2. Menggunakan OpenRouteService API (butuh API key via `--dart-define=ORS_API_KEY`)
3. Mengembalikan `List<LatLng>` untuk polyline
4. Jika ORS_API_KEY kosong → rute tidak ditampilkan (marker tetap ada)

### 7. Lifecycle

- **initState**: Mulai polling + fetch data pertama
- **dispose**: Cancel timer untuk mencegah memory leak
- Peta auto-center ke posisi provider saat ada update

## API Endpoints

| Endpoint | Method | Keterangan |
|---|---|---|
| `/api/orders/orders/{orderId}/tracking` | GET | Data lokasi provider & order |

### Response

```json
{
  "data": {
    "providerLocation": {
      "lat": -3.4430,
      "lng": 114.8325
    },
    "orderLocation": {
      "lat": -3.4423,
      "lng": 114.8321
    },
    "providerName": "Budi Santoso",
    "status": "on_the_way"
  }
}
```

## Integrasi Routing

```dart
// RoutingService (services/routing_service.dart)
RoutingService.init(orsApiKey);
final points = await RoutingService.getRoute(fromLatLng, toLatLng);
// Mengembalikan List<LatLng> untuk polyline
```

## Screen Files

| Screen | Path |
|---|---|
| Tracking Peta | `features/orders/presentation/pages/order_tracking_page.dart` |
| Routing Service | `services/routing_service.dart` |

## Status

**(SUKSES)** — Tracking real-time berfungsi dengan polling 5 detik, marker provider/customer, dan rute polyline via OpenRouteService. Catatan: menggunakan polling HTTP, bukan WebSocket.
