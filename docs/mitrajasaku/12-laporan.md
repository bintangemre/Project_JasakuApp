# 12 — Laporan (Report/Complaint)

## Deskripsi

Fitur laporan memungkinkan provider melaporkan masalah yang terjadi selama penggunaan aplikasi, seperti masalah teknis, pembayaran, pesanan palsu, atau perilaku pengguna lain. Laporan dikirim ke admin untuk ditindaklanjuti.

### Komponen Utama

| File | Fungsi |
|---|---|
| `report_form_page.dart` | Form pengiriman laporan |
| `report_history_page.dart` | Riwayat laporan yang sudah dikirim |
| `provider_profile_page.dart` | Akses ke form laporan dari profil |

## Flow

### 1. Mengirim Laporan

**Akses:** Profil → "Laporkan Masalah" → `ReportFormPage`

**Langkah:**
1. Pilih **kategori masalah** dari dropdown:
   - Masalah Teknis
   - Pembayaran
   - Pesanan Palsu
   - Perilaku Pengguna
   - Pekerjaan Tidak Sesuai
   - Lainnya
2. Tulis **deskripsi masalah** (minimal 10 karakter, maksimal 1000 karakter)
3. Ketuk **"Kirim Laporan"**
4. Request: `POST /api/reports/` dengan body:
   ```json
   {
     "subject": "Masalah Teknis",
     "description": "Detail masalah yang dialami..."
   }
   ```
5. SnackBar hijau: "Laporan berhasil dikirim"
6. Kembali ke halaman sebelumnya

### 2. Melihat Riwayat Laporan

**Akses:** Profil → "Riwayat Laporan" → `ReportHistoryPage`

**Menampilkan:**
- Daftar laporan yang sudah dikirim
- Status setiap laporan (pending, diproses, selesai)
- Tanggal pengiriman
- Deskripsi laporan

### 3. Validasi Form

| Field | Aturan |
|---|---|
| Kategori | Dropdown, default "Masalah Teknis" |
| Deskripsi | Wajib diisi, minimal 10 karakter, maksimal 1000 karakter |

### 4. Error Handling

- Jika request gagal (network error, server error) → SnackBar merah dengan pesan error
- Jika DioException → ambil pesan dari `response.data.message`

## API Endpoints

| Method | Endpoint | Fungsi |
|---|---|---|
| `POST` | `/api/reports/` | Kirim laporan baru |
| Body | `{ "subject": "...", "description": "..." }` | Kategori + deskripsi |
| `GET` | `/api/reports/mine` | Riwayat laporan provider |

## Provider State Management

Form menggunakan state lokal:

```dart
class _ReportFormPageState {
  String _selectedCategory = 'Masalah Teknis';
  final _descController = TextEditingController();
  bool _submitting = false;
}
```

Riwayat laporan menggunakan state lokal di `ReportHistoryPage`.

## Status

**SUKSES**

Fitur laporan berfungsi dengan baik. Form dengan validasi, kirim ke backend, dan riwayat laporan semuanya bekerja.
