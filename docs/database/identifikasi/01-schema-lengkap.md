# Schema Lengkap Database Jasaku

> Dokumen referensi lengkap seluruh tabel dalam database Jasaku.
> Dihasilkan dari `jasaku-backend/prisma/schema.prisma`
> Terakhir diperbarui: 2026-07-16

---

## Daftar Semua Tabel

| # | Nama Tabel | Domain | Jumlah Kolom |
|---|---|---|---|
| 1 | `roles` | Otorisasi | 4 |
| 2 | `users` | Autentikasi | 14 |
| 3 | `profiles_customer` | Profil Pelanggan | 9 |
| 4 | `provider_profiles` | Profil Mitra | 27 |
| 5 | `provider_locations` | Lokasi Mitra | 4 |
| 6 | `provider_documents` | Dokumen Mitra | 7 |
| 7 | `provider_payout_methods` | Pembayaran Mitra | 7 |
| 8 | `provider_schedules` | Jadwal Mitra | 6 |
| 9 | `provider_services` | Layanan Mitra | 5 |
| 10 | `provider_service_prices` | Harga Layanan Mitra | 6 |
| 11 | `identity_verifications` | Verifikasi Identitas | 15 |
| 12 | `categories` | Kategori Layanan | 5 |
| 13 | `services` | Layanan | 5 |
| 14 | `pricing_types` | Tipe Harga | 5 |
| 15 | `orders` | Pesanan | 20 |
| 16 | `order_items` | Item Pesanan | 7 |
| 17 | `order_locations` | Lokasi Pesanan | 4 |
| 18 | `order_attachments` | Lampiran Pesanan | 4 |
| 19 | `order_extensions` | Perpanjangan Pesanan | 11 |
| 20 | `payments` | Pembayaran | 8 |
| 21 | `reviews` | Ulasan | 8 |
| 22 | `reports` | Laporan | 11 |
| 23 | `custom_tasks` | Tugas Kustom | 18 |
| 24 | `task_locations` | Lokasi Tugas | 6 |
| 25 | `task_providers` | Mitra Tugas | 10 |
| 26 | `admin_bank_accounts` | Rekening Bank Admin | 6 |
| 27 | `admin_ewallet_accounts` | E-Wallet Admin | 6 |
| 28 | `admin_qris_accounts` | QRIS Admin | 6 |
| 29 | `user_devices` | Perangkat Pengguna | 7 |

**Catatan**: Tabel `spatial_ref_sys` tidak didokumentasikan karena merupakan tabel sistem PostGIS bawaan, bukan tabel aplikasi.

---

## Daftar Tipe Data yang Digunakan

| Tipe Data | PostgreSQL | Kapan Digunakan |
|---|---|---|
| **UUID** | `uuid` | Primary key global — tidak bisa ditebak, aman untuk URL, tidak bentrok lintas environment |
| **Int (autoincrement)** | `serial` / `integer` | Tabel referensi kecil (misal: `roles`) di mana jumlah baris sedikit dan ID bersifat internal |
| **VARCHAR(n)** | `character varying(n)` | Teks dengan batas panjang ketat — memaksa validasi di level database |
| **TEXT** | `text` | Teks tanpa batas panjang — untuk deskripsi, alamat, catatan bebas |
| **DECIMAL(p,s)** | `numeric(p,s)` | Angka presisi tinggi untuk harga/money — tidak ada error pembulatan seperti FLOAT |
| **BOOLEAN** | `boolean` | Flag on/off — is_verified, is_active, dsb. |
| **DateTime** | `timestamptz` | Waktu lengkap (tanggal + jam) dengan timezone — created_at, updated_at |
| **Date** | `date` | Hanya tanggal tanpa jam — work_date pada order dan schedule |
| **geometry** | `geometry(Point,4326)` | Koordinat geospasial PostGIS — latitude + longitude untuk pencarian lokasi |
| **JsonB** | `jsonb` | Data JSON yang bisa diquery — hasil OCR, data liveness |
| **String[]** | `text[]` | Array PostgreSQL untuk data multi-value — lampiran, portofolio |
| **Int** | `integer` | Bilangan bulat untuk counter/jumlah — total_jobs, quantity |
| **Float** | `real` | Angka desimal tanpa presisi ketat — face_match_score (0.0–1.0) |

---

## Referensi Schema per Tabel

---

### 1. roles

