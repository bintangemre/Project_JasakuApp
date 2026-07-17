# Laporan (Reports)

## Deskripsi

Halaman ini digunakan oleh admin untuk menangani laporan dari customer atau mitra. Laporan bisa berupa keluhan, permintaan bantuan, atau masalah lainnya. Admin menanggapi laporan dengan memberikan respon dan menentukan tindakan (selesaikan atau tolak).

## Flow Lengkap

```
Customer/Mitra kirim laporan (via aplikasi)
    ↓
Laporan masuk dengan status: open
    ↓
Admin buka halaman Laporan
    ↓
Admin melihat daftar laporan open
    ↓
Admin klik "Tanggapi" pada laporan
    ↓
Modal muncul: detail laporan + form tanggapan
    ↓
Admin tulis tanggapan
    ↓
Admin pilih tindakan: "Selesaikan" atau "Tolak"
    ↓
Admin klik "Kirim"
    ↓
API: PATCH /api/admin/reports/:reportId/respond { response, status }
    ↓
Laporan status: open → resolved / dismissed
    ↓
Pelapor dikirim notifikasi push: REPORT_RESPONDED
("Laporan '...' telah terselesaikan/ditutup oleh admin. Respon: ...")
```

## Halaman

### Kolom Tabel

| Kolom | Keterangan |
|---|---|
| Pelapor | Email pengirim laporan |
| Subjek | Judul/jenis laporan |
| Deskripsi | Deskripsi singkat (max-width, truncate) |
| Tanggal | Tanggal laporan dibuat (dd/mm/yyyy) |
| Aksi | Tombol "Tanggapi" (ikon reply + teks) |

### Auto-refresh

Daftar laporan di-refresh otomatis setiap **15 detik**.

### Empty State

Jika tidak ada laporan:
- Ikon `fa-flag` gray
- "Tidak ada laporan"
- "Semua laporan sudah ditindaklanjuti"

## Modal Tanggapi Laporan

### Bagian Atas: Detail Laporan

Menampilkan subjek dan deskripsi laporan di panel abu-abu.

### Form Tanggapan

| Field | Tipe | Keterangan |
|---|---|---|
| Tanggapan | Textarea (4 baris) | Respon admin untuk pelapor. Wajib diisi. |
| Tindakan | Select dropdown | Pilihan: "Selesaikan" (`resolved`) atau "Tolak" (`dismissed`) |

### Tombol Aksi

- **Batal**: Tutup modal tanpa menyimpan
- **Kirim**: Simpan tanggapan + tutup modal

## API Endpoints

| Method | Endpoint | Keterangan |
|---|---|---|
| GET | `/api/admin/reports/open` | Ambil laporan dengan status `open` |
| PATCH | `/api/admin/reports/:reportId/respond` | Tanggapi laporan |

### Response `GET /api/admin/reports/open`

Mengembalikan array `reports` dengan `status = 'open'`, diurutkan dari yang terbaru. Include data `users` (email pelapor).

### Request `PATCH /api/admin/reports/:reportId/respond`

```json
{
  "response": "Kami sudah menindaklanjuti laporan Anda. Terima kasih.",
  "status": "resolved"
}
```

| Field | Tipe | Nilai |
|---|---|---|
| `response` | string | Respon admin (wajib) |
| `status` | string | `resolved` (selesaikan) atau `dismissed` (tolak) |

**Efek samping:**
- `reports.status` berubah ke `resolved` atau `dismissed`
- `reports.admin_response` diisi dengan respon
- `reports.resolved_at` diisi dengan waktu sekarang
- Push notification `REPORT_RESPONDED` dikirim ke pelapor

## Status: (SUKSES)

Fitur laporan berfungsi dengan baik. Admin bisa menanggapi dan menentukan tindakan. Auto-refresh aktif. Push notification ke pelapor aktif.

**Lokasi kode:**
- Frontend: `index.html:871-886,892-910` (template + modal), `app.js:1467-1494` (logic + modal)
- Backend: `admin.routes.ts:102-103` (routes), `admin.controller.ts:331-353` (handlers), `admin.service.ts:419-455` (logic)
