# Konfirmasi Ekstensi

## Deskripsi

Halaman ini digunakan oleh admin untuk mengonfirmasi pembayaran ekstensi waktu pengerjaan. Ekstensi terjadi ketika mitra meminta waktu tambahan dan customer menyetujui + membayar biaya ekstensi.

## Flow Lengkap

```
Mitra kerjakan order → Waktu hampir habis → Mitra minta ekstensi
    ↓
Customer terima notifikasi → Setujui ekstensi
    ↓
Customer bayar biaya ekstensi → Upload bukti bayar
    ↓
Order extension status: pending_payment
    ↓
Admin buka halaman Konfirmasi Ekstensi
    ↓
Admin klik "Aktifkan"
    ↓
API: PATCH /api/admin/extensions/:extensionId/activate
    ↓
Extension status: pending_payment → pending (aktif)
    ↓
Mitra dapat notifikasi bahwa ekstensi sudah aktif
    ↓
Pengerjaan berlanjut dengan waktu tambahan
```

## Ketentuan Ekstensi

| Aturan | Nilai |
|---|---|
| Biaya per hari | 2% dari total order |
| Maksimal biaya | 5% dari total order |
| Maksimal hari ekstensi | 3 hari total |
| Persetujuan | Customer harus menyetujui |
| Pembayaran | Customer membayar, admin konfirmasi |

## Halaman

### Kolom Tabel

| Kolom | Keterangan |
|---|---|
| Pelanggan | Nama lengkap customer |
| Mitra | Nama lengkap mitra |
| Biaya Ekstensi | Jumlah biaya ekstensi (format Rupiah, warna hijau) |
| Hari | Jumlah hari ekstensi (badge info/biru, format "X hari") |
| Total Order | Total harga order asli (format Rupiah) |
| Status | Badge "Menunggu Pembayaran" (warning/kuning) |
| Aksi | Tombol "Aktifkan" |

### Aksi Aktifkan

1. Admin klik tombol "Aktifkan" pada ekstensi
2. Modal konfirmasi: "Aktifkan ekstensi ini?"
3. Admin klik "Ya, Hapus"
4. Tombol berubah jadi spinner "Memproses..."
5. API dipanggil: `PATCH /api/admin/extensions/:extensionId/activate`
6. Toast hijau: "Ekstensi berhasil diaktifkan"
7. Daftar di-refresh

### Auto-refresh

Data di-refresh otomatis setiap **15 detik**.

## API Endpoints

| Method | Endpoint | Keterangan |
|---|---|---|
| GET | `/api/admin/extensions/pending-payment` | Ambil ekstensi dengan status `pending_payment` |
| PATCH | `/api/admin/extensions/:extensionId/activate` | Aktifkan ekstensi |

### Response `GET /api/admin/extensions/pending-payment`

Mengembalikan array `order_extensions` dengan `status = 'pending_payment'`, include data order terkait (nama customer, nama mitra, total_price, dll).

### Request `PATCH /api/admin/extensions/:extensionId/activate`

Tidak memerlukan body tambahan. Cukup header auth.

## Status: (SUKSES)

Fitur konfirmasi ekstensi berfungsi dengan baik. Auto-refresh aktif.

**Lokasi kode:**
- Frontend: `index.html:603-646` (template), `app.js:318-343` (logic)
- Backend: `admin.routes.ts:89,91` (routes), `admin.controller.ts:322-329` (handler), `admin.service.ts:497-516` (query)