**Domain**: Otorisasi
**Deskripsi**: Menyimpan daftar peran pengguna dalam sistem. Setiap pengguna memiliki tepat satu peran yang menentukan hak aksesnya.
**Jumlah Kolom**: 4

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | INT (autoincrement) | No | autoincrement | PK | Identifier peran. Menggunakan integer karena tabel ini kecil dan bersifat referensi internal — ID jarang berubah. |
| `name` | VARCHAR(50) | No | — | UNIQUE | Nama peran (misal: `customer`, `provider`, `admin`). Di-unique agar tidak ada duplikat peran. |
| `description` | TEXT | Ya | — | — | Deskripsi singkat tentang peran. Bersifat opsional karena nama peran sudah cukup informatif. |
| `created_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu pembuatan record. Default `now()` agar otomatis terisi saat insert. |

**Relasi**:
- `roles.id` → `users.role_id` (satu peran memiliki banyak pengguna)

**Indeks**: Tidak ada (tabel kecil, full scan tidak masalah)

**Unique Constraints**: `name` (nama peran harus unik)

**Digunakan di Fitur**: Autentikasi, penentuan hak akses (customer/mitra/admin), middleware role guard

---

### 2. users

**Domain**: Autentikasi
**Deskripsi**: Tabel utama untuk semua pengguna Jasaku. Menyimpan kredensial login (email, password, Google ID) dan status akun. Satu user bisa punya profil customer DAN/OR profil mitra.
**Jumlah Kolom**: 14

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik global. UUID dipilih agar aman di URL dan tidak bisa ditebak, juga tidak bentrok antar environment (dev/staging/prod). |
| `role_id` | INT | No | — | FK → roles.id | Peran pengguna. Tidak nullable karena setiap user WAJIB punya peran. Menggunakan integer karena FK ke tabel `roles` yang pakai autoincrement. |
| `email` | VARCHAR(255) | Ya | — | UNIQUE, Index | Alamat email. Bisa null karena user bisa daftar via Google (email tidak selalu diisi). Unique agar tidak ada akun ganda. |
| `phone` | VARCHAR(20) | Ya | — | UNIQUE, Index | Nomor telepon. Bisa null (belum verifikasi). Unique agar tidak ada akun ganda dengan nomor yang sama. VARCHAR(20) cukup untuk format internasional. |
| `password_hash` | TEXT | Ya | — | — | Hash password (bcrypt). Bisa null karena user Google OAuth tidak punya password. |
| `google_id` | VARCHAR(255) | Ya | — | Unique, Index | ID unik dari Google OAuth. Bisa null karena user email/password tidak pakai Google. Di-index untuk performa login Google. |
| `is_phone_verified` | BOOLEAN | Ya | `false` | — | Flag apakah nomor telepon sudah diverifikasi via OTP. Default `false` karena verifikasi dilakukan terpisah. |
| `is_email_verified` | BOOLEAN | Ya | `false` | — | Flag apakah email sudah diverifikasi. Default `false`. |
| `status` | VARCHAR(20) | Ya | `"active"` | — | Status akun: `active`, `suspended`, `deleted`. Default `active` agar user langsung bisa pakai setelah daftar. |
| `created_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu akun dibuat. |
| `updated_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu terakhir update. Akan di-update otomatis oleh Prisma `@updatedAt`. |

**Relasi**:
- `users.role_id` → `roles.id` (satu user punya satu peran)
- `users.id` → `profiles_customer.user_id` (satu user bisa punya profil customer)
- `users.id` → `provider_profiles.user_id` (satu user bisa punya profil mitra)
- `users.id` → `provider_locations.provider_id` (satu user mitra punya satu lokasi)
- `users.id` → `custom_tasks.customer_id` (satu user bisa buat banyak tugas kustom)
- `users.id` → `reports.reporter_id` (satu user bisa kirim banyak laporan)
- `users.id` → `reviews.customer_id` / `reviews.provider_id` (satu user bisa punya banyak ulasan)
- `users.id` → `user_devices.user_id` (satu user bisa punya banyak perangkat)

**Indeks**:
- `idx_users_email` — kolom `email` untuk pencarian login
- `idx_users_google_id` — kolom `google_id` untuk login Google
- `idx_users_phone` — kolom `phone` untuk pencarian by telepon

**Unique Constraints**: `email`, `phone`

**Digunakan di Fitur**: Login (email/password + Google OAuth), registrasi, verifikasi OTP, manajemen akun admin, push notification (via user_devices)

---

### 3. profiles_customer

**Domain**: Profil Pelanggan
**Deskripsi**: Profil detail untuk pengguna berperan customer. Berisi data pribadi seperti nama lengkap, alamat, dan foto profil. Dihapus otomatis jika user dihapus (cascade).
**Jumlah Kolom**: 9

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik profil. |
| `user_id` | UUID | No | — | UNIQUE, FK → users.id | Referensi ke user pemilik profil. Unique karena satu user hanya punya satu profil customer. Cascade delete: jika user dihapus, profil ikut terhapus. |
| `full_name` | VARCHAR(150) | No | — | — | Nama lengkap customer. Wajib diisi. VARCHAR(150) cukup untuk nama panjang internasional. |
| `nickname` | VARCHAR(100) | Ya | — | — | Nama panggilan. Opsional — ditampilkan di UI sebagai ganti nama lengkap. |
| `birth_date` | DATE | Ya | — | — | Tanggal lahir. Hanya tanggal (bukan datetime) karena tidak perlu jam. Digunakan untuk verifikasi usia atau statistik demografi. |
| `gender` | VARCHAR(10) | Ya | — | — | Jenis kelamin: `Laki-laki`, `Perempuan`, dll. VARCHAR(10) cukup untuk opsi umum. |
| `address` | TEXT | Ya | — | — | Alamat lengkap customer. TEXT tanpa batas karena alamat bisa panjang. |
| `avatar_url` | TEXT | Ya | — | — | URL foto profil (biasanya dari Supabase Storage). |
| `created_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu profil dibuat. |
| `updated_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu terakhir update profil. |

**Relasi**:
- `profiles_customer.user_id` → `users.id` (satu profil milik satu user)
- `profiles_customer.id` → `orders.customer_id` (satu customer bisa punya banyak order)

**Indeks**:
- `idx_profiles_user_id` — kolom `user_id` untuk lookup cepat dari user ke profil

**Unique Constraints**: `user_id` (satu user hanya punya satu profil customer)

**Digunakan di Fitur**: Profil customer, data diri di order, checkout, histori pesanan

---

### 4. provider_profiles

**Domain**: Profil Mitra
**Deskripsi**: Profil detail untuk pengguna berperan mitra (provider). Berisi data pribadi, status verifikasi, rating, jumlah pekerjaan, portofolio, dan berbagai flag ketersediaan. Ini adalah tabel terbesar karena mitra memiliki banyak atribut bisnis.
**Jumlah Kolom**: 27

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik profil mitra. |
| `user_id` | UUID | No | — | UNIQUE, FK → users.id | Referensi ke user pemilik profil. Unique karena satu user hanya punya satu profil mitra. Cascade delete. |
| `full_name` | VARCHAR(100) | No | — | — | Nama lengkap mitra. Wajib diisi. |
| `nickname` | VARCHAR(50) | Ya | — | — | Nama panggilan. Lebih pendek dari customer karena ditampilkan di UI mitra. |
| `gender` | VARCHAR(10) | Ya | — | — | Jenis kelamin. |
| `birth_date` | DATE | Ya | — | — | Tanggal lahir. |
| `phone` | VARCHAR(20) | Ya | — | — | Nomor telepon mitra (bisa berbeda dari `users.phone`). |
| `address` | TEXT | Ya | — | — | Alamat rumah mitra. |
| `domicile` | VARCHAR(100) | Ya | — | — | Domisili kota/area tempat mitra beroperasi. Digunakan untuk pencarian mitra berdasarkan wilayah. |
| `profile_photo` | TEXT | Ya | — | — | URL foto profil mitra. |
| `ktp_photo` | TEXT | Ya | — | — | URL foto KTP mitra. Digunakan untuk verifikasi identitas. |
| `selfie_photo` | TEXT | Ya | — | — | URL selfie mitra. Digunakan untuk verifikasi wajah (face matching). |
| `is_verified` | BOOLEAN | Ya | `false` | — | Apakah mitra sudah diverifikasi secara keseluruhan. Default `false` — mitra baru belum terverifikasi. |
| `verification_status` | VARCHAR(20) | Ya | `"pending"` | — | Status verifikasi: `pending`, `approved`, `rejected`. Default `pending`. |
| `verification_notes` | TEXT | Ya | — | — | Catatan dari admin saat review verifikasi. Misal: alasan penolakan. |
| `is_active` | BOOLEAN | Ya | `true` | — | Apakah akun mitra aktif. Bisa di-nonaktifkan oleh admin. Default `true`. |
| `onboarding_completed` | BOOLEAN | Ya | `false` | — | Apakah mitra sudah menyelesaikan proses onboarding awal. Default `false`. |
| `custom_task_enabled` | BOOLEAN | Ya | `false` | — | Apakah mitra mengaktifkan fitur tugas kustom. Default `false` — mitra harus opt-in. |
| `service_available` | BOOLEAN | No | `true` | — | Apakah mitra tersedia untuk menerima order layanan. Default `true`. |
| `task_available` | BOOLEAN | No | `true` | — | Apakah mitra tersedia untuk menerima tugas kustom. Default `true`. |
| `rating` | DECIMAL(2,1) | Ya | `0` | — | Rating rata-rata mitra (0.0–5.0). DECIMAL(2,1) memberikan satu angka desimal — cukup untuk rating bintang. Default `0` (belum ada ulasan). |
| `total_jobs` | INT | Ya | `0` | — | Total jumlah pekerjaan yang sudah diselesaikan. Counter yang di-increment setiap order selesai. Default `0`. |
| `created_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu profil dibuat. |
| `updated_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu terakhir update. |
| `total_reviews` | INT | Ya | `0` | — | Total jumlah ulasan yang diterima. Counter terpisah dari `total_jobs` karena tidak semua order punya ulasan. Default `0`. |
| `portfolios` | TEXT[] | Ya | `{}` | — | Array URL foto portofolio. PostgreSQL array memungkinkan beberapa URL disimpan dalam satu kolom tanpa tabel terpisah. Default array kosong. |

**Relasi**:
- `provider_profiles.user_id` → `users.id` (satu profil milik satu user)
- `provider_profiles.id` → `orders.provider_id` (satu mitra bisa punya banyak order)
- `provider_profiles.id` → `provider_documents.provider_id` (satu mitra punya banyak dokumen)
- `provider_profiles.id` → `provider_schedules.provider_id` (satu mitra punya banyak jadwal)
- `provider_profiles.id` → `task_providers.provider_id` (satu mitra bisa ikut banyak tugas)
- `provider_profiles.id` → `identity_verifications.provider_id` (satu mitra punya satu record verifikasi)

**Indeks**: Tidak ada indeks eksplisit (lookup dilakukan via `users` → `provider_profiles` relasi)

**Unique Constraints**: `user_id`

**Digunakan di Fitur**: Dashboard mitra, profil publik mitra, verifikasi mitra, pencarian mitra berdasarkan rating/domisili, portofolio, manajemen ketersediaan

---

### 5. provider_locations

**Domain**: Lokasi Mitra
**Deskripsi**: Menyimpan lokasi geospasial mitra secara real-time. Menggunakan PostGIS `geometry` untuk pencarian berbasis jarak (misal: "mitra terdekat 5km dari saya"). Satu mitra hanya punya satu record lokasi yang di-update berkala.
**Jumlah Kolom**: 4

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik record lokasi. |
| `provider_id` | UUID | No | — | UNIQUE, FK → users.id | Referensi ke user mitra. Unique karena satu mitra hanya punya satu lokasi aktif (di-update, bukan ditambah baru). |
| `address` | TEXT | Ya | — | — | Alamat teks lokasi mitra. Bisa null jika hanya koordinat yang dikirim. |
| `location` | geometry | Ya | — | — | Koordinat geospasial (Point, SRID 4326 = WGS84). Kolom PostGIS yang mendukung query spasial seperti ST_Distance(), ST_DWithin(). Bisa null jika lokasi belum di-set. |

**Relasi**:
- `provider_locations.provider_id` → `users.id` (satu lokasi milik satu user mitra)

**Indeks**:
- `provider_locations_geo_idx` (GiST) — indeks spasial pada kolom `location`. GiST (Generalized Search Tree) adalah tipe indeks khusus PostGIS untuk query geospasial. Tanpa indeks ini, pencarian "mitra terdekat" akan melakukan full table scan.

**Unique Constraints**: `provider_id`

**Digunakan di Fitur**: Live tracking lokasi mitra, pencarian mitra terdekat (radius), peta dashboard mitra, order tracking

---

### 6. provider_documents

**Domain**: Dokumen Mitra
**Deskripsi**: Menyimpan dokumen-dokumen yang diunggah mitra (sertifikat, izin usah, dll). Setiap dokumen punya tipe dan bisa dikategorikan. Jika mitra dihapus, semua dokumennya ikut terhapus (cascade).
**Jumlah Kolom**: 7

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik dokumen. |
| `provider_id` | UUID | No | — | FK → profiles_provider.id (CASCADE) | Referensi ke profil mitra. Cascade delete: jika profil mitra dihapus, semua dokumen ikut terhapus. |
| `type` | VARCHAR(30) | No | — | — | Tipe dokumen: `sertifikat`, `izin_usaha`, `ktp`, `selfie`, dll. VARCHAR(30) cukup untuk nama tipe dokumen. |
| `file_url` | TEXT | No | — | — | URL file dokumen (biasanya dari Supabase Storage). Wajib diisi. |
| `category_id` | UUID | Ya | — | FK → categories.id | Kategori layanan yang terkait dokumen. Bisa null jika dokumen bersifat umum (bukan spesifik kategori). |
| `description` | TEXT | Ya | — | — | Deskripsi atau catatan tentang dokumen. |
| `created_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu dokumen diunggah. |

