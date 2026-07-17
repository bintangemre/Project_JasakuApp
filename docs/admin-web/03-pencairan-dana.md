# Pencairan Dana (Order Payout)

## Deskripsi

Halaman ini digunakan oleh admin untuk mencairkan dana ke rekening mitra setelah pesanan selesai dikerjakan. Proses pencairan dilakukan secara manual oleh admin (transfer bank/e-wallet), lalu dikonfirmasi di panel ini.

## Flow Lengkap

```
Order selesai (status: completed)
    ↓
Admin buka halaman Pencairan Dana
    ↓
Admin melihat daftar order completed yang belum dicairkan
    ↓
Admin melihat info rekening mitra (nomor rekening, nama bank/e-wallet)
    ↓
Admin transfer dana secara manual ke rekening mitra
    ↓
Admin klik "Konfirmasi" → Konfirmasi modal: "Pastikan dana sudah ditransfer"
    ↓
API: PATCH /api/admin/orders/:orderId/confirm-payout
    ↓
Order: payout_confirmed = true, payout_at = now()
    ↓
Mitra dikirim notifikasi push: ORDER_PAYOUT_CONFIRMED
    ("Dana untuk pesanan telah dikirim ke rekening Anda. Terima kasih!")
```

## Halaman

### Kolom Tabel

| Kolom | Keterangan |
|---|---|
| Pelanggan | Nama lengkap customer |
| Mitra | Nama lengkap mitra |
| Tanggal | Tanggal order dibuat |
| No. Rekening Mitra | Nomor rekening + nama penyedia. Jika belum diatur: "Belum diatur" (merah) |
| Total | Total harga order (format Rupiah) |
| Metode | Label metode pembayaran customer |
| Status | Badge "Selesai" (info/biru) |
| Aksi | Tombol "Konfirmasi" atau label "Sudah Dicairkan" (hijau) |

### Info Rekening Mitra

Data rekening mitra diambil dari tabel `provider_payout_methods`. Ditampilkan:
- Nomor rekening / nomor e-wallet
- Nama penyedia (misal: "BCA", "GoPay")

Jika mitra belum mengatur rekening, kolom menampilkan "Belum diatur" dengan teks merah.

### Aksi Konfirmasi Pencairan

1. Admin klik "Konfirmasi" pada order
2. Modal konfirmasi muncul: "Konfirmasi pencairan dana ke mitra? Pastikan dana sudah ditransfer."
3. Admin klik "Ya, Hapus" (tombol confirm)
4. API dipanggil: `PATCH /api/admin/orders/:orderId/confirm-payout`
5. Status berubah: tombol "Konfirmasi" diganti label hijau "Sudah Dicairkan"

### Fitur Riwayat

Sama seperti halaman Konfirmasi Pembayaran:
- **Toggle Riwayat**: Tampilkan/sembunyikan order yang sudah dicairkan
- **Hapus Riwayat**: Mode select → pilih order → "Sembunyikan"
- Disimpan di `localStorage` dengan key `payout_hidden_orders`

### Auto-refresh

Data di-refresh otomatis setiap **15 detik**.

## API Endpoints

| Method | Endpoint | Keterangan |
|---|---|---|
| GET | `/api/admin/orders/pending-payout` | Ambil semua order completed (reguler, bukan custom task) |
| PATCH | `/api/admin/orders/:orderId/confirm-payout` | Konfirmasi pencairan dana |

### Response `GET /api/admin/orders/pending-payout`

Mengembalikan array order dengan status `completed` dan `task_provider_id = null`. Diurutkan: belum dicairkan di atas, lalu berdasarkan tanggal. Include:
- `payout_confirmed`: boolean, sudah dicairkan atau belum
- `provider_payout`: info rekening mitra
- `payments`: metode pembayaran

### Request `PATCH /api/admin/orders/:orderId/confirm-payout`

**Validasi:**
- Order harus ada
- Order status harus `completed`
- `payout_confirmed` harus `false`

**Efek samping:**
- `payout_confirmed = true`
- `payout_at = new Date()`
- Mitra dikirim push notification `ORDER_PAYOUT_CONFIRMED`

## Status: (SUKSES)

Fitur pencairan dana berfungsi dengan baik. Auto-refresh aktif. Riwayat bisa disembunyikan per-browser.

**Lokasi kode:**
- Frontend: `index.html:649-723` (template), `app.js:1297-1356` (logic)
- Backend: `admin.routes.ts:83-84` (routes), `admin.controller.ts:424-441` (handler), `admin.service.ts:519-607` (query + logic)
