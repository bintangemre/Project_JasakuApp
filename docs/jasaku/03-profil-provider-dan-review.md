# Profil Provider dan Review

## Deskripsi

Halaman detail profil provider ditampilkan sebagai bottom sheet (`DetailProviderSheet`) saat customer mengetuk "Lihat Profil" dari daftar provider. Menampilkan informasi lengkap provider, portofolio, jadwal, ulasan, dan warning terkait ketersediaan. Halaman `CustomerProviderReviewsPage` menampilkan semua ulasan untuk provider tertentu.

## Flow

### 1. Melihat Profil Provider

1. Dari daftar mitra (`ProviderListScreen`), customer tap **"Lihat Profil"**
2. `DetailProviderSheet` terbuka (bottom sheet, tinggi 85% layar)
3. Data provider ditampilkan: foto, nama, badge verifikasi, lokasi, jarak

### 2. Cek Status Provider

1. Saat sheet dibuka → `GET /api/orders/provider/{providerId}/status`
2. Data yang dikembalikan:
   - `is_active`: Apakah provider aktif menerima order?
   - `hasActiveOrder`: Apakah provider sedang mengerjakan order?
3. Jika provider tidak aktif → tampilkan banner merah "Mitra sedang tidak tersedia"
4. Jika provider sedang ada order aktif → tampilkan banner merah "Tidak bisa order hari ini"

### 3. Warning Jam Operasional

1. Sheet mengecek `OperatingHours.isWithinOperatingHours()` (client-side)
2. Jika di luar jam 08:00-16:00 WITA → tampilkan banner oranye
3. Pesan: "Anda sedang di luar jam operasional (08:00-16:00 WITA)"

### 4. Tab Info — Tentang Mitra

1. Menampilkan `aboutMe` (deskripsi dari provider)
2. **Portofolio**: Daftar gambar horizontal scrollable (dari `provider.portfolios`)
3. Tap gambar → preview full-screen
4. **Jadwal Mitra**: Tap menu → `GET /api/orders/provider/{providerId}/schedule`
5. Menampilkan tanggal-tanggal yang sudah dibooking (tidak bisa order di tanggal tersebut)

### 5. Tab Ulasan — Daftar Review

1. Saat tab "Ulasan" dipilih → `GET /api/reviews/provider/{providerId}`
2. Menampilkan maksimal 3 ulasan terbaru:
   - Avatar customer, nama, rating bintang, teks review, tanggal
3. Jika lebih dari 3 ulasan → tombol **"Lihat Semua Ulasan (N)"**
4. Tap navigasi ke `CustomerProviderReviewsPage`

### 6. Halaman Ulasan Lengkap (CustomerProviderReviewsPage)

1. `GET /api/reviews/provider/{providerId}`
2. Menampilkan SEMUA ulasan dengan pull-to-refresh
3. Setiap ulasan:
   - Avatar customer (atau placeholder)
   - Nama customer
   - Rating bintang 1-5
   - Teks review (jika ada)
   - Tanggal review
4. Jika belum ada ulasan → tampilkan pesan "Belum ada ulasan"

## API Endpoints

| Endpoint | Method | Keterangan |
|---|---|---|
| `/api/orders/provider/{providerId}/status` | GET | Status aktif & order aktif provider |
| `/api/orders/provider/{providerId}/schedule` | GET | Jadwal yang sudah dibooking |
| `/api/reviews/provider/{providerId}` | GET | Semua ulasan provider |

### Response — Provider Status

```json
{
  "data": {
    "is_active": true,
    "hasActiveOrder": false
  }
}
```

### Response — Provider Schedule

```json
{
  "data": [
    { "work_date": "2026-07-20" },
    { "work_date": "2026-07-22" }
  ]
}
```

### Response — Provider Reviews

```json
{
  "data": [
    {
      "rating": 5,
      "review": "Sangat puas dengan hasilnya!",
      "created_at": "2026-07-15T10:30:00Z",
      "users_reviews_customer_idTousers": {
        "profiles_customer": {
          "full_name": "Andi",
          "avatar_url": "https://..."
        }
      }
    }
  ]
}
```

## Provider State Management

| Provider | Tipe | Keterangan |
|---|---|---|
| — | State lokal `DetailProviderSheet` | `_loadingStatus`, `_hasActiveOrder`, `_serviceAvailable`, `_reviews` |

DetailProviderSheet menggunakan state lokal (`StatefulWidget`) dengan `setState()`, bukan Riverpod provider.

## Screen Files

| Screen | Path |
|---|---|
| Detail Provider (Bottom Sheet) | `features/customer/presentation/screens/customer_provider_list.dart` → `DetailProviderSheet` |
| Semua Ulasan | `features/customer/presentation/screens/customer_provider_reviews_page.dart` |

## Status

**(SUKSES)** — Profil provider, portofolio, jadwal, ulasan, dan warning ketersediaan berfungsi. Data dimuat secara real-time dari backend.
