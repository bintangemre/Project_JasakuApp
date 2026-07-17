# 08 — Metode Pencairan (Payout Methods)

## Deskripsi

Halaman metode pencairan memungkinkan provider mengelola rekening bank atau e-wallet untuk menerima pembayaran dari platform. Provider dapat menambah, mengedit, dan menghapus metode pencairan.

### Komponen Utama

| File | Fungsi |
|---|---|
| `provider_payout_screen.dart` | Halaman utama metode pencairan |
| `payment_repository.dart` | Repository untuk CRUD payout methods |
| `payment_method_model.dart` | Model data PayoutMethod |

## Flow

### 1. Membuka Halaman Metode Pencairan

Provider mengetuk tab **"Profil"** → gulir ke bawah → ketuk **"Metode Penerimaan"** → masuk `ProviderPayoutScreen`.

### 2. Memuat Data

1. `payoutMethodsProvider` (Riverpod `FutureProvider.autoDispose`) dipanggil
2. `PaymentRepository().getMyPayoutMethods()` → `GET /api/payment-methods/mine`
3. Data di-cache selama provider tetap di halaman ini
4. Auto-dispose saat navigasi keluar

### 3. Tampilan Halaman

**Empty state:**
- Ikon wallet besar
- "Belum ada metode penerimaan"
- "Tambahkan rekening bank atau e-wallet"

**Ada data:**
- ListView berisi kartu metode pencairan
- Setiap kartu menampilkan:
  - **Avatar lingkaran** — biru untuk bank, hijau untuk e-wallet
  - **Nama pemilik** (bold)
  - **Nama bank/e-wallet + nomor rekening/HP**
  - **Tombol edit** (ikon pensil)
  - **Tombol hapus** (ikon tempat sampah, merah)

**Floating Action Button (+):**
- Tombol tambah metode baru di pojok kanan bawah

### 4. Menambah Metode Pencairan

1. Ketuk **FAB (+)**
2. Bottom sheet form muncul dengan field:
   - **Tipe** — Dropdown: "Rekening Bank" / "E-Wallet"
   - **Nama Bank/E-Wallet** — TextField (contoh: BCA / GoPay)
   - **Nomor Rekening/HP** — TextField
   - **Nama Pemilik** — TextField
3. Validasi: semua field wajib diisi
4. Ketuk **"Simpan"**
5. `PaymentRepository().createPayoutMethod(method)` → `POST /api/payment-methods/save`
6. List di-refresh (`ref.invalidate(payoutMethodsProvider)`)
7. Bottom sheet tertutup + SnackBar sukses

### 5. Mengedit Metode Pencairan

1. Ketuk **ikon edit** pada kartu
2. Bottom sheet form muncul dengan data terisi:
   - Tipe, nama bank, nomor rekening, nama pemilik sudah terisi
3. Edit field yang diperlukan
4. Ketuk **"Simpan"**
5. `PaymentRepository().updatePayoutMethod(id, method)` → `PUT /api/provider/payout-methods/{id}`
6. List di-refresh + SnackBar sukses

### 6. Menghapus Metode Pencairan

1. Ketuk **ikon hapus** pada kartu
2. Dialog konfirmasi: "Hapus?" / "Metode penerimaan ini akan dihapus."
3. Tombol "Batal" / "Hapus" (merah)
4. Jika konfirmasi → `PaymentRepository().deletePayoutMethod(id)` → `DELETE /api/provider/payout-methods/{id}`
5. List di-refresh + SnackBar "Berhasil dihapus"

## API Endpoints

| Method | Endpoint | Fungsi |
|---|---|---|
| `GET` | `/api/payment-methods/mine` | Ambil semua metode pencairan |
| `POST` | `/api/payment-methods/save` | Tambah metode pencairan baru |
| `PUT` | `/api/provider/payout-methods/{id}` | Update metode pencairan |
| `DELETE` | `/api/provider/payout-methods/{id}` | Hapus metode pencairan |

## Provider State Management

### `payoutMethodsProvider` (FutureProvider.autoDispose)

```dart
final payoutMethodsProvider = FutureProvider.autoDispose<List<PayoutMethod>>((ref) {
  return PaymentRepository().getMyPayoutMethods();
});
```

**Model PayoutMethod:**
```dart
class PayoutMethod {
  String id;
  String type;          // 'bank' | 'ewallet'
  String providerName;  // Nama bank/e-wallet
  String accountNumber; // Nomor rekening/HP
  String accountName;   // Nama pemilik
}
```

**Refresh:**
- `ref.invalidate(payoutMethodsProvider)` — setelah create/update/delete

## Status

**SUKSES**

Metode pencairan berfungsi dengan baik. CRUD lengkap (Create, Read, Update, Delete) dengan UI bottom sheet form dan dialog konfirmasi.