**Relasi**:
- `provider_documents.provider_id` → `provider_profiles.id` (satu mitra punya banyak dokumen)
- `provider_documents.category_id` → `categories.id` (opsional — dokumen terkait kategori tertentu)

**Indeks**:
- Index pada `provider_id` — untuk lookup cepat semua dokumen milik satu mitra

**Unique Constraints**: Tidak ada (satu mitra bisa punya banyak dokumen dengan tipe yang sama)

**Digunakan di Fitur**: Upload dokumen mitra, review dokumen oleh admin, verifikasi dokumen kategori

---

### 7. provider_payout_methods

**Domain**: Pembayaran Mitra
**Deskripsi**: Menyimpan metode pencairan dana (payout) yang dimiliki mitra. Mitra bisa punya beberapa metode: rekening bank, e-wallet, dll.
**Jumlah Kolom**: 7

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik metode payout. |
| `provider_id` | UUID | No | — | FK → users.id (implicit) | Referensi ke user mitra. Tidak ada cascade karena menggunakan relasi langsung ke users. |
| `type` | VARCHAR(50) | Ya | — | — | Tipe metode: `bank_transfer`, `e_wallet`, `qris`. VARCHAR(50) cukup untuk berbagai jenis. |
| `provider_name` | VARCHAR(100) | Ya | — | — | Nama penyedia: `Bank BCA`, `GoPay`, `OVO`, dll. |
| `account_number` | VARCHAR(100) | Ya | — | — | Nomor rekening/e-wallet. VARCHAR(100) untuk mengakomodasi berbagai format. |
| `account_name` | VARCHAR(150) | Ya | — | — | Nama pemilik rekening. VARCHAR(150) cukup untuk nama panjang. |
| `created_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu metode ditambahkan. |

**Relasi**: Tidak ada relasi Prisma formal — `provider_id` merujuk ke `users.id` secara logika

**Indeks**: Tidak ada

**Unique Constraints**: Tidak ada (satu mitra bisa punya beberapa metode payout)

**Digunakan di Fitur**: Pengaturan metode pembayaran mitra, proses payout/pencairan dana

---

### 8. provider_schedules

**Domain**: Jadwal Mitra
**Deskripsi**: Menyimpan jadwal ketersediaan mitra per hari. Setiap mitra bisa punya satu record per tanggal — menandakan apakah tanggal itu sudah terisi (booked) atau belum. Digunakan untuk mencegah double-booking.
**Jumlah Kolom**: 6

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik jadwal. |
| `provider_id` | UUID | No | — | FK → profiles_provider.id | Referensi ke profil mitra. |
| `work_date` | DATE | No | — | UNIQUE(provider_id, work_date) | Tanggal kerja. Tipe DATE (bukan DATETIME) karena hanya tanggal yang penting — tidak ada jam spesifik dalam jadwal. |
| `is_booked` | BOOLEAN | No | `false` | — | Apakah tanggal sudah terisi order. Default `false` — tanggal baru tersedia. |
| `order_id` | UUID | Ya | — | FK → orders.id | Order yang mengisi tanggal ini. Bisa null jika tanggal belum terisi (is_booked = false). |
| `created_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu jadwal dibuat. |

**Relasi**:
- `provider_schedules.provider_id` → `provider_profiles.id` (satu mitra punya banyak jadwal)
- `provider_schedules.order_id` → `orders.id` (satu jadwal terkait satu order)

**Indeks**:
- Composite index pada `provider_id` + `work_date` — untuk lookup cepat jadwal mitra pada tanggal tertentu

**Unique Constraints**: Composite `provider_id` + `work_date` — memastikan satu mitra hanya punya satu record per tanggal (mencegah double-booking)

**Digunakan di Fitur**: Cek ketersediaan mitra saat checkout, kalender jadwal mitra, pencegahan double-booking, operasional hours check

---

### 9. provider_services

**Domain**: Layanan Mitra
**Deskripsi**: Menyimpan daftar layanan yang ditawarkan oleh setiap mitra. Ini adalah tabel penghubung antara mitra (`provider_profiles`) dan layanan (`services`). Satu mitra bisa menawarkan banyak layanan.
**Jumlah Kolom**: 5

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik hubungan mitra-layanan. |
| `provider_id` | UUID | No | — | FK → profiles_provider.id | Referensi ke profil mitra. |
| `service_id` | UUID | No | — | FK → services.id | Referensi ke layanan yang ditawarkan. |
| `description` | TEXT | Ya | — | — | Deskripsi khusus mitra untuk layanan ini (bisa berbeda dari deskripsi umum layanan). |
| `created_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu layanan ditambahkan ke profil mitra. |

**Relasi**:
- `provider_services.provider_id` → (implicit) `provider_profiles.id`
- `provider_services.service_id` → `services.id` (satu layanan ditawarkan oleh banyak mitra)
- `provider_services.id` → `provider_service_prices.provider_service_id` (satu layanan mitra punya banyak opsi harga)

**Indeks**: Tidak ada eksplisit (diakses via relasi)

**Unique Constraints**: Tidak ada eksplisit dalam schema (kemungkinan diatur di aplikasi)

**Digunakan di Fitur**: Pencarian mitra berdasarkan layanan, daftar layanan mitra, pemesanan layanan

---

### 10. provider_service_prices

**Domain**: Harga Layanan Mitra
**Deskripsi**: Menyimpan harga spesifik yang ditawarkan mitra untuk setiap layanan. Satu layanan mitra bisa punya beberapa tipe harga (misal: harga per meter persegi, harga per jam, harga tetap).
**Jumlah Kolom**: 6

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik harga. |
| `provider_service_id` | UUID | No | — | FK → provider_services.id | Referensi ke layanan mitra. |
| `pricing_type_id` | UUID | No | — | FK → pricing_types.id | Tipe harga (per jam, per meter, tetap, dll). |
| `price` | DECIMAL(12,2) | No | — | — | Harga dalam Rupiah. DECIMAL(12,2) memberikan presisi hingga Rp 999.999.999.999,99 — cukup untuk harga apapun tanpa error pembulatan. |
| `created_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu harga dibuat. |
| `unit` | TEXT | Ya | — | — | Satuan harga (misal: `meter`, `jam`, `meter_persegi`). Bersifat fleksibel karena bisa berbeda per tipe harga. |

