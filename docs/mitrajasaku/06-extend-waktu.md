# 06 — Perpanjangan Waktu (Extend Waktu)

## Deskripsi

Fitur perpanjangan waktu memungkinkan provider meminta tambahan waktu (1-3 hari) ketika pekerjaan belum selesai pada tanggal yang dijadwalkan. Permintaan ekstensi harus disetujui dan dibayar oleh customer, lalu dikonfirmasi oleh admin sebelum aktif.

### Komponen Utama

| File | Fungsi |
|---|---|
| `provider_dashboard.dart` | Tombol "Minta Perpanjangan Waktu" di dashboard |
| `provider_order_detail_page.dart` | Info ekstensi di detail order |
| `admin_pending_extensions_page.dart` | Halaman admin untuk approve ekstensi |

## Flow

### 1. Minta Perpanjangan (Provider)

**Prasyarat:**
- Order harus dalam status `in_progress`
- Belum ada ekstensi pending atau aktif untuk order ini

**Langkah:**
1. Di dashboard, pada kartu pekerjaan aktif, tombol **"Minta Perpanjangan Waktu"** muncul (outlined button oranye)
2. Ketuk tombol → dialog pilih jumlah hari:
   - **1 hari**
   - **2 hari**
   - **3 hari**
3. Pilih jumlah hari → kirim request
4. SnackBar hijau: "Permintaan perpanjangan diajukan"
5. Tombol berubah menjadi info status ekstensi

### 2. Status Ekstensi

Setelah mengajukan, dashboard menampilkan status ekstensi:

| Status | Label | Warna |
|---|---|---|
| `pending_customer` | "Menunggu respon customer (N hari)" | Orange |
| `pending_payment` | "Menunggu pembayaran (N hari)" | Orange |
| `active` | "Ekstensi N hari aktif" | Hijau |

Status dicek via `GET /api/orders/orders/{orderId}/extensions`.

### 3. Alur Lengkap Perpanjangan

```
Provider minta ekstensi (1-3 hari)
        ↓
POST /api/orders/orders/{orderId}/extend
        ↓
Customer menerima notifikasi
        ↓
Customer setujui atau tolak
        ↓ (setuju)
Customer bayar biaya ekstensi (2% per hari, max 5%)
        ↓
Admin konfirmasi pembayaran
        ↓
Ekstensi aktif — tanggal selesai order diperpanjang
```

### 4. Biaya Perpanjangan

- **Biaya**: 2% per hari dari total harga order
- **Maksimum**: 5% dari total harga order
- **Contoh**: Order Rp 1.000.000, ekstensi 2 hari → biaya Rp 40.000 (4%)
- Biaya dibayar oleh customer melalui sistem pembayaran

### 5. Syarat & Ketentuan

- Provider **tidak boleh** memiliki order di masa depan jika ingin minta ekstensi
- Ekstensi hanya bisa diminta saat status order `in_progress`
- Maksimal 3 hari per permintaan
- Customer berhak menolak permintaan ekstensi

## API Endpoints

| Method | Endpoint | Fungsi |
|---|---|---|
| `POST` | `/api/orders/orders/{orderId}/extend` | Ajukan perpanjangan waktu |
| Body | `{ "additionalDays": N }` | N = 1, 2, atau 3 |
| `GET` | `/api/orders/orders/{orderId}/extensions` | Cek status ekstensi |
| `POST` | `/api/orders/extensions/{extensionId}/respond` | Customer: setujui/tolak |
| `GET` | `/api/admin/extensions/pending` | Admin: daftar ekstensi pending |
| `POST` | `/api/admin/extensions/{extensionId}/approve` | Admin: konfirmasi ekstensi |

## Provider State Management

State ekstensi dikelola di tingkat widget `ProviderHomePage`:

```dart
String? _extensionStatusText;  // Teks status ekstensi
bool _extensionLoading = false; // Loading state saat submit
String? _lastCheckedOrderId;   // Cache: cek sekali per order
```

**Flow state:**
1. `_requestExtension(orderId)` — tampilkan dialog → POST → update loading state
2. `_checkExtensionStatus(orderId)` — GET extensions → parse status → update `_extensionStatusText`

## Status

**SUKSES**

Fitur perpanjangan waktu berfungsi dengan baik. Flow provider → customer → admin sudah lengkap.
