# Pemesanan (Order)

## Deskripsi

Halaman pemesanan memungkinkan customer membuat pesanan jasa dari provider. Formulir mencakup pemilihan tanggal, lokasi di peta, durasi, deskripsi pekerjaan, foto pendukung, dan metode pembayaran. Terdapat validasi jam operasional dan cek jadwal provider.

## Flow

### 1. Akses Halaman Pemesanan

1. Dari `DetailProviderSheet`, customer tap tombol pesan
2. Navigasi ke `CustomerOrdersPage` dengan parameter:
   - `providerId`, `providerName`, `serviceId`, `pricingTypeId`, `basePrice`

### 2. Form Pemesanan

Halaman terdiri dari beberapa kartu:

**Kartu 1 — Detail Layanan**
- Nama provider dan harga per hari
- Durasi kerja (hari): tombol +/- (minimal 1)

**Kartu 2 — Tanggal Pelaksanaan**
- Date picker: `firstDate` = hari ini, `lastDate` = 30 hari ke depan
- Format: `yyyy-MM-dd`

**Kartu 3 — Lokasi Pengerjaan**
- Peta FlutterMap (OpenStreetMap tiles)
- Marker merah menunjukkan lokasi yang dipilih
- GPS otomatis: customer location via `Geolocator.getCurrentPosition()`
- Tap peta untuk memindahkan marker
- TextField alamat detail (wajib diisi)

**Kartu 4 — Deskripsi Pekerjaan**
- TextField multiline (opsional)
- Placeholder: "Contoh: Tolong perbaiki dinding retak..."

**Kartu 5 — Foto Pendukung**
- Tombol trigger → bottom sheet pilihan: Kamera / Galeri
- Kompres gambar ke 70% quality (hemat bandwidth)
- Maksimal **5 foto**
- Preview horizontal scrollable dengan tombol hapus per foto

**Kartu 6 — Metode Pembayaran**
- `PaymentMethodPicker` → daftar metode dari `GET /api/payment-methods`
- Pilihan: Bank Transfer, E-Wallet, QRIS

### 3. Validasi Jam Operasional

- Jika tanggal yang dipilih = hari ini → cek `OperatingHours.canOrderNow()`
- **Sebelum jam 08:00**: warning "Belum jam operasional (08:00-16:00 WITA)"
- **15:30 - 15:59**: warning "Jam operasional berakhir pukul 16:00 WITA. Pilih hari lain atau pesan 2 hari kerja..."
- **Setelah 15:59**: warning "Sudah lewat jam operasional, silahkan order untuk besok"

### 4. Ringkasan Harga

| Item | Keterangan |
|---|---|
| Harga Jasa | `basePrice × quantity` (Rp per hari × jumlah hari) |
| Biaya Aplikasi | Rp 2.000 (flat) |
| **Total Pembayaran** | Harga Jasa + Biaya Aplikasi |

### 5. Submit Pesanan

1. Customer tekan **"Konfirmasi Pesanan"**
2. Validasi form (tanggal, alamat wajib diisi)
3. Buat `OrderPayloadModel` dengan semua data
4. `orderFormProvider.notifier.submitNewOrder()` dipanggil

### 6. Proses Backend

1. `POST /api/orders/orders` → buat pesanan
   ```json
   {
     "customerId": "uuid",
     "providerId": "uuid",
     "serviceId": "uuid",
     "pricingTypeId": "uuid",
     "quantity": 3,
     "description": "...",
     "workDate": "2026-07-20",
     "address": "Jl. Merdeka No. 123",
     "lat": -3.4423,
     "lng": 114.8321,
     "paymentMethod": "method-uuid",
     "attachments": ["path/to/photo1.jpg"]
   }
   ```
2. `POST /api/payments` → buat record pembayaran
   ```json
   {
     "orderId": "order-uuid",
     "method": "method-uuid",
     "amount": 52000
   }
   ```
3. Jika sukses → navigasi ke `PaymentInstructionScreen`

### 7. Setelah Pesanan Dibuat

- SnackBar: pesanan berhasil
- Notifikasi counter bertambah (`unreadNotifProvider`)
- Navigasi ke halaman instruksi pembayaran

## API Endpoints

| Endpoint | Method | Keterangan |
|---|---|---|
| `/api/orders/orders` | POST | Buat pesanan baru |
| `/api/payments` | POST | Buat record pembayaran |
| `/api/payment-methods` | GET | Daftar metode pembayaran |

## Provider State Management

| Provider | Tipe | Keterangan |
|---|---|---|
| `orderFormProvider` | `StateNotifier<OrderFormNotifier, OrderFormState>` | State form pemesanan |

### OrderFormState

```dart
class OrderFormState {
  final bool isLoading;
  final String? errorMessage;
  final bool isSuccess;
  final String? orderId;
  final String? paymentMethod;
}
```

### OrderPayloadModel

| Field | Tipe | Keterangan |
|---|---|---|
| `customerId` | String | ID customer |
| `providerId` | String | ID provider |
| `serviceId` | String | ID layanan |
| `pricingTypeId` | String | ID tipe harga |
| `quantity` | int | Durasi kerja (hari) |
| `description` | String | Deskripsi pekerjaan |
| `workDate` | String | Tanggal pelaksanaan (yyyy-MM-dd) |
| `address` | String | Alamat detail |
| `lat` | double | Latitude lokasi |
| `lng` | double | Longitude lokasi |
| `attachments` | List<String> | Path foto-foto lokal |

## Screen Files

| Screen | Path |
|---|---|
| Form Pemesanan | `features/customer/presentation/screens/customer_orders.dart` |
| Order Provider | `features/orders/presentation/providers/orders_provider.dart` |

## Status

**(SUKSES)** — Pemesanan berfungsi dengan validasi jam operasional, upload foto, pemetaan lokasi, dan integrasi pembayaran. Platform fee Rp 2.000 dikenakan per pesanan.