**Relasi**:
- `provider_service_prices.provider_service_id` → `provider_services.id` (satu layanan mitra punya banyak opsi harga)
- `provider_service_prices.pricing_type_id` → `pricing_types.id` (satu tipe harga digunakan di banyak tempat)

**Indeks**: Tidak ada eksplisit

**Unique Constraints**: Tidak ada

**Digunakan di Fitur**: Pencarian harga layanan, perhitungan total harga saat checkout, perbandingan harga antar mitra

---

### 11. identity_verifications

**Domain**: Verifikasi Identitas
**Deskripsi**: Menyimpan hasil verifikasi identitas mitra menggunakan teknologi OCR dan face matching. Data diambil dari KTP (via OCR) dan dibandingkan dengan selfie mitra. Satu mitra hanya punya satu record verifikasi.
**Jumlah Kolom**: 15

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik verifikasi. |
| `provider_id` | UUID | No | — | UNIQUE, FK → profiles_provider.id (CASCADE) | Referensi ke profil mitra. Unique karena satu mitra hanya verifikasi sekali. Cascade delete. |
| `nik` | TEXT | Ya | — | — | Nomor Induk Kependudukan (16 digit). Bersifat opsional di schema — bisa diisi via OCR atau manual. |
| `ocr_full_name` | TEXT | Ya | — | — | Nama lengkap hasil ekstraksi OCR dari KTP. Bisa berbeda dari `provider_profiles.full_name` jika ada kesalahan input. |
| `ocr_birth_place` | TEXT | Ya | — | — | Tempat lahir hasil OCR. |
| `ocr_birth_date` | TEXT | Ya | — | — | Tanggal lahir hasil OCR. Disimpan sebagai TEXT (bukan DATE) karena format asli dari OCR mungkin tidak standar — perlu parsing di aplikasi. |
| `ocr_address` | TEXT | Ya | — | — | Alamat sesuai KTP hasil OCR. |
| `ocr_gender` | TEXT | Ya | — | — | Jenis kelamin hasil OCR. |
| `ocr_blood_type` | TEXT | Ya | — | — | Golongan darah hasil OCR (dari KTP lama). |
| `ocr_religion` | TEXT | Ya | — | — | Agama hasil OCR (dari KTP). |
| `ocr_raw_result` | JsonB | Ya | — | — | Hasil mentah dari OCR dalam format JSON. JsonB memungkinkan query terhadap field spesifik di dalam JSON (misal: `ocr_raw_result->>'confidence'`). Menyimpan raw result berguna untuk debugging. |
| `face_match_score` | FLOAT | Ya | — | — | Skor kecocokan wajah antara KTP dan selfie (0.0–1.0). FLOAT cukup karena skor ini tidak memerlukan presisi keuangan. |
| `face_match_status` | VARCHAR(20) | No | `"pending"` | — | Status face matching: `pending`, `matched`, `mismatched`. Default `pending`. |
| `liveness_data` | JsonB | Ya | — | — | Data liveness detection (memastikan selfie bukan foto/gambar). Disimpan dalam format JSON. |
| `liveness_status` | VARCHAR(20) | No | `"pending"` | — | Status liveness: `pending`, `passed`, `failed`. Default `pending`. |
| `created_at` | TIMESTAMP(6) | No | `now()` | — | Waktu verifikasi dibuat. Tidak nullable. |
| `verified_at` | TIMESTAMP(6) | Ya | — | — | Waktu verifikasi selesai diproses (oleh sistem atau admin). |

**Relasi**:
- `identity_verifications.provider_id` → `provider_profiles.id` (satu mitra punya satu record verifikasi)

**Indeks**:
- Index pada `provider_id` — untuk lookup cepat status verifikasi mitra

**Unique Constraints**: `provider_id`

**Digunakan di Fitur**: Onboarding mitra, verifikasi KTP via OCR, face matching, liveness detection, review verifikasi oleh admin

---

### 12. categories

**Domain**: Kategori Layanan
**Deskripsi**: Menyimpan kategori-kategori layanan yang tersedia di Jasaku (misal: "Kebersihan", "Perbaikan", "Renovasi"). Setiap layanan wajib masuk dalam satu kategori.
**Jumlah Kolom**: 5

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik kategori. |
| `name` | VARCHAR(100) | No | — | — | Nama kategori. VARCHAR(100) cukup untuk nama kategori pendek. |
| `description` | TEXT | Ya | — | — | Deskripsi kategori. Bersifat opsional — nama kategori biasanya sudah jelas. |
| `created_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu kategori dibuat. |
| `icon_url` | TEXT | Ya | — | — | URL ikon kategori. Ditampilkan di UI sebagai ikon visual. |

**Relasi**:
- `categories.id` → `services.category_id` (satu kategori memiliki banyak layanan)
- `categories.id` → `pricing_types.category_id` (satu kategori bisa punya tipe harga khusus)
- `categories.id` → `provider_documents.category_id` (opsional — dokumen terkait kategori)

**Indeks**: Tidak ada (tabel referensi kecil)

**Unique Constraints**: Tidak ada di schema (kemungkinan di-handle di aplikasi)

**Digunakan di Fitur**: Katalog layanan, filter pencarian berdasarkan kategori, navigasi kategori di UI

---

### 13. services

**Domain**: Layanan
**Deskripsi**: Menyimpan daftar layanan spesifik dalam satu kategori (misal: dalam kategori "Kebersihan" ada layanan "Cuci Karpet", "Cuci Sofa", "Bersih-bersih Rumah"). Setiap layanan dimiliki oleh tepat satu kategori.
**Jumlah Kolom**: 5

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik layanan. |
| `category_id` | UUID | No | — | FK → categories.id | Referensi ke kategori induk. Wajib diisi — setiap layanan harus punya kategori. |
| `name` | VARCHAR(150) | No | — | — | Nama layanan. VARCHAR(150) cukup untuk nama deskriptif. |
| `description` | TEXT | Ya | — | — | Deskripsi detail layanan. |
| `created_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu layanan dibuat. |

**Relasi**:
- `services.category_id` → `categories.id` (satu layanan milik satu kategori)
- `services.id` → `provider_services.service_id` (satu layanan ditawarkan oleh banyak mitra)
- `services.id` → `order_items.service_id` (satu layanan muncul di banyak order item)

**Indeks**: Tidak ada eksplisit

**Unique Constraints**: Tidak ada

**Digunakan di Fitur**: Katalog layanan, pencarian layanan, checkout (memilih layanan), mitra mendaftarkan layanan

---

### 14. pricing_types

