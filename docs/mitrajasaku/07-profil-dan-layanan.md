# 07 — Profil dan Layanan Provider

## Deskripsi

Halaman profil menampilkan informasi lengkap provider, statistik, layanan, portofolio, dan akses ke berbagai pengaturan. Provider dapat mengedit profil, mengelola layanan, melihat portofolio, dan mengaktifkan/menonaktifkan ketersediaan.

### Komponen Utama

| File | Fungsi |
|---|---|
| `provider_profile_page.dart` | Halaman profil utama |
| `provider_profile_edit_screen.dart` | Form edit profil |
| `provider_services_edit_screen.dart` | Edit layanan (deskripsi + harga) |
| `provider_reviews_page.dart` | Halaman ulasan/review |
| `provider_profile_provider.dart` | State management profil |

## Flow

### 1. Membuka Profil

Provider mengetuk tab **"Profil"** di bottom navigation → masuk `ProviderProfilePage`.

Saat dimuat:
1. `profileProvider.notifier.loadProfile()` dipanggil
2. Data diambil dari `GET /api/provider/profile`

### 2. Komponen Profil

#### Header
- **Foto profil** (lingkaran, radius 40) — dari URL backend atau placeholder
- **Nama lengkap** (bold, titleLarge)
- **Nickname** (@nickname) — jika ada
- **Tombol edit** (ikon pensil) → navigasi ke edit profil

#### Status Verifikasi
Banner berwarna sesuai status:
- **Terverifikasi** → hijau — ikon centang + "Terverifikasi"
- **Menunggu verifikasi** → kuning — ikon jam + "Menunggu verifikasi admin"
- **Verifikasi ditolak** → merah — ikon cancel + "Verifikasi ditolak"

#### Statistik (3 kartu)
- **Rating** — bintang + angka (contoh: 4.5) — warna tertiary
- **Pekerjaan** — jumlah total pekerjaan — warna primary
- **Ulasan** — jumlah review (ketuk → buka `ProviderReviewsPage`) — warna secondary

#### Menu Profil

| Menu | Ikon | Navigasi |
|---|---|---|
| Informasi Pribadi | person_outline | → `ProviderProfileEditScreen` |
| Layanan Saya | miscellaneous_services_outlined | → `ProviderServicesEditScreen` |
| Portofolio | photo_library_outlined | Tampilkan galeri portofolio (inline) |
| Metode Penerimaan | account_balance_wallet_outlined | → `ProviderPayoutScreen` |
| Laporkan Masalah | shield_outlined | → `ReportFormPage` |
| Riwayat Laporan | history_outlined | → `ReportHistoryPage` |
| Manajemen Orderan | assignment_outlined | → `ProviderOrderListPage` |
| Edit Profil | edit_outlined | → `ProviderProfileEditScreen` |
| Keluar | logout_outlined | Dialog konfirmasi → logout |

### 3. Edit Profil (`ProviderProfileEditScreen`)

Form edit profil memungkinkan provider mengubah:

| Field | Tipe | Wajib |
|---|---|---|
| Foto Profil | Image (camera/gallery) | Tidak |
| Nama Lengkap | TextField | Ya |
| Nama Panggilan | TextField | Ya |
| Nomor HP | TextField (phone keyboard) | Ya |
| Jenis Kelamin | Dropdown (Laki-laki/Perempuan) | Tidak |
| Tanggal Lahir | DatePicker | Tidak |
| Alamat | TextField (multiline) | Ya |
| Domisili | TextField | Ya |

**Portofolio di edit profil:**
- Lihat portofolio existing (thumbnail network image)
- Tambah foto baru (camera/gallery, maksimal 5 total)
- Hapus foto existing atau baru
- Perubahan ditandai dengan flag `_hasChanges`

**Flow simpan:**
1. Validasi form (field wajib terisi)
2. `profileProvider.notifier.updateProfile(...)` dipanggil
3. Jika ada foto baru → dikirim sebagai multipart
4. Jika berhasil → pop screen + reload profile
5. Jika gagal → tampilkan error

### 4. Edit Layanan (`ProviderServicesEditScreen`)

Halaman edit layanan memungkinkan provider memperbarui deskripsi dan harga semua layanan sekaligus:

**Saat dimuat:**
1. Fetch layanan provider: `GET /api/provider/services`
2. Fetch tipe pricing: `GET /api/provider/services/available-pricing-types`
3. Inisialisasi controller untuk setiap field

**Tampilan:**
- Setiap layanan menampilkan:
  - Nama layanan
  - TextField untuk deskripsi (multiline, max 2 baris)
  - TextField untuk setiap tipe harga (prefix "Rp", suffix "/unit")
- Tombol **"Simpan Perubahan"** di bawah

**Flow simpan:**
1. Iterasi semua layanan
2. Untuk setiap layanan → `PUT /api/provider/services/update-service`
3. Hitung jumlah berhasil/gagal
4. Jika semua berhasil → pop + invalidate profile
5. Jika ada gagal → tampilkan ringkasan "X berhasil, Y gagal"

### 5. Portofolio

Portofolio ditampilkan sebagai galeri thumbnail (Wrap widget, 100x100 px):
- Setiap foto di-load dari URL backend via `NetworkImage`
- Error builder menampilkan placeholder broken image
- Jika portofolio kosong → teks "Belum ada portofolio"

### 6. Toggle Ketersediaan

Di dashboard (bukan profil), terdapat toggle switch untuk:
- **Aktif/nonaktif menerima pesanan** (`is_active`)
- **Aktif/nonaktif menerima custom task** (`task_available`)

Toggle memanggil:
- `PATCH /api/provider/profile/availability` → toggle `is_active`
- `PATCH /api/provider/profile/availability` → toggle `task_available`

### 7. Logout

1. Ketuk tombol **"Keluar"**
2. Dialog konfirmasi: "Apakah kamu yakin ingin keluar?"
3. Tombol "Batal" / "Keluar" (merah)
4. Jika konfirmasi → `authProvider.notifier.logout()` → navigasi ke `/login`

## API Endpoints

| Method | Endpoint | Fungsi |
|---|---|---|
| `GET` | `/api/provider/profile` | Ambil data profil |
| `PATCH` | `/api/provider/profile` | Update data profil (multipart) |
| `GET` | `/api/provider/services` | Daftar layanan provider |
| `PUT` | `/api/provider/services/update-service` | Update deskripsi + harga layanan |
| `GET` | `/api/provider/services/available-pricing-types` | Daftar tipe pricing |
| `PATCH` | `/api/provider/profile/availability` | Toggle ketersediaan |
| `GET` | `/api/reviews/provider/{providerId}` | Ulasan provider |
| `POST` | `/api/auth/logout` | Logout |

## Provider State Management

### `profileProvider` (StateNotifierProvider)

```dart
class ProfileState {
  bool isLoading;
  String? error;
  // Profil
  String? fullName, nickname, phone, gender, birthDate, address, domicile, profilePhoto;
  double rating;
  int totalJobs, totalReviews, servicesCount;
  bool isActive, taskAvailable;
  bool isVerificationPending, isVerificationRejected;
  // Portofolio
  List<String> portfolios;
}
```

**Methods:**
- `loadProfile()` — fetch dari API
- `updateProfile(...)` — update profil + upload foto
- `toggleAvailability()` — toggle is_active
- `toggleTaskAvailability()` — toggle task_available

## Status

**SUKSES**

Profil dan layanan berfungsi dengan baik. Edit profil, edit layanan, portofolio, dan toggle ketersediaan semuanya bekerja.
