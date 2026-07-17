# Pembayaran

## Deskripsi

Modul pembayaran menangani alur dari pemilihan metode bayar, instruksi transfer, upload bukti pembayaran, hingga konfirmasi admin. Semua pembayaran melalui sistem **Rekber (Rekening Bersama)** — uang customer ditampung admin sampai pekerjaan selesai.

## Flow

### 1. Pilih Metode Pembayaran (dalam form order)

1. `PaymentMethodPicker` memuat daftar metode dari `GET /api/payment-methods`
2. Daftar ditampilkan sebagai list dengan ikon dan deskripsi
3. Customer pilih metode: Bank Transfer, E-Wallet, atau QRIS
4. Pilihan tersimpan di state `_selectedPaymentMethod`

### 2. Instruksi Pembayaran (PaymentInstructionScreen)

Setelah pesanan dibuat, customer navigasi ke `PaymentInstructionScreen` dengan parameter:
- `orderId`: ID pesanan
- `paymentMethodId`: ID metode pembayaran yang dipilih
- `totalAmount`: Total yang harus dibayar (harga jasa + biaya aplikasi)

**Tampilan:**
1. **Header**: Ikon centang hijau + "Pesanan Dibuat!"
2. **Instruksi pembayaran** tergantung metode:
   - **QRIS**: Gambar QR code + nama penyedia
   - **Bank Transfer**: Nama bank, nomor rekening, atas nama
3. **Ringkasan Total Transfer**: Jumlah yang harus dibayar
4. **Warning**: "Pesanan akan diproses setelah admin mengkonfirmasi pembayaran"
5. **Upload Bukti Pembayaran**: Pilih gambar dari galeri → upload

### 3. Upload Bukti Pembayaran

1. Tap tombol **"Pilih Gambar"** → `ImagePicker` dari galeri
2. Preview gambar ditampilkan
3. Tap **"Upload"** → `POST /api/payments/upload-proof/{orderId}`
4. FormData dengan field `proof` (multipart file)
5. Jika sukses → SnackBar "Bukti pembayaran berhasil diupload"

### 4. Polling Status

1. `Timer.periodic(10 detik)` → cek status pesanan
2. `GET /api/orders/orders/{orderId}` → cek `status`
3. Jika status berubah ke `pending`, `accepted`, atau `on_the_way`:
   - Polling dihentikan
   - Tampilan berubah ke "Pembayaran Dikonfirmasi!"
4. Customer dapat kembali ke beranda atau melihat pesanan

### 5. Pembayaran Ekstensi

Untuk perpanjangan waktu order:
1. Customer setujui ekstensi → muncul dialog pembayaran
2. `GET /api/orders/payment-accounts` → ambil rekening admin
3. Customer pilih metode → lihat detail rekening
4. Transfer manual ke rekening admin
5. Admin konfirmasi secara manual

## API Endpoints

| Endpoint | Method | Keterangan |
|---|---|---|
| `/api/payment-methods` | GET | Daftar metode pembayaran |
| `/api/payments` | POST | Buat record pembayaran |
| `/api/payments/order/{orderId}` | GET | Info pembayaran per order |
| `/api/payments/upload-proof/{orderId}` | POST | Upload bukti transfer |
| `/api/orders/orders/{orderId}` | GET | Cek status order (polling) |
| `/api/orders/payment-accounts` | GET | Rekening admin untuk transfer |

### Request — Upload Proof

```
POST /api/payments/upload-proof/{orderId}
Content-Type: multipart/form-data

proof: [file image]
```

## Provider State Management

| Provider | Tipe | Keterangan |
|---|---|---|
| `paymentMethodsProvider` | `FutureProvider<List<PaymentMethod>>` | Daftar metode pembayaran |

### PaymentMethod Model

```dart
class PaymentMethod {
  final String id;
  final String type;          // "bank_transfer", "e_wallet", "qris"
  final String icon;          // "account_balance", "wallet", "qr_code"
  final String? providerName;
  final String? accountNumber;
  final String? accountName;
  final String? qrisImageUrl;
  final String description;
}
```

## Screen Files

| Screen | Path |
|---|---|
| Pilihan Metode | `features/payments/presentation/screens/payment_methods_screen.dart` |
| Instruksi Pembayaran | `features/payments/presentation/screens/payment_instruction_screen.dart` |
| Picker Widget | `features/payments/presentation/widgets/payment_method_picker.dart` |

## Alur Lengkap

```
Pilih metode → Lihat instruksi → Transfer manual → Upload bukti → Tunggu konfirmasi admin
                                                                    ↓
                                               Admin cek bukti → Status berubah → Notifikasi ke customer
```

## Status

**(SUKSES)** — Alur pembayaran berfungsi: pemilihan metode, instruksi transfer (bank/e-wallet/QRIS), upload bukti, dan polling status otomatis. Semua pembayaran melalui Rekber admin.