**Domain**: Tipe Harga
**Deskripsi**: Menyimpan jenis-jenis metode penentuan harga (misal: "Per Jam", "Per Meter Persegi", "Harga Tetap"). Setiap tipe harga bisa dikaitkan dengan kategori tertentu.
**Jumlah Kolom**: 5

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik tipe harga. |
| `name` | VARCHAR(50) | No | — | — | Nama tipe harga: `per_jam`, `per_meter_persegi`, `harga_tetap`, dll. VARCHAR(50) cukup untuk nama pendek. |
| `description` | TEXT | Ya | — | — | Deskripsi tipe harga. |
| `default_unit` | TEXT | Ya | — | — | Satuan default (misal: `jam`, `meter`, `meter_persegi`). |
| `category_id` | UUID | Ya | — | FK → categories.id | Kategori terkait. Bisa null jika tipe harga berlaku umum untuk semua kategori. |

**Relasi**:
- `pricing_types.category_id` → `categories.id` (opsional — tipe harga bisa spesifik per kategori)
- `pricing_types.id` → `provider_service_prices.pricing_type_id` (satu tipe harga digunakan di banyak tempat)

**Indeks**: Tidak ada

**Unique Constraints**: Tidak ada

**Digunakan di Fitur**: Penentuan harga layanan, input harga oleh mitra, tampilan harga di UI

---

### 15. orders

**Domain**: Pesanan
**Deskripsi**: Tabel pusat transaksi Jasaku. Menyimpan semua informasi pesanan dari customer ke mitra — termasuk status, harga, jadwal, dan hubungan ke entitas terkait (payment, review, lampiran). Ini adalah tabel terpenting dalam sistem.
**Jumlah Kolom**: 20

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik order. UUID untuk keamanan URL — customer bisa share link order tanpa takut ID bisa ditebak. |
| `customer_id` | UUID | No | — | FK → profiles_customer.id | Customer yang membuat order. |
| `provider_id` | UUID | No | — | FK → provider_profiles.id | Mitra yang menerima order. |
| `custom_task_id` | UUID | Ya | — | FK → custom_tasks.id | Jika order ini berasal dari tugas kustom, referensi ke tugasnya. Bisa null untuk order biasa. |
| `task_provider_id` | UUID | Ya | — | FK → task_providers.id | Referensi ke record task_providers jika order dari tugas kustom. |
| `status` | VARCHAR(30) | Ya | `"pending"` | — | Status order: `pending`, `accepted`, `on_the_way`, `arrived`, `in_progress`, `completed`, `cancelled`. Default `pending`. VARCHAR(30) cukup untuk status panjang. |
| `total_price` | DECIMAL(12,2) | Ya | — | — | Total harga order. Bisa null saat awal dibuat (belum dihitung). DECIMAL(12,2) untuk presisi uang. |
| `platform_fee` | DECIMAL(12,2) | Ya | — | — | Fee platform Jasaku. Diambil dari `total_price` * persentase fee. |
| `additional_fee` | DECIMAL(12,2) | Ya | `0` | — | Biaya tambahan (materai, transport, dll). Default `0` — order normal tanpa biaya tambahan. |
| `description` | TEXT | Ya | — | — | Catatan atau deskripsi tambahan dari customer. |
| `work_date` | DATE | Ya | — | — | Tanggal pengerjaan. DATE (bukan DATETIME) karena hanya tanggal yang relevan — jam ditentukan terpisah. |
| `created_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu order dibuat. |
| `start_date` | TIMESTAMP(6) | Ya | — | — | Waktu mulai pengerjaan. Diisi saat mitra mulai bekerja. |
| `end_date` | TIMESTAMP(6) | Ya | — | — | Waktu selesai pengerjaan. Diisi saat order selesai. |
| `assignment_type` | VARCHAR(20) | Ya | `"manual"` | — | Tipe penugasan: `manual` (customer pilih mitra) atau `auto` (sistem tentukan). Default `manual`. |
| `payout_confirmed` | BOOLEAN | No | `false` | — | Apakah payout ke mitra sudah dikonfirmasi. Default `false`. |
| `payout_at` | TIMESTAMP(6) | Ya | — | — | Waktu payout dilakukan. |

**Relasi**:
- `orders.customer_id` → `profiles_customer.id` (satu customer punya banyak order)
- `orders.provider_id` → `provider_profiles.id` (satu mitra punya banyak order)
- `orders.custom_task_id` → `custom_tasks.id` (opsional — order dari tugas kustom)
- `orders.task_provider_id` → `task_providers.id` (opsional)
- `orders.id` → `order_items.order_id` (satu order punya banyak item)
- `orders.id` → `order_locations.order_id` (satu order punya banyak lokasi)
- `orders.id` → `order_attachments.order_id` (satu order punya banyak lampiran)
- `orders.id` → `payments.order_id` (satu order punya banyak pembayaran)
- `orders.id` → `reviews.order_id` (satu order punya satu ulasan)
- `orders.id` → `provider_schedules.order_id` (satu order mengisi satu jadwal)
- `orders.id` → `order_extensions.order_id` (satu order bisa punya banyak perpanjangan)

**Indeks**: Tidak ada eksplisit (diakses via relasi foreign key)

**Unique Constraints**: Tidak ada

**Digunakan di Fitur**: CRUD order, tracking status order, perhitungan harga, histori pesanan, payout, ulasan, perpanjangan order

---

### 16. order_items

**Domain**: Item Pesanan
**Deskripsi**: Menyimpan detail item dalam satu order. Satu order bisa memiliki beberapa item layanan dengan harga dan jumlah masing-masing. Mirip tabel "keranjang belanja" dalam e-commerce.
**Jumlah Kolom**: 7

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik item. |
| `order_id` | UUID | No | — | FK → orders.id | Order pemilik item ini. |
| `service_id` | UUID | No | — | FK → services.id | Layanan yang dipesan. |
| `pricing_type_id` | UUID | No | — | FK → pricing_types.id | Tipe harga yang digunakan (per jam, per meter, dll). |
| `quantity` | INT | Ya | `1` | — | Jumlah unit. Default `1` — minimal satu unit. Bisa null (diperlakukan sebagai 1). |
| `price` | DECIMAL(12,2) | Ya | — | — | Harga per unit saat order dibuat. Disimpan snapshot agar tidak berubah jika harga mitra berubah setelah order. |
| `subtotal` | DECIMAL(12,2) | Ya | — | — | `quantity` * `price`. Juga disimpan sebagai snapshot. |

**Relasi**:
- `order_items.order_id` → `orders.id` (satu order punya banyak item)
- `order_items.service_id` → `services.id` (satu layanan muncul di banyak item)
- `order_items` → `pricing_types.id` (satu tipe harga digunakan di banyak item)

**Indeks**: Tidak ada eksplisit

**Unique Constraints**: Tidak ada

**Digunakan di Fitur**: Detail order, perhitungan total harga, ringkasan order di UI, faktur

---

### 17. order_locations

**Domain**: Lokasi Pesanan
**Deskripsi**: Menyimpan lokasi geospasial terkait order (alamat tujuan layanan). Menggunakan PostGIS geometry untuk pencarian dan perhitungan jarak.
**Jumlah Kolom**: 4

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik lokasi order. |
| `order_id` | UUID | No | — | FK → orders.id | Order pemilik lokasi ini. |
| `address` | TEXT | Ya | — | — | Alamat teks lokasi. Bisa null jika hanya koordinat yang dikirim. |
| `location` | geometry | Ya | — | — | Koordinat geospasial (Point, WGS84). Digunakan untuk menampilkan di peta dan menghitung jarak ke mitra. |

**Relasi**:
- `order_locations.order_id` → `orders.id` (satu order bisa punya banyak lokasi)

**Indeks**: Tidak ada eksplisit (bisa ditambahkan jika pencarian lokasi order sering dilakukan)

**Unique Constraints**: Tidak ada

**Digunakan di Fitur**: Menampilkan lokasi order di peta, perhitungan jarak ke mitra, order tracking

---

### 18. order_attachments

**Domain**: Lampiran Pesanan
**Deskripsi**: Menyimpan file lampiran yang diunggah customer saat membuat order (misal: foto kondisi barang, foto rumah yang akan dibersihkan).
**Jumlah Kolom**: 4

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik lampiran. |
| `order_id` | UUID | No | — | FK → orders.id | Order pemilik lampiran ini. |
| `file_url` | TEXT | No | — | — | URL file lampiran (biasanya dari Supabase Storage). Wajib diisi. Tidak pakai VARCHAR karena URL bisa sangat panjang. |
| `created_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu lampiran diunggah. |

