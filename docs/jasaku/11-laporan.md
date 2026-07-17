# Laporan (Report/Complaint)

## Deskripsi

Fitur laporan memungkinkan customer melaporkan masalah terkait teknis aplikasi, pembayaran, pesanan palsu, perilaku pengguna, atau pekerjaan yang tidak sesuai. Customer juga dapat melihat riwayat laporan yang sudah dikirim beserta respon admin.

## Flow

### 1. Mengirim Laporan (ReportFormPage)

1. Akses dari menu **Profil** → **"Laporkan Masalah"**
2. Halaman form ditampilkan:
   - **Kategori Masalah** (Dropdown): Pilih salah satu:
     - Masalah Teknis
     - Pembayaran
     - Pesanan Palsu
     - Perilaku Pengguna
     - Pekerjaan Tidak Sesuai
     - Lainnya
   - **Deskripsi Masalah** (TextField multiline):
     - Wajib diisi (minimal 10 karakter)
     - Max 1000 karakter
     - Placeholder: "Jelaskan masalah yang kamu alami secara detail..."
3. Tap **"Kirim Laporan"**
4. Validasi form: kategori wajib, deskripsi minimal 10 karakter
5. `POST /api/reports` dengan body:
   ```json
   {
     "subject": "Masalah Teknis",
     "description": "Aplikasi error saat membuka halaman pesanan..."
   }
   ```
6. Jika sukses → SnackBar "Laporan berhasil dikirim" (hijau) → navigasi kembali
7. Jika gagal → SnackBar error (merah)

### 2. Melihat Riwayat Laporan (ReportHistoryPage)

1. Akses dari menu **Profil** → **"Riwayat Laporan"**
2. `GET /api/reports/mine` → ambil semua laporan customer
3. Daftar laporan ditampilkan dalam kartu

**Setiap kartu menampilkan:**
- **Ikon status** (colored container):
  - `open` → Ikon hourglass, warna oranye, label "Diproses"
  - `resolved` → Ikon centang, warna hijau, label "Selesai"
  - `dismissed` → Ikon silang, warna merah, label "Ditolak"
- **Subjek** laporan (kategori)
- **Deskripsi** (max 2 baris, ellipsis)
- **Tanggal** pengiriman

4. Tap kartu → `showModalBottomSheet` detail:
   - Status + ikon
   - Subjek laporan
   - Deskripsi lengkap
   - **Respon Admin** (jika ada): ditampilkan setelah garis pemisah
   - Tanggal dibuat

### 3. Pull-to-Refresh

Halaman riwayat laporan mendukung pull-to-refresh untuk memperbarui data.

## API Endpoints

| Endpoint | Method | Keterangan |
|---|---|---|
| `/api/reports` | POST | Kirim laporan baru |
| `/api/reports/mine` | GET | Riwayat laporan customer |

### Request Body — Kirim Laporan

```json
{
  "subject": "Masalah Teknis",
  "description": "Aplikasi force close saat saya membuka halaman..."
}
```

### Response — Riwayat Laporan

```json
{
  "data": [
    {
      "id": "report-uuid",
      "subject": "Masalah Teknis",
      "description": "Aplikasi error...",
      "status": "open",
      "admin_response": "Kami sedang menindaklanjuti...",
      "created_at": "2026-07-15T10:30:00Z"
    }
  ]
}
```

### Status Laporan

| Status | Label | Keterangan |
|---|---|---|
| `open` | Diproses | Laporan diterima, menunggu penanganan |
| `resolved` | Selesai | Laporan sudah ditangani admin |
| `dismissed` | Ditolak | Laporan ditolak oleh admin |

## Provider State Management

| Provider | Tipe | Keterangan |
|---|---|---|
| — | State lokal | Menggunakan `StatefulWidget` + `setState()` per halaman |

## Screen Files

| Screen | Path |
|---|---|
| Form Laporan | `features/reports/presentation/pages/report_form_page.dart` |
| Riwayat Laporan | `features/reports/presentation/pages/report_history_page.dart` |

## Status

**(SUKSES)** — Fitur laporan berfungsi: pengiriman laporan dengan kategori, riwayat laporan dengan detail, dan respon admin. Form validasi memastikan deskripsi minimal 10 karakter.
