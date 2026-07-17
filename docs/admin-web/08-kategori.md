# Manajemen Kategori

## Deskripsi

Halaman ini digunakan oleh admin untuk mengelola kategori layanan (CRUD penuh). Setiap kategori memiliki nama dan ikon. Kategori digunakan sebagai parent untuk layanan dan tipe harga.

## Flow

### Tambah Kategori

```
Admin klik "Tambah"
    ↓
Modal form muncul: Nama + Icon Picker
    ↓
Admin pilih nama (misal: "Elektronik") + ikon (misal: "bolt")
    ↓
Admin klik "Simpan"
    ↓
API: POST /api/admin/categories { name, icon }
    ↓
Toast: "Kategori ditambahkan"
    ↓
Daftar kategori di-refresh
```

### Edit Kategori

```
Admin klik ikon edit (pensil) pada kategori
    ↓
Modal form muncul dengan data existing
    ↓
Admin ubah nama/ikon
    ↓
Admin klik "Simpan"
    ↓
API: PUT /api/admin/categories/:id { name, icon }
    ↓
Toast: "Kategori diperbarui"
```

### Hapus Kategori

```
Admin klik ikon tempat sampah pada kategori
    ↓
Modal konfirmasi: "Hapus kategori ini?"
    ↓
Admin klik "Ya, Hapus"
    ↓
API: DELETE /api/admin/categories/:id
    ↓
Toast: "Kategori dihapus"
```

**Aturan bisnis**: Kategori tidak bisa dihapus jika masih memiliki layanan aktif. Error: "Kategori memiliki layanan aktif. Hapus layanan terlebih dahulu."

## Icon Picker

Tersedia **17 ikon** yang bisa dipilih:

| # | Ikon | Kode |
|---|---|---|
| 1 | Kunci inggris | `wrench` |
| 2 | Petir | `bolt` |
| 3 | Kuas | `paintbrush` |
| 4 | Tetesan air | `droplets` |
| 5 | Salju | `snowflake` |
| 6 | Angin | `wind` |
| 7 | Tempat sampah | `trash` |
| 8 | Percikan | `sparkles` |
| 9 | Alat | `tools` |
| 10 | Roda gigi | `cog` |
| 11 | Kipas | `fan` |
| 12 | Api | `fire` |
| 13 | Air | `water` |
| 14 | Daun | `leaf` |
| 15 | Rumah | `home` |
| 16 | Colokan | `plug` |
| 17 | Daur ulang | `recycle` |

Ikon dipilih dari grid 9 kolom. Ikon yang dipilih ditandai dengan background indigo + border indigo.

## Halaman

### Kolom Tabel

| Kolom | Keterangan |
|---|---|
| Ikon | Ikon kategori dalam kotak indigo |
| Nama | Nama kategori |
| Aksi | Tombol Edit (pensil) + Hapus (tempat sampah) |

### Empty State

Jika belum ada kategori:
- Ikon `fa-tags` gray
- "Belum ada kategori"
- "Klik 'Tambah' untuk membuat kategori pertama"

## API Endpoints

| Method | Endpoint | Keterangan |
|---|---|---|
| GET | `/api/admin/categories` | Ambil semua kategori (diurutkan A-Z) |
| POST | `/api/admin/categories` | Buat kategori baru |
| PUT | `/api/admin/categories/:id` | Update kategori |
| DELETE | `/api/admin/categories/:id` | Hapus kategori |

### Request POST/PUT

```json
{
  "name": "Elektronik",
  "icon": "bolt"
}
```

### Validasi Hapus

Backend mengecek jumlah layanan dalam kategori. Jika > 0, error dilempar.

## Status: (SUKSES)

Fitur CRUD kategori berfungsi dengan baik. Icon picker 17 ikon tersedia. Validasi hapus aktif.

**Lokasi kode:**
- Frontend: `index.html:432-451` (template), `app.js:1094-1119` (logic + modal)
- Backend: `admin.routes.ts:54-57` (routes), `admin.controller.ts:53-113` (handlers), `admin.service.ts:153-186` (logic)