**Relasi**:
- `order_attachments.order_id` → `orders.id` (satu order punya banyak lampiran)

**Indeks**: Tidak ada

**Unique Constraints**: Tidak ada

**Digunakan di Fitur**: Upload foto saat checkout, melihat lampiran order di detail order, lampiran untuk mitra

---

### 19. order_extensions

**Domain**: Perpanjangan Pesanan
**Deskripsi**: Menyimpan permintaan perpanjangan waktu pengerjaan order. Jika pengerjaan membutuhkan lebih banyak waktu dari jadwal awal, mitra atau customer bisa meminta perpanjangan dengan biaya tambahan.
**Jumlah Kolom**: 11

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik perpanjangan. |
| `order_id` | UUID | No | — | FK → orders.id | Order yang diperpanjang. |
| `provider_id` | UUID | No | — | — | Mitra yang meminta perpanjangan. |
| `customer_id` | UUID | No | — | — | Customer pemilik order. |
| `requested_date` | DATE | No | — | — | Tanggal yang diminta untuk perpanjangan. DATE karena hanya tanggal yang penting. |
| `additional_cost` | DECIMAL(12,2) | No | — | — | Biaya tambahan untuk perpanjangan. DECIMAL(12,2) untuk presisi uang. |
| `platform_fee_rate` | DECIMAL(3,2) | No | — | — | Persentase fee platform untuk perpanjangan (misal: 5.00 = 5%). DECIMAL(3,2) cukup untuk persentase hingga 99.99%. |
| `extension_count` | INT | No | `1` | — | Berapa kali perpanjangan sudah dilakukan. Default `1` — perpanjangan pertama. |
| `status` | VARCHAR(20) | No | `"pending"` | — | Status perpanjangan: `pending`, `accepted`, `rejected`, `completed`. Default `pending`. |
| `response_note` | TEXT | Ya | — | — | Catatan respons dari customer (saat accept/reject). |
| `created_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu perpanjangan diajukan. |

**Relasi**:
- `order_extensions.order_id` → `orders.id` (satu order bisa punya banyak perpanjangan)

**Indeks**:
- Index pada `order_id` — untuk lookup cepat semua perpanjangan suatu order

**Unique Constraints**: Tidak ada

**Digunakan di Fitur**: Pengajuan perpanjangan waktu kerja, approval perpanjangan oleh customer, biaya tambahan perpanjangan

---

### 20. payments

**Domain**: Pembayaran
**Deskripsi**: Menyimpan informasi pembayaran untuk setiap order. Mendukung beberapa metode pembayaran (transfer bank, e-wallet, QRIS) dan bisa memiliki beberapa record pembayaran per order (jika customer membayar bertahap).
**Jumlah Kolom**: 8

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik pembayaran. |
| `order_id` | UUID | No | — | FK → orders.id | Order yang dibayar. |
| `method` | VARCHAR(50) | Ya | — | — | Metode pembayaran: `bank_transfer`, `e_wallet`, `qris`, `cash`. Bisa null jika belum ditentukan. |
| `status` | VARCHAR(30) | Ya | `"pending"` | — | Status pembayaran: `pending`, `paid`, `failed`, `refunded`. Default `pending`. |
| `amount` | DECIMAL(12,2) | Ya | — | — | Jumlah yang dibayarkan. DECIMAL(12,2) untuk presisi uang. Bisa null jika status masih pending. |
| `paid_at` | TIMESTAMP(6) | Ya | — | — | Waktu pembayaran berhasil. |
| `created_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu record pembayaran dibuat. |
| `payment_proof` | TEXT | Ya | — | — | URL bukti pembayaran (foto struk/transfer). TEXT karena URL bisa panjang. |

**Relasi**:
- `payments.order_id` → `orders.id` (satu order bisa punya banyak pembayaran)

**Indeks**: Tidak ada eksplisit

**Unique Constraints**: Tidak ada (satu order bisa punya beberapa pembayaran)

**Digunakan di Fitur**: Pembayaran order, upload bukti transfer, verifikasi pembayaran, riwayat pembayaran

---

### 21. reviews

**Domain**: Ulasan
**Deskripsi**: Menyimpan ulasan dan rating dari customer untuk mitra setelah order selesai. Satu order hanya bisa punya satu ulasan (unique constraint pada order_id).
**Jumlah Kolom**: 8

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik ulasan. |
| `order_id` | UUID | No | — | UNIQUE, FK → orders.id | Order yang diulas. Unique karena satu order hanya bisa diulas sekali. Cascade delete. |
| `customer_id` | UUID | No | — | FK → users.id | Customer yang menulis ulasan. Cascade delete. |
| `provider_id` | UUID | No | — | FK → users.id | Mitra yang diulas. Cascade delete. |
| `rating` | INT | No | — | — | Rating 1–5 (bintang). Tipe INT karena hanya bilangan bulat yang diperlukan. |
| `review` | TEXT | Ya | — | — | Teks ulasan. Bisa null jika customer hanya memberi rating tanpa komentar. |
| `created_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu ulasan dibuat. |
| `updated_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu ulasan terakhir diupdate. |

**Relasi**:
- `reviews.order_id` → `orders.id` (satu order punya satu ulasan)
- `reviews.customer_id` → `users.id` (satu customer menulis banyak ulasan)
- `reviews.provider_id` → `users.id` (satu mitra menerima banyak ulasan)

**Indeks**: Tidak ada eksplisit (diakses via relasi)

**Unique Constraints**: `order_id`

**Digunakan di Fitur**: Menulis ulasan, menampilkan ulasan di profil mitra, menghitung rating rata-rata mitra

---

### 22. reports

**Domain**: Laporan
**Deskripsi**: Menyimpan laporan/keluhan dari pengguna (customer atau mitra) ke admin. Bisa terkait order tertentu atau umum. Admin bisa merespons dan menandai laporan sebagai selesai.
**Jumlah Kolom**: 11

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik laporan. |
| `reporter_id` | UUID | No | — | FK → users.id | Pengguna yang melaporkan. |
| `reporter_role` | VARCHAR(20) | No | — | — | Peran pelapor: `customer` atau `provider`. VARCHAR(20) cukup untuk peran pendek. Disimpan di sini untuk query cepat tanpa join ke tabel users. |
| `order_id` | UUID | Ya | — | — | Order terkait laporan. Bisa null untuk laporan umum (bukan spesifik order). |
| `subject` | VARCHAR(200) | No | — | — | Subjek/judul laporan. VARCHAR(200) cukup untuk ringkasan singkat. |
| `description` | TEXT | No | — | — | Deskripsi detail laporan. TEXT tanpa batas karena laporan bisa panjang. |
| `attachments` | TEXT[] | No | `{}` | — | Array URL lampiran (foto/bukti). PostgreSQL array untuk beberapa URL. Default array kosong. |
| `status` | VARCHAR(20) | No | `"open"` | — | Status laporan: `open`, `in_progress`, `resolved`, `closed`. Default `open`. |
| `admin_response` | TEXT | Ya | — | — | Respon dari admin. Bisa null jika belum ditanggapi. |
| `created_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu laporan dibuat. |
| `updated_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu laporan terakhir diupdate. |
| `resolved_at` | TIMESTAMP(6) | Ya | — | — | Waktu laporan diselesaikan. Bisa null jika belum selesai. |

**Relasi**:
- `reports.reporter_id` → `users.id` (satu user mengirim banyak laporan)

**Indeks**:
- Index pada `reporter_id` — untuk lookup cepat laporan berdasarkan pelapor
- Index pada `status` — untuk filter laporan berdasarkan status (open, in_progress, dll)

