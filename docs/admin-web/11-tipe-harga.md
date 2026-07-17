# Tipe Harga (Pricing Types)

## Deskripsi

Halaman ini digunakan oleh admin untuk mengelola tipe harga (pricing types). Tipe harga menentukan satuan unit untuk layanan (misal: per hari, per meter, per unit, sesi). Setiap tipe harga terikat pada satu kategori.

**Penting**: Halaman ini hanya mendukung **Create** dan **Delete**. Tidak ada fitur **Update/Edit**.

## Flow

### Melihat Tipe Harga

```
Admin buka halaman Tipe Harga
    ↓
Admin pilih kategori dari dropdown
    ↓
API: GET /api/admin/categories/:id/pricing-types
    ↓
Daftar tipe harga dalam kategori ditampilkan
```

### Tambah Tipe Harga

```
Admin pilih kategori → Klik "Tambah"
    ↓
Modal form muncul:
  - Nama: input text (misal: "Harian", "Borongan")
  - Deskripsi: input text (opsional, misal: "Harga per hari kerja")
  - Satuan: input text (opsional, misal: "hari", "meter", "unit", "sesi")
    ↓
Admin isi data → Klik "Simpan"
    ↓
API: POST /api/admin/pricing-types { categoryId, name, description, defaultUnit }
    ↓
Toast: "Tipe harga ditambahkan"
```

### Hapus Tipe Harga

```
Admin klik ikon tempat sampah pada tipe harga
    ↓
Modal konfirmasi: "Hapus tipe harga ini?"
    ↓
Admin klik "Ya, Hapus"
    ↓
API: DELETE /api/admin/pricing-types/:id
    ↓
Toast: "Tipe harga dihapus"
```

## Halaman

### Dropdown Kategori

Select dropdown di bagian atas. Admin harus memilih kategori dulu:
- Jika belum memilih: pesan "Pilih kategori" ditampilkan
- Tombol "Tambah" disabled jika belum ada kategori dipilih

### Kolom Tabel

| Kolom | Keterangan |
|---|---|
| Nama | Nama tipe harga |
| Deskripsi | Deskripsi singkat, atau "-" jika kosong |
| Satuan | Unit harga, atau "-" jika kosong |
| Aksi | Tombol Hapus (tempat sampah) saja — **tidak ada tombol Edit** |

### Empty State

Jika kategori belum dipilih:
- Ikon `fa-dollar-sign` gray
- "Pilih kategori"

Jika kategori dipilih tapi kosong:
- Ikon `fa-tag` gray
- "Belum ada tipe harga"

## API Endpoints

| Method | Endpoint | Keterangan |
|---|---|---|
| GET | `/api/admin/categories/:id/pricing-types` | Ambil tipe harga berdasarkan kategori |
| POST | `/api/admin/pricing-types` | Buat tipe harga baru |
| DELETE | `/api/admin/pricing-types/:id` | Hapus tipe harga |

> **Tidak ada endpoint PUT/PATCH** untuk update tipe harga.

### Request POST

```json
{
  "categoryId": "uuid-kategori",
  "name": "Harian",
  "description": "Harga per hari kerja",
  "defaultUnit": "hari"
}
```

## Status: (POTENSI ERROR — RENDAH)

**Alasan**: Tidak ada fitur edit. Jika admin membuat tipe harga dengan nama yang salah, satu-satunya opsi adalah menghapus dan membuat ulang. Ini bukan error teknis, tapi keterbatasan fitur.

**Solusi**:
- Saat ini tidak ada dampak fungsional — tipe harga jarang diubah
- Jika diperlukan, endpoint PUT bisa ditambahkan di backend (ikuti pola `updateCategory`)
- Frontend hanya perlu menambah tombol edit di tabel + modal edit

**Lokasi kode:**
- Frontend: `index.html:500-522` (template), `app.js:1198-1209,1496-1509` (logic + modal)
- Backend: `admin.routes.ts:66-68` (routes), `admin.controller.ts:198-218` (handlers), `admin.service.ts:254-263` (logic)
