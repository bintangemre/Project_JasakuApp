# Dashboard (Beranda)

## Deskripsi

Halaman Dashboard adalah landing page setelah admin login. Menampilkan ringkasan statistik platform dalam bentuk 4 kartu statis. Halaman ini **read-only** — tidak ada fitur CRUD atau interaksi tambahan selain melihat data.

## Stat Cards

| # | Label | Ikon | Warna | Data | Keterangan |
|---|---|---|---|---|---|
| 1 | Total Pengguna | `fa-users` | Indigo | `stats.totalUsers` | Jumlah seluruh user terdaftar (customer + mitra + admin) |
| 2 | Total Mitra | `fa-hard-hat` | Emerald | `stats.totalProviders` | Jumlah provider_profiles |
| 3 | Total Layanan | `fa-tools` | Amber | `stats.totalServices` | Jumlah layanan di seluruh kategori |
| 4 | Total Pesanan | `fa-clipboard-list` | Rose | `stats.totalOrders` | Jumlah seluruh order |

### Layout

- **Desktop**: 4 kartu dalam 1 baris (`grid-cols-4`)
- **Tablet**: 2 kartu per baris (`sm:grid-cols-2`)
- **Mobile**: 1 kartu per baris (`grid-cols-1`)

Setiap kartu memiliki:
- Ikon dalam lingkaran berwarna kiri
- Label kecil di atas (text-xs, gray)
- Angka besar di bawah (text-2xl, bold, dark)
- Efek hover: shadow naik + border indigo

## Loading State

Saat data belum dimuat, 4 skeleton card ditampilkan dengan animasi pulse.

## Flow

1. Admin login → navigate ke `#dashboard`
2. `dashboardPage.init()` dipanggil → memanggil `load()`
3. `load()` mengirim `GET /api/admin/dashboard`
4. Data ditampilkan dalam 4 stat cards

## API Endpoints

| Method | Endpoint | Keterangan |
|---|---|---|
| GET | `/api/admin/dashboard` | Mengambil seluruh statistik dashboard |

### Response `GET /api/admin/dashboard`

```json
{
  "success": true,
  "data": {
    "totalUsers": 150,
    "totalProviders": 45,
    "totalCustomers": 100,
    "totalServices": 30,
    "totalOrders": 500,
    "pendingVerifications": 3,
    "totalCategories": 8
  },
  "message": "Data dashboard berhasil diambil"
}
```

> **Catatan**: Field `totalCustomers`, `pendingVerifications`, dan `totalCategories` dikembalikan oleh backend tapi tidak ditampilkan di UI frontend.

## Auto-refresh

Tidak ada auto-refresh. Data hanya dimuat sekali saat halaman dibuka. Admin harus navigate away dan kembali untuk me-refresh.

## Status: (SUKSES)

Halaman berfungsi dengan baik. Data ditampilkan dengan benar.

**Lokasi kode:**
- Frontend: `index.html:219-233` (template), `app.js:1084-1092` (logic)
- Backend: `admin.controller.ts:9-16` (handler), `admin.service.ts:41-69` (query)