**Unique Constraints**: Tidak ada (satu user bisa melaporkan banyak hal)

**Digunakan di Fitur**: Pengiriman laporan/keluhan, manajemen laporan oleh admin, notifikasi status laporan

---

### 23. custom_tasks

**Domain**: Tugas Kustom
**Deskripsi**: Menyimpan tugas kustom yang dibuat oleh customer. Berbeda dari order biasa, tugas kustom bersifat "open" — customer menawarkan pekerjaan dan mitra yang berminat bisa menerima. Mendukung multiple mitra untuk satu tugas.
**Jumlah Kolom**: 18

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik tugas kustom. |
| `customer_id` | UUID | No | — | FK → users.id | Customer yang membuat tugas. |
| `title` | VARCHAR(150) | No | — | — | Judul tugas. VARCHAR(150) cukup untuk judul deskriptif. Wajib diisi. |
| `description` | TEXT | Ya | — | — | Deskripsi detail tugas. |
| `budget_per_person` | DECIMAL(12,0) | No | — | — | Budget per mitra yang menerima. DECIMAL(12,0) — tanpa desimal karena budget tugas kustom dalam Rupiah bulat. |
| `required_people` | INT | No | `1` | — | Jumlah mitra yang dibutuhkan. Default `1`. |
| `accepted_count` | INT | No | `0` | — | Jumlah mitra yang sudah menerima. Counter yang di-increment. Default `0`. |
| `platform_fee_rate` | DECIMAL(4,2) | No | `5.00` | — | Persentase fee platform. Default 5%. DECIMAL(4,2) untuk presisi hingga 99.99%. |
| `address` | TEXT | Ya | — | — | Alamat lokasi tugas. |
| `location_detail` | TEXT | Ya | — | — | Detail lokasi (blok, nomor rumah, patokan, dll). |
| `publish_days` | INT | No | `1` | — | Berapa hari tugas akan ditampilkan. Default `1` (satu hari). |
| `expires_at` | TIMESTAMP(6) | Ya | — | — | Waktu kadaluarsa tugas. Bisa null jika tidak ada batas waktu. |
| `payment_proof` | TEXT | Ya | — | — | URL bukti pembayaran budget tugas. |
| `payment_status` | VARCHAR(30) | No | `"unpaid"` | — | Status pembayaran: `unpaid`, `proof_uploaded`, `paid`. Default `unpaid`. |
| `location` | geometry | Ya | — | — | Koordinat geospasial lokasi tugas. |
| `status` | VARCHAR(30) | No | `"open"` | — | Status tugas: `open`, `in_progress`, `active`, `completed`, `fulfilled`, `expired`, `cancelled`. Default `open`. |
| `created_at` | TIMESTAMP(6) | No | `now()` | — | Waktu tugas dibuat. Tidak nullable. |
| `updated_at` | TIMESTAMP(6) | No | `@updatedAt` | — | Waktu terakhir update. Dikelola oleh Prisma. Tidak nullable. |

**Relasi**:
- `custom_tasks.customer_id` → `users.id` (satu customer membuat banyak tugas)
- `custom_tasks.id` → `task_locations.task_id` (satu tugas punya banyak lokasi)
- `custom_tasks.id` → `task_providers.task_id` (satu tugas punya banyak mitra penerima)
- `custom_tasks.id` → `orders.custom_task_id` (satu tugas menghasilkan banyak order)

**Indeks**: Tidak ada eksplisit

**Unique Constraints**: Tidak ada

**Digunakan di Fitur**: Membuat tugas kustom, pencarian tugas oleh mitra, penerimaan tugas, pembayaran budget, tracking status tugas

---

### 24. task_locations

**Domain**: Lokasi Tugas
**Deskripsi**: Menyimpan lokasi-lokasi terkait satu tugas kustom. Sebuah tugas bisa memiliki beberapa titik lokasi (misal: tugas pindahan dari lokasi A ke lokasi B).
**Jumlah Kolom**: 6

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik lokasi tugas. |
| `task_id` | UUID | No | — | FK → custom_tasks.id (CASCADE) | Tugas pemilik lokasi ini. Cascade delete. |
| `label` | VARCHAR(100) | Ya | — | — | Label lokasi (misal: "Lokasi Asal", "Lokasi Tujuan"). |
| `address` | TEXT | No | — | — | Alamat teks lokasi. Wajib diisi. |
| `location` | geometry | Ya | — | — | Koordinat geospasial lokasi. |
| `stop_order` | INT | No | `0` | — | Urutan stop (0-indexed). Default `0`. Digunakan untuk tugas dengan beberapa titik yang harus dikunjungi secara berurutan. |

**Relasi**:
- `task_locations.task_id` → `custom_tasks.id` (satu tugas punya banyak lokasi)

**Indeks**:
- Index pada `task_id` — untuk lookup cepat semua lokasi suatu tugas

**Unique Constraints**: Tidak ada

**Digunakan di Fitur**: Multi-lokasi tugas kustom, urutan rute, navigasi mitra ke lokasi tugas

---

### 25. task_providers

**Domain**: Mitra Tugas
**Deskripsi**: Menyimpan data mitra yang menerima tugas kustom. Menghubungkan `custom_tasks` dengan `provider_profiles`. Setiap kombinasi task + provider harus unik (satu mitra tidak bisa menerima tugas yang sama dua kali).
**Jumlah Kolom**: 10

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik penerimaan tugas. |
| `task_id` | UUID | No | — | FK → custom_tasks.id | Tugas yang diterima. |
| `provider_id` | UUID | No | — | FK → provider_profiles.id | Mitra yang menerima. |
| `status` | VARCHAR(20) | No | `"accepted"` | — | Status penerimaan: `accepted`, `completed`. Default `accepted`. |
| `work_status` | VARCHAR(20) | Ya | — | — | Status pekerjaan: `null`, `on_the_way`, `arrived`, `in_progress`, `completed`. Bisa null jika pekerjaan belum mulai. |
| `accepted_at` | TIMESTAMP(6) | No | `now()` | — | Waktu mitra menerima tugas. |
| `completed_at` | TIMESTAMP(6) | Ya | — | — | Waktu mitra menyelesaikan tugas. |
| `payout_confirmed` | BOOLEAN | No | `false` | — | Apakah payout ke mitra sudah dikonfirmasi. Default `false`. |
| `payout_at` | TIMESTAMP(6) | Ya | — | — | Waktu payout dilakukan. |

**Relasi**:
- `task_providers.task_id` → `custom_tasks.id` (satu tugas punya banyak mitra)
- `task_providers.provider_id` → `provider_profiles.id` (satu mitra menerima banyak tugas)
- `task_providers.id` → `orders.task_provider_id` (satu penerimaan tugas menghasilkan order)

**Indeks**:
- Index pada `provider_id` — untuk lookup cepat semua tugas yang diterima suatu mitra

**Unique Constraints**: Composite `task_id` + `provider_id` (satu mitra hanya bisa menerima satu tugas sekali)

**Digunakan di Fitur**: Penerimaan tugas kustom oleh mitra, tracking status pekerjaan tugas, payout tugas, manajemen tugas aktif

---

### 26. admin_bank_accounts

**Domain**: Rekening Bank Admin
**Deskripsi**: Menyimpan rekening bank yang dimiliki admin/platform Jasaku. Digunakan untuk menerima pembayaran dari customer atau melakukan payout ke mitra.
**Jumlah Kolom**: 6

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik rekening bank. |
| `provider_name` | VARCHAR(100) | No | — | — | Nama bank: `Bank BCA`, `Bank Mandiri`, `Bank BRI`, dll. |
| `account_number` | VARCHAR(100) | No | — | — | Nomor rekening. VARCHAR(100) untuk mengakomodasi berbagai format nomor. |
| `account_name` | VARCHAR(150) | No | — | — | Nama pemilik rekening. |
| `is_active` | BOOLEAN | Ya | `true` | — | Apakah rekening aktif digunakan. Default `true`. Bisa di-nonaktifkan jika rekening ditutup. |
| `created_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu rekening ditambahkan. |
| `updated_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu terakhir update. |

