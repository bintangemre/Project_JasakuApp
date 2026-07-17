# Manajemen Layanan

## Deskripsi

Halaman ini digunakan oleh admin untuk mengelola layanan (CRUD). Setiap layanan terikat pada satu kategori. Admin harus memilih kategori terlebih dahulu sebelum bisa melihat/menambah layanan.

## Flow

### Melihat Layanan

```
Admin buka halaman Layanan
    ↓
Admin pilih kategori dari dropdown
    ↓
API: GET /api/admin/categories/:id/services
    ↓
Daftar layanan dalam kategori ditampilkan
```

### Tambah Layanan

```
Admin pilih kategori → Klik "Tambah"
    ↓
Modal form muncul: Nama Layanan
    ↓
Admin masukkan nama (misal: "Service AC")
    ↓
Admin klik "Simpan"
    ↓
API: POST /api/admin/services { categoryId, name }
    ↓
Toast: "Layanan ditambahkan"
    ↓
Daftar layanan di-refresh
```

### Edit Layanan

```
Admin klik ikon edit (pensil) pada layanan
    ↓
Modal form muncul dengan nama existing
    ↓
Admin ubah nama
    ↓
Admin klik "Simpan"
    ↓
API: PUT /api/admin/services/:id { name }
    ↓
Toast: "Layanan diperbarui"
```

### Hapus Layanan

```
Admin klik ikon tempat sampah pada layanan
    ↓
Modal konfirmasi: "Hapus layanan ini?"
    ↓
Admin klik "Ya, Hapus"
    ↓
API: DELETE /api/admin/services/:id
    ↓
Toast: "Layanan dihapus"
```

## Halaman

### Dropdown Kategori

Select dropdown di bagian atas, menampilkan seluruh kategori. Admin harus memilih kategori:
- Jika belum memilih: pesan "Pilih kategori" ditampilkan
- Tombol "Tambah" disabled jika belum ada kategori dipilih

### Kolom Tabel

| Kolom | Keterangan |
|---|---|
| Nama | Nama layanan |
| Aksi | Tombol Edit (pensil) + Hapus (tempat sampah) |

### Loading State

3 skeleton baris ditampilkan saat data dimuat.

### Empty State

Jika kategori belum dipilih:
- Ikon `fa-tools` gray
- "Pilih kategori"
- "Pilih kategori untuk melihat layanan di dalamnya"

Jika kategori sudah dipilih tapi kosong:
- Ikon `fa-box-open` gray
- "Belum ada layanan"
- "Klik 'Tambah' untuk membuat layanan baru"

## API Endpoints

| Method | Endpoint | Keterangan |
|---|---|---|
| GET | `/api/admin/categories/:id/services` | Ambil layanan berdasarkan kategori |
| POST | `/api/admin/services` | Buat layanan baru |
| PUT | `/api/admin/services/:id` | Update layanan |
| DELETE | `/api/admin/services/:id` | Hapus layanan |

### Request POST

```json
{
  "categoryId": "uuid-kategori",
  "name": "Service AC"
}
```

### Request PUT

```json
{
  "name": "Service AC Split"
}
```

## Status: (SUKSES)

Fitur CRUD layanan berfungsi dengan baik. Dropdown kategori sebagai filter parent.

**Lokasi kode:**
- Frontend: `index.html:454-476` (template), `app.js:1121-1146` (logic + modal)
- Backend: `admin.routes.ts:60-63` (routes), `admin.controller.ts:116-146` (handlers), `admin.service.ts:188-201` (logic)