**Relasi**: Tidak ada relasi ke tabel lain (tabel admin mandiri)

**Indeks**: Tidak ada

**Unique Constraints**: Tidak ada

**Digunakan di Fitur**: Pengaturan rekening bank platform, informasi pembayaran ke customer, proses transfer

---

### 27. admin_ewallet_accounts

**Domain**: E-Wallet Admin
**Deskripsi**: Menyimpan akun e-wallet yang dimiliki admin/platform Jasaku (GoPay, OVO, Dana, dll).
**Jumlah Kolom**: 6

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik akun e-wallet. |
| `provider_name` | VARCHAR(100) | No | — | — | Nama e-wallet: `GoPay`, `OVO`, `Dana`, `LinkAja`, dll. |
| `account_number` | VARCHAR(100) | No | — | — | Nomor akun e-wallet (biasanya nomor HP). |
| `account_name` | VARCHAR(150) | No | — | — | Nama pemilik akun. |
| `is_active` | BOOLEAN | Ya | `true` | — | Apakah akun aktif. Default `true`. |
| `created_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu akun ditambahkan. |
| `updated_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu terakhir update. |

**Relasi**: Tidak ada relasi ke tabel lain

**Indeks**: Tidak ada

**Unique Constraints**: Tidak ada

**Digunakan di Fitur**: Pengaturan e-wallet platform, informasi pembayaran

---

### 28. admin_qris_accounts

**Domain**: QRIS Admin
**Deskripsi**: Menyimpan informasi QRIS (Quick Response Indonesian Standard) yang dimiliki admin/platform Jasaku. QRIS adalah metode pembayaran via scan QR code yang umum di Indonesia.
**Jumlah Kolom**: 6

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `uuid_generate_v4()` | PK | Identifier unik akun QRIS. |
| `provider_name` | VARCHAR(100) | No | — | — | Nama penyedia QRIS. |
| `qris_image_url` | TEXT | No | — | — | URL gambar QR code QRIS. TEXT karena URL gambar bisa panjang. Wajib diisi — customer perlu melihat QR untuk scan. |
| `is_active` | BOOLEAN | Ya | `true` | — | Apakah QRIS aktif. Default `true`. |
| `created_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu QRIS ditambahkan. |
| `updated_at` | TIMESTAMP(6) | Ya | `now()` | — | Waktu terakhir update. |

**Relasi**: Tidak ada relasi ke tabel lain

**Indeks**: Tidak ada

**Unique Constraints**: Tidak ada

**Digunakan di Fitur**: Pembayaran via QRIS, menampilkan QR code ke customer

---

### 29. user_devices

**Domain**: Perangkat Pengguna
**Deskripsi**: Menyimpan token FCM (Firebase Cloud Messaging) dari perangkat pengguna. Token ini digunakan untuk mengirim push notification. Satu user bisa punya beberapa perangkat (HP, tablet).
**Jumlah Kolom**: 7

| Kolom | Tipe Data | Nullable | Default | Constraint | Penjelasan |
|---|---|---|---|---|---|
| `id` | UUID | No | `gen_random_uuid()` | PK | Identifier unik perangkat. Menggunakan `gen_random_uuid()` (bukan `uuid_generate_v4()`) — fungsi PostgreSQL bawaan yang menghasilkan UUID v4. |
| `user_id` | UUID | No | — | FK → users.id (CASCADE) | User pemilik perangkat. Cascade delete: jika user dihapus, semua device token ikut terhapus. |
| `fcm_token` | TEXT | No | — | UNIQUE | Token FCM dari Firebase. Unique karena satu token hanya boleh dimiliki satu user — jika user lain login di device yang sama, token lama harus di-replace. |
| `device_type` | TEXT | No | — | — | Tipe perangkat: `android`, `ios`, `web`. Tidak pakai ENUM karena lebih fleksibel. |
| `device_name` | TEXT | Ya | — | — | Nama perangkat (misal: "Samsung Galaxy S24", "iPhone 15"). Bisa null. |
| `created_at` | TIMESTAMPTZ(6) | No | `now()` | — | Waktu perangkat didaftarkan. Menggunakan `timestamptz` (bukan `timestamp`) — menyimpan timezone untuk akurasi waktu. |
| `updated_at` | TIMESTAMPTZ(6) | No | `@updatedAt` | — | Waktu terakhir update. Menggunakan `timestamptz`. |

**Relasi**:
- `user_devices.user_id` → `users.id` (satu user punya banyak perangkat)

**Indeks**:
- Index pada `user_id` — untuk lookup cepat semua perangkat suatu user (untuk kirim notifikasi ke semua device)

**Unique Constraints**: `fcm_token` (satu token hanya untuk satu user)

**Digunakan di Fitur**: Push notification (FCM), registrasi device saat login, pengiriman notifikasi order, notifikasi status

---

## Diagram Relasi (Ringkasan)

```
roles ──1:N── users
users ──1:1── profiles_customer ──1:N── orders
users ──1:1── provider_profiles ──1:N── orders
users ──1:1── provider_locations
users ──1:N── custom_tasks ──1:N── task_locations
users ──1:N── custom_tasks ──1:N── task_providers
users ──1:N── reports
users ──1:N── reviews (sebagai customer)
users ──1:N── reviews (sebagai provider)
users ──1:N── user_devices

orders ──1:N── order_items
orders ──1:N── order_locations
orders ──1:N── order_attachments
orders ──1:N── payments
orders ──1:1── reviews
orders ──1:N── order_extensions
orders ──1:1── provider_schedules

categories ──1:N── services
categories ──1:N── pricing_types (opsional)
services ──N:1── categories
services ──N:M── provider_profiles (via provider_services)

provider_profiles ──1:N── provider_documents
provider_profiles ──1:N── provider_schedules
provider_profiles ──1:1── identity_verifications
provider_profiles ──1:N── provider_payout_methods

provider_services ──1:N── provider_service_prices
pricing_types ──1:N── provider_service_prices

custom_tasks ──1:N── task_providers
custom_tasks ──1:N── task_locations
```

---

## Catatan Teknis

### Row-Level Security (RLS)
Hampir semua tabel memiliki anotasi RLS di Prisma schema. RLS diaktifkan di level database PostgreSQL/Supabase — artinya akses data dikontrol oleh kebijakan database, bukan hanya oleh aplikasi. Ini memberikan lapisan keamanan tambahan.

### PostGIS Geometry
Kolom bertipe `geometry` menggunakan SRID 4326 (WGS 84 — sistem koordinat GPS standar). Beberapa tabel memiliki indeks GiST untuk performa query spasial:
- `provider_locations`: indeks `provider_locations_geo_idx`
- `custom_tasks` dan `order_locations`: belum ada indeks eksplisit (bisa ditambahkan jika diperlukan)

### UUID Generation
Dua fungsi UUID digunakan:
- `uuid_generate_v4()` — dari ekstensi `uuid-ossp` PostgreSQL. Digunakan di hampir semua tabel.
- `gen_random_uuid()` — fungsi bawaan PostgreSQL 13+. Digunakan di `user_devices`.

Keduanya menghasilkan UUID v4 yang sama — perbedaannya hanya sumber fungsi.

### DECIMAL vs FLOAT
- **DECIMAL(12,2)** digunakan untuk semua kolom harga/uang — memberikan presisi pasti tanpa error pembulatan floating-point.
- **FLOAT** hanya digunakan di `face_match_score` — skor 0.0–1.0 yang tidak memerlukan presisi keuangan.

### VARCHAR vs TEXT
- **VARCHAR(n)** digunakan kolom yang memiliki batas panjang alami (nama, email, status) — memberikan validasi di level database.
- **TEXT** digunakan kolom yang panjangnya tidak dapat diprediksi (deskripsi, alamat, URL) — lebih fleksibel.
