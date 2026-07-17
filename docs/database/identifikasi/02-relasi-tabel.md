# Relasi Antar Tabel — Jasaku Database

> Dokumen ini mencakup **seluruh relasi foreign key** dalam database Jasaku.
> Referensi: `prisma/schema.prisma` & `docs/database/jasaku_ddl.sql`

---

## Diagram Relasi (Ringkasan Visual)

```
roles ──1:N──▶ users ──1:1──▶ profiles_customer ──1:N──▶ orders
                    │                                    │
                    ├──1:1──▶ provider_profiles ──1:N──▶ orders
                    │             │
                    │             ├──1:N──▶ provider_documents
                    │             ├──1:N──▶ provider_payout_methods
                    │             ├──1:N──▶ provider_schedules ──N:1──▶ orders
                    │             ├──1:N──▶ provider_services ──N:1──▶ services
                    │             ├──1:N──▶ task_providers ──N:1──▶ custom_tasks
                    │             │                │
                    │             └──1:1──▶ identity_verifications
                    │
                    ├──1:1──▶ provider_locations (PostGIS)
                    ├──1:N──▶ user_devices (FCM tokens)
                    ├──1:N──▶ reports
                    └──1:N──▶ reviews (via customer_id, provider_id)

categories ──1:N──▶ services ──1:N──▶ order_items ──N:1──▶ orders
                    │              └──1:N──▶ provider_services
                    └──1:N──▶ pricing_types ──1:N──▶ provider_service_prices

orders ──1:N──▶ order_items
      ──1:N──▶ order_locations (PostGIS)
      ──1:N──▶ order_attachments
      ──1:N──▶ order_extensions
      ──1:N──▶ payments
      ──1:1──▶ reviews
      ──N:1──▶ custom_tasks
      ──N:1──▶ task_providers

custom_tasks ──1:N──▶ task_locations (PostGIS)
            ──1:N──▶ task_providers ──N:1──▶ provider_profiles
```

---

## Relasi Lengkap

### Domain: Autentikasi & Pengguna

---

### 1. roles → users

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `roles` (PK: `id` INT) |
| **Tabel Child** | `users` (FK: `role_id` INT) |
| **On Delete** | NoAction |
| **On Update** | NoAction |
| **Constraint Name** | `fk_user_role` |

**Alasan Desain:**

Setiap user hanya punya satu role (`customer`, `provider`/`mitra`, `admin`), tapi satu role bisa dimiliki banyak user. Role disimpan sebagai tabel terpisah (bukan enum) agar admin bisa menambah role baru tanpa migrasi.

**Fitur yang menggunakan:**

- **Autentikasi**: Saat login, role dibaca untuk menentukan redirect (customer app vs mitra app).
- **Role Middleware** (`role.middleware.ts`): Guard endpoint berdasarkan role.
- **Registration**: Saat register, user dikaitkan dengan role yang dipilih.

**Kekhususan:**

- `roles.id` menggunakan `SERIAL` (auto-increment integer), bukan UUID — satu-satunya tabel dengan PK integer.
- Nilai default yang di-seed: `customer`, `mitra`, `admin`.
- Index tidak diperlukan di `roles.id` karena PK sudah auto-index.

---

### 2. users → profiles_customer

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-One |
| **Tabel Parent** | `users` (PK: `id` UUID) |
| **Tabel Child** | `profiles_customer` (FK: `user_id` UUID, UNIQUE) |
| **On Delete** | CASCADE |
| **On Update** | NoAction |
| **Constraint Name** | `fk_profile_user` |

**Alasan Desain:**

Data profil customer dipisah dari `users` karena `users` hanya menyimpan data autentikasi (email, password, role), sedangkan `profiles_customer` menyimpan data pribadi (nama lengkap, alamat, avatar, tanggal lahir). Prinsip *Single Responsibility* — data autentikasi tidak bercampur dengan data profil.

**Fitur yang menggunakan:**

- **Registrasi Customer**: Saat customer baru mendaftar, baris baru dibuat di `profiles_customer` dengan `user_id` yang sama.
- **Profil Customer**: Halaman profil menampilkan data dari `profiles_customer`.
- **Order Creation**: `orders.customer_id` merujuk ke `profiles_customer.id` (bukan `users.id`).

**Kekhususan:**

- `ON DELETE CASCADE`: Jika user dihapus, profil customer otomatis terhapus (data tidak orphän).
- `user_id` memiliki UNIQUE constraint — memastikan satu user hanya punya satu profil.
- Index `idx_profiles_user_id` di kolom `user_id` untuk query cepat.

---

### 3. users → provider_profiles

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-One |
| **Tabel Parent** | `users` (PK: `id` UUID) |
| **Tabel Child** | `provider_profiles` (FK: `user_id` UUID, UNIQUE) |
| **On Delete** | CASCADE |
| **On Update** | NoAction |
| **Constraint Name** | `fk_provider_user` |

**Alasan Desain:**

Data provider jauh lebih kompleks dari customer: KTP, selfie, portofolio, rating, status verifikasi, onboarding. Memisahkan dari `users` menghindari puluhan kolom null di tabel `users` yang tidak relevan untuk customer/admin.

**Fitur yang menggunakan:**

- **Registrasi Mitra**: Saat provider mendaftar, baris `provider_profiles` dibuat.
- **Dashboard Mitra**: Semua data ditampilkan dari `provider_profiles`.
- **Verifikasi**: Status verifikasi (`is_verified`, `verification_status`) ada di tabel ini.
- **Pencarian Provider**: Query mencari provider berdasarkan service, lokasi, dan rating — semuanya dari `provider_profiles`.

**Kekhususan:**

- `ON DELETE CASCADE`: Hapus user → hapus profil provider dan semua data terkait (dokumen, jadwal, layanan, dll).
- `user_id` UNIQUE: Satu user hanya bisa jadi satu provider.
- Rating dihitung secara denormalized (`rating`, `total_jobs`, `total_reviews`) untuk menghindari COUNT/AVG di setiap query.

---

### 4. users → provider_locations

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-One |
| **Tabel Parent** | `users` (PK: `id` UUID) |
| **Tabel Child** | `provider_locations` (FK: `provider_id` UUID, UNIQUE) |
| **On Delete** | NoAction |
| **On Update** | NoAction |
| **Constraint Name** | `fk_provider_loc` |

**Alasan Desain:**

Lokasi provider berubah setiap ~30 detik (GPS tracking real-time). Jika digabung dengan `provider_profiles`, setiap update lokasi akan menulis ulang seluruh baris profil (nama, foto, KTP, dll) — ini tidak efisien dan menimbulkan write contention. Dengan tabel terpisah, update lokasi hanya menulis 2 kolom.

**Fitur yang menggunakan:**

- **Location Tracker** (`location_tracker_provider.dart`): Mengirim lokasi ke `PUT /api/locations/update` tiap 30 detik.
- **Pencarian Provider Terdekat**: Query PostGIS `ST_DWithin()` hanya berjalan pada tabel ini.
- **Dashboard Provider**: Menampilkan lokasi saat ini di peta.

**Kekhususan:**

- Menggunakan PostGIS `geometry(Point, 4326)` untuk koordinat.
- Index GIST spesial: `provider_locations_geo_idx` pada kolom `location` — wajib untuk query geospasial cepat.
- `provider_id` UNIQUE: Satu provider hanya punya satu record lokasi (upsert, bukan insert baru).
- `ON DELETE NoAction`: Lokasi tidak cascade karena provider_locations FK ke `users.id`, bukan ke `provider_profiles.id`. Jika user dihapus, data lokasi harus di-handle secara aplikasi.

---

### 5. users → user_devices

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `users` (PK: `id` UUID) |
| **Tabel Child** | `user_devices` (FK: `user_id` UUID) |
| **On Delete** | CASCADE |
| **On Update** | — |
| **Constraint Name** | `fk_device_user` |

**Alasan Desain:**

Satu user bisa login di banyak device (HP utama, tablet, HP cadangan). Setiap device punya FCM token yang unik. Push notification harus dikirim ke semua device yang aktif — makanya perlu tabel terpisah dengan `fcm_token` UNIQUE.

**Fitur yang menggunakan:**

- **Push Notification** (`notifications/`): Backend mengambil semua `fcm_token` dari tabel ini untuk mengirim notifikasi ke semua device user.
- **Login/Register**: Saat user login di device baru, FCM token didaftarkan/upsert.
- **Logout**: FCM token dihapus dari tabel.

**Kekhususan:**

- `ON DELETE CASCADE`: Hapus user → hapus semua device registration (token tidak valid lagi).
- `fcm_token` UNIQUE: Memastikan satu token FCM hanya terdaftar untuk satu user/device.
- Menggunakan `gen_random_uuid()` (bukan `uuid_generate_v4()`) — berbeda dari tabel lain.
- Menggunakan `TIMESTAMPTZ` (timezone-aware) — berbeda dari tabel lain yang pakai `TIMESTAMP`.

---

### 6. users → reports

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `users` (PK: `id` UUID) |
| **Tabel Child** | `reports` (FK: `reporter_id` UUID) |
| **On Delete** | NoAction (Prisma default) |
| **On Update** | — |
| **Constraint Name** | `fk_report_reporter` |

**Alasan Desain:**

Siapa saja (customer atau provider) bisa membuat laporan. `reporter_id` merujuk ke `users.id`, bukan ke `profiles_customer` atau `provider_profiles`, karena pelapor bisa dari role mana pun. Kolom `reporter_role` disimpan sebagai denormalisasi untuk query cepat tanpa JOIN ke `users` + `roles`.

**Fitur yang menggunakan:**

- **Buat Laporan**: Customer/provider melaporkan masalah terkait order.
- **Dashboard Admin**: Admin melihat semua laporan, filter by status.

**Kekhususan:**

- Tidak ada CASCADE karena laporan harus tetap ada meski user dihapus (audit trail).
- Index `idx_reporter_id` dan `idx_reports_status` untuk query admin.
- `order_id` bersifat opsional — laporan bisa terkait order atau umum.

---

### 7. users → reviews (via customer_id)

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `users` (PK: `id` UUID) |
| **Tabel Child** | `reviews` (FK: `customer_id` UUID) |
| **On Delete** | CASCADE |
| **On Update** | NoAction |
| **Constraint Name** | `fk_review_customer` |
| **Relasi Prisma** | `reviews_customer_idTousers` |

**Alasan Desain:**

Customer yang memberikan ulasan. FK merujuk ke `users.id` (bukan `profiles_customer.id`) karena Prisma perlu relasi langsung ke tabel yang memiliki field yang di-query. Satu customer bisa memberikan banyak ulasan (satu per order yang sudah selesai).

**Fitur yang menggunakan:**

- **Riwayat Ulasan Customer**: Customer melihat semua ulasan yang pernah diberikan.
- **Dashboard Admin**: Admin melihat ulasan per customer.

---

### 8. users → reviews (via provider_id)

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `users` (PK: `id` UUID) |
| **Tabel Child** | `reviews` (FK: `provider_id` UUID) |
| **On Delete** | CASCADE |
| **On Update** | NoAction |
| **Constraint Name** | `fk_review_provider` |
| **Relasi Prisma** | `reviews_reviews_provider_idTousers` |

**Alasan Desain:**

Provider yang menerima ulasan. Relasi ini memungkinkan query: "Semua ulasan untuk provider X" tanpa JOIN ke `provider_profiles` → `users`.

**Fitur yang menggunakan:**

- **Profil Provider Publik**: Rata-rata rating dan daftar ulasan ditampilkan.
- **Dashboard Provider**: Provider melihat ulasan dari customer.

---

### 9. users → custom_tasks

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `users` (PK: `id` UUID) |
| **Tabel Child** | `custom_tasks` (FK: `customer_id` UUID) |
| **On Delete** | NoAction |
| **On Update** | NoAction |
| **Constraint Name** | (implicit) |

**Alasan Desain:**

Customer membuat custom task (tender/lelang pekerjaan). Satu customer bisa membuat banyak custom task. FK ke `users.id` langsung karena hanya user dengan role `customer` yang bisa membuat task.

**Fitur yang menggunakan:**

- **Custom Task (Tender)**: Customer membuat pengumuman pekerjaan dengan budget, jumlah orang, dan lokasi.
- **Riwayat Task**: Customer melihat daftar task yang pernah dibuat.

**Kekhususan:**

- `ON DELETE NoAction`: Jika user dihapus, custom task tetap ada (riwayat penting untuk provider yang sudah menerima).

---

### Domain: Provider

---

### 10. provider_profiles → provider_documents

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `provider_profiles` (PK: `id` UUID) |
| **Tabel Child** | `provider_documents` (FK: `provider_id` UUID) |
| **On Delete** | CASCADE |
| **On Update** | — |
| **Constraint Name** | `fk_pdoc_provider` |

**Alasan Desain:**

Provider bisa mengunggah banyak dokumen pendukung (sertifikat, portfolio, izin usaha). Setiap dokumen punya metadata sendiri (type, description, created_at). Menggunakan array of rows daripada PostgreSQL array karena setiap item membutuhkan metadata terstruktur.

**Fitur yang menggunakan:**

- **Upload Dokumen**: Provider mengunggah dokumen pendukung saat proses verifikasi atau kapan saja.
- **Verifikasi Admin**: Admin memeriksa dokumen-dokumen yang diunggah.

**Kekhususan:**

- `ON DELETE CASCADE`: Hapus provider → hapus semua dokumen (tidak ada data orphan).
- Index `idx_provider_documents_pid` untuk query cepat berdasarkan provider.

---

### 11. provider_profiles → provider_payout_methods

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `provider_profiles` (PK: `id` UUID) |
| **Tabel Child** | `provider_payout_methods` (FK: `provider_id` UUID) |
| **On Delete** | NoAction (Prisma default) |
| **On Update** | — |
| **Constraint Name** | `fk_ppayout_provider` |

**Alasan Desain:**

Provider bisa punya beberapa metode pembayaran (transfer bank, e-wallet). Satu provider → banyak payout method. Memungkinkan admin melakukan payout ke rekening yang dipilih provider.

**Fitur yang menggunakan:**

- **Atur Rekening**: Provider menambahkan/mengubah rekening bank atau e-wallet.
- **Payout Admin**: Admin memilih metode payout untuk provider.

**Kekhususan:**

- Tidak ada CASCADE karena data payout method sensitif — admin perlu audit trail meski provider nonaktif.
- Index `idx_provider_payout_methods_pid` untuk query berdasarkan provider.

---

### 12. provider_profiles → provider_schedules

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `provider_profiles` (PK: `id` UUID) |
| **Tabel Child** | `provider_schedules` (FK: `provider_id` UUID) |
| **On Delete** | NoAction (Prisma default) |
| **On Update** | — |
| **Constraint Name** | (implicit) |

**Alasan Desain:**

Jadwal kerja provider per hari. Satu provider bisa punya banyak jadwal (satu per hari). `provider_id + work_date` di-UNIQUE agar satu provider hanya punya satu jadwal per hari.

**Fitur yang menggunakan:**

- **Ketersediaan Provider**: Customer melihat tanggal yang tersedia saat memesan.
- **Booking**: Saat order dibuat, jadwal provider ditandai `is_booked = true`.
- **Dashboard Provider**: Provider melihat jadwal kerjanya.

**Kekhususan:**

- `@@unique([provider_id, work_date])`: Constraint unik komposit — satu provider, satu record per tanggal.
- `@@index([provider_id, work_date])`: Index komposit untuk query cepat (cek ketersediaan).
- `order_id` opsional: Ada saat jadwal sudah dibooking, NULL saat belum.

---

### 13. provider_profiles → provider_services

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `provider_profiles` (PK: `id` UUID) |
| **Tabel Child** | `provider_services` (FK: `provider_id` UUID) |
| **On Delete** | NoAction (Prisma default) |
| **On Update** | — |
| **Constraint Name** | (implicit) |

**Alasan Desain:**

Junction table antara provider dan layanan. Satu provider bisa menawarkan banyak layanan. `provider_services` menjawab pertanyaan: "Layanan apa saja yang ditawarkan provider X?"

**Fitur yang menggunakan:**

- **Daftar Layanan Provider**: Provider memilih layanan mana yang ditawarkan.
- **Pencarian Provider**: Customer mencari provider berdasarkan layanan tertentu.
- **Harga Provider**: Harga spesifik provider ada di child table `provider_service_prices`.

**Kekhususan:**

- Index `idx_provider_services_pid` untuk query berdasarkan provider.

---

### 14. provider_profiles → task_providers

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `provider_profiles` (PK: `id` UUID) |
| **Tabel Child** | `task_providers` (FK: `provider_id` UUID) |
| **On Delete** | NoAction (Prisma default) |
| **On Update** | — |
| **Constraint Name** | `fk_tprov_provider` |

**Alasan Desain:**

Junction table antara provider dan custom task. Satu provider bisa menerima banyak custom task. Menjawab: "Custom task apa saja yang sudah diterima provider X?"

**Fitur yang menggunakan:**

- **Custom Task Marketplace**: Provider menerima/menolak custom task.
- **Dashboard Mitra**: Provider melihat daftar task yang sudah diterima.
- **Payout Task**: Status payout per task provider.

**Kekhususan:**

- `@@unique([task_id, provider_id])`: Satu provider hanya bisa menerima satu task sekali.
- Index `idx_task_providers_pid` untuk query berdasarkan provider.

---

### 15. provider_profiles → orders

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `provider_profiles` (PK: `id` UUID) |
| **Tabel Child** | `orders` (FK: `provider_id` UUID) |
| **On Delete** | NoAction |
| **On Update** | NoAction |
| **Constraint Name** | `fk_order_provider` |

**Alasan Desain:**

Satu provider bisa menangani banyak order. `provider_id` di `orders` merujuk ke `provider_profiles.id` (bukan `users.id`) karena lebih logis secara domain — order ditangani oleh profil provider, bukan user.

**Fitur yang menggunakan:**

- **Dashboard Mitra**: Provider melihat daftar order yang diterima.
- **Riwayat Pekerjaan**: Provider melihat riwayat pekerjaan selesai.
- **Payout**: Perhitungan payout berdasarkan order yang selesai.

---

### 16. provider_profiles → identity_verifications

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-One |
| **Tabel Parent** | `provider_profiles` (PK: `id` UUID) |
| **Tabel Child** | `identity_verifications` (FK: `provider_id` UUID, UNIQUE) |
| **On Delete** | CASCADE |
| **On Update** | — |
| **Constraint Name** | `fk_idverif_provider` |

**Alasan Desain:**

Data verifikasi identitas (NIK, hasil OCR KTP, face match, liveness check) dipisah karena: (a) data sangat sensitif — perlu proteksi akses ketat, (b) mengandung JSONB besar untuk raw OCR result, (c) audit trail perlu dijaga terpisah dari profil.

**Fitur yang menggunakan:**

- **Onboarding Mitra**: Provider mengunggah KTP dan selfie → OCR dijalankan → data disimpan di sini.
- **Verifikasi Admin**: Admin memeriksa hasil OCR dan face match.
- **Status Verifikasi**: `face_match_status`, `liveness_status` dikirim ke provider_profiles sebagai ringkasan.

**Kekhususan:**

- `ON DELETE CASCADE`: Hapus provider → hapus data verifikasi (data sensitif tidak boleh orphan).
- `provider_id` UNIQUE: Satu provider hanya punya satu record verifikasi.
- Menggunakan `JSONB` untuk `ocr_raw_result` dan `liveness_data` — fleksibel untuk berbagai format OCR.
- Index `idx_identity_verifications_pid` untuk query berdasarkan provider.

---

### Domain: Pesanan (Orders)

---

### 17. profiles_customer → orders

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `profiles_customer` (PK: `id` UUID) |
| **Tabel Child** | `orders` (FK: `customer_id` UUID) |
| **On Delete** | NoAction |
| **On Update** | NoAction |
| **Constraint Name** | `fk_order_customer` |

**Alasan Desain:**

Satu customer bisa membuat banyak order. FK merujuk ke `profiles_customer.id` (bukan `users.id`) karena order membutuhkan data profil (nama, alamat) yang sudah ada di `profiles_customer`.

**Fitur yang menggunakan:**

- **Riwayat Order Customer**: Customer melihat semua order yang pernah dibuat.
- **Dashboard Admin**: Admin melihat order per customer.
- **Pembatalan Order**: Saat customer membatalkan, order terkait diperbarui.

**Kekhususan:**

- Index `idx_orders_customer_id` untuk query riwayat order customer.

---

### Domain: Katalog Layanan

---

### 18. categories → services

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `categories` (PK: `id` UUID) |
| **Tabel Child** | `services` (FK: `category_id` UUID) |
| **On Delete** | NoAction |
| **On Update** | NoAction |
| **Constraint Name** | `fk_service_category` |

**Alasan Desain:**

Normalisasi. Kategori (Rumah Tangga, Renovasi, Kebersihan) memelihara banyak layanan (Bersih-bersih, Plumbing, Cat Tembok). Memisahkan menghindari duplikasi nama kategori di setiap layanan.

**Fitur yang menggunakan:**

- **Katalog Layanan**: Customer memilih kategori → melihat daftar layanan.
- **Manajemen Layanan**: Admin menambah/mengedit layanan dalam kategori.

**Kekhususan:**

- Index `idx_services_category_id` untuk query layanan per kategori.
- `ON DELETE NoAction`: Kategori tidak bisa dihapus jika masih ada layanan terkait.

---

### 19. categories → pricing_types

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `categories` (PK: `id` UUID) |
| **Tabel Child** | `pricing_types` (FK: `category_id` UUID, opsional) |
| **On Delete** | NoAction |
| **On Update** | NoAction |
| **Constraint Name** | `fk_ptype_category` |

**Alasan Desain:**

Pricing types (Per Hari, Per Meter, Flat) bisa bersifat global atau spesifik kategori. `category_id` opsional — jika NULL, pricing type berlaku untuk semua kategori. Jika terisi, pricing type spesifik untuk kategori tertentu.

**Fitur yang menggunakan:**

- **Harga Layanan**: Saat provider mengatur harga, pricing type yang tersedia ditampilkan berdasarkan kategori layanan.
- **Order Form**: Customer memilih pricing type saat memesan.

**Kekhususan:**

- `category_id` NULLABLE — memungkinkan pricing type global.
- Index `idx_pricing_types_category_id` untuk query berdasarkan kategori.

---

### 20. services → order_items

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `services` (PK: `id` UUID) |
| **Tabel Child** | `order_items` (FK: `service_id` UUID) |
| **On Delete** | NoAction |
| **On Update** | NoAction |
| **Constraint Name** | `fk_oitem_service` |

**Alasan Desain:**

Setiap order item mereferensikan layanan apa yang dipesan. Satu layanan bisa muncul di banyak order items (dari berbagai order). Harga saat order di-snap ke `order_items.price` agar tidak berubah jika harga master berubah.

**Fitur yang menggunakan:**

- **Detail Order**: Menampilkan layanan apa saja yang dipesan dalam satu order.
- **Riwayat Harga**: Hargahistoris terjaga di `order_items.price`.

**Kekhususan:**

- Harga di `order_items` adalah snapshot — tidak berubah meski harga provider berubah.

---

### 21. services → provider_services

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `services` (PK: `id` UUID) |
| **Tabel Child** | `provider_services` (FK: `service_id` UUID) |
| **On Delete** | NoAction |
| **On Update** | NoAction |
| **Constraint Name** | `fk_pserv_service` |

**Alasan Desain:**

Junction table: "Provider X menawarkan layanan Y". Satu layanan bisa ditawarkan oleh banyak provider.

**Fitur yang menggunakan:**

- **Pencarian Provider**: Customer memilih layanan → sistem mencari semua provider yang menawarkan layanan tersebut.
- **Profil Provider**: Menampilkan daftar layanan yang ditawarkan.

---

### 22. pricing_types → provider_service_prices

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `pricing_types` (PK: `id` UUID) |
| **Tabel Child** | `provider_service_prices` (FK: `pricing_type_id` UUID) |
| **On Delete** | NoAction |
| **On Update** | NoAction |
| **Constraint Name** | `fk_psp_ptype` |

**Alasan Desain:**

Setiap harga provider merujuk ke jenis pricing tertentu. "Per Hari" → Rp 200.000, "Per Meter" → Rp 5.000/m². Pricing type bisa dipakai oleh banyak provider_service_prices.

**Fitur yang menggunakan:**

- **Pengaturan Harga**: Provider memilih pricing type → mengisi harga.
- **Tampilan Harga**: Customer melihat opsi harga per pricing type.

---

### 23. provider_services → provider_service_prices

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `provider_services` (PK: `id` UUID) |
| **Tabel Child** | `provider_service_prices` (FK: `provider_service_id` UUID) |
| **On Delete** | NoAction |
| **On Update** | NoAction |
| **Constraint Name** | `fk_ps_price` |

**Alasan Desain:**

Satu provider service bisa punya banyak opsi harga (satu per pricing type). Contoh: "Bersih-bersih oleh Provider A" bisa punya harga per hari (Rp 200rb) DAN per meter (Rp 5rb/m²). Dua tabel junction (`provider_services` + `provider_service_prices`) diperlukan untuk mendukung multi-pricing.

**Fitur yang menggunakan:**

- **Pengaturan Harga**: Provider menambahkan beberapa opsi harga per layanan.
- **Order Form**: Customer memilih salah satu opsi harga.

**Kekhususan:**

- Index `idx_provider_service_prices_psid` untuk query harga berdasarkan provider service.

---

### Domain: Pesanan (Orders) — Lanjutan

---

### 24. orders → order_items

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `orders` (PK: `id` UUID) |
| **Tabel Child** | `order_items` (FK: `order_id` UUID) |
| **On Delete** | NoAction |
| **On Update** | NoAction |
| **Constraint Name** | `fk_oitem_order` |

**Alasan Desain:**

Satu order bisa memuat banyak item (beberapa layanan sekaligus). `order_items` menyimpan detail: layanan apa, pricing type apa, berapa quantity, harga satuan, dan subtotal.

**Fitur yang menggunakan:**

- **Detail Order**: Menampilkan semua item dalam order.
- **Kalkulasi Total**: `SUM(subtotal)` dari order_items.
- **Rincian untuk Provider**: Provider melihat detail pekerjaan.

**Kekhususan:**

- Index `idx_order_items_oid` untuk query item per order.

---

### 25. orders → order_locations

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many (dalam praktik: satu order biasanya 1 lokasi, tapi tabel mendukung banyak) |
| **Tabel Parent** | `orders` (PK: `id` UUID) |
| **Tabel Child** | `order_locations` (FK: `order_id` UUID) |
| **On Delete** | NoAction |
| **On Update** | NoAction |
| **Constraint Name** | `fk_oloc_order` |

**Alasan Desain:**

Lokasi order disimpan terpisah karena menggunakan PostGIS `geometry(Point, 4326)`. Desain one-to-many memungkinkan multi-lokasi (misal: pindahan yang punya origin DAN destination).

**Fitur yang menggunakan:**

- **Peta Order**: Menampilkan lokasi order di peta.
- **Navigasi Provider**: Provider melihat lokasi customer untuk navigasi.
- **Pencarian Terdekat**: Sistem mencari provider terdekat dari lokasi order.

**Kekhususan:**

- Menggunakan PostGIS `geometry(Point, 4326)`.
- Index `idx_order_locations_oid` untuk query berdasarkan order.
- Prisma mendefinisikan sebagai `order_locations[]` (one-to-many), bukan `order_locations?` (one-to-one).

---

### 26. orders → order_attachments

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `orders` (PK: `id` UUID) |
| **Tabel Child** | `order_attachments` (FK: `order_id` UUID) |
| **On Delete** | NoAction |
| **On Update** | NoAction |
| **Constraint Name** | `fk_oattach_order` |

**Alasan Desain:**

Customer/provider bisa melampirkan file (foto kondisi rumah, foto hasil kerja). Satu order bisa punya banyak lampiran.

**Fitur yang menggunakan:**

- **Upload Lampiran**: Customer/provider mengunggah foto saat membuat/mengerjakan order.
- **Detail Order**: Menampilkan lampiran terkait order.

**Kekhususan:**

- `file_url` adalah string (URL ke storage — Supabase Storage atau sejenisnya).
- Index `idx_order_attachments_oid` untuk query berdasarkan order.

---

### 27. orders → order_extensions

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `orders` (PK: `id` UUID) |
| **Tabel Child** | `order_extensions` (FK: `order_id` UUID) |
| **On Delete** | NoAction (Prisma default) |
| **On Update** | — |
| **Constraint Name** | `fk_oext_order` |

**Alasan Desain:**

Ekstensi order — provider atau customer bisa memperpanjang durasi pekerjaan. Satu order bisa diekstensi berkali-kali. Setiap ekstensi punya biaya tambahan dan status tersendiri (pending/accepted/rejected).

**Fitur yang menggunakan:**

- **Ekstensi Order**: Provider/customer meminta perpanjangan waktu.
- **Riwayat Ekstensi**: Menampilkan semua perubahan durasi order.

**Kekhususan:**

- Index `idx_order_extensions_oid` untuk query berdasarkan order.
- `additional_cost` dan `platform_fee_rate` disimpan per ekstensi — perubahan biaya tercatat historical.

---

### 28. orders → payments

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `orders` (PK: `id` UUID) |
| **Tabel Child** | `payments` (FK: `order_id` UUID) |
| **On Delete** | NoAction |
| **On Update** | NoAction |
| **Constraint Name** | `fk_payment_order` |

**Alasan Desain:**

Satu order bisa punya banyak pembayaran (bayar DP dulu, sisanya nanti; atau pembayaran ulang jika gagal). Status pembayaran terpisah dari status order.

**Fitur yang menggunakan:**

- **Pembayaran Order**: Customer melakukan pembayaran (transfer bank, e-wallet, QRIS).
- **Verifikasi Pembayaran**: Admin/provider memverifikasi bukti bayar.
- **Status Pembayaran**: `pending`, `paid`, `failed`, `refunded`.

**Kekhususan:**

- `payment_proof` menyimpan URL bukti transfer.
- Index `idx_payments_oid` untuk query berdasarkan order.

---

### 29. orders → reviews

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-One |
| **Tabel Parent** | `orders` (PK: `id` UUID) |
| **Tabel Child** | `reviews` (FK: `order_id` UUID, UNIQUE) |
| **On Delete** | CASCADE |
| **On Update** | NoAction |
| **Constraint Name** | `fk_review_order` |

**Alasan Desain:**

Satu order hanya bisa diulas sekali. `order_id` UNIQUE di tabel `reviews` memastikan tidak ada ulasan ganda per order.

**Fitur yanggunakan:**

- **Buat Ulasan**: Customer memberikan rating dan ulasan setelah order selesai.
- **Tampilan Ulasan**: Ulasan ditampilkan di profil provider.

**Kekhususan:**

- `ON DELETE CASCADE`: Hapus order → hapus ulasan terkait.
- `order_id` UNIQUE di `reviews`: Memastikan 1 order = 1 ulasan.

---

### 30. orders → provider_schedules

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `orders` (PK: `id` UUID) |
| **Tabel Child** | `provider_schedules` (FK: `order_id` UUID, opsional) |
| **On Delete** | NoAction (Prisma default) |
| **On Update** | — |
| **Constraint Name** | (implicit) |

**Alasan Desain:**

Ketika order dibuat untuk tanggal tertentu, jadwal provider pada tanggal tersebut ditandai `is_booked = true` dan `order_id` diisi. Relasi ini memungkinkan: "Jadwal provider X pada tanggal Y sudah dibooking untuk order mana?"

**Fitur yang menggunakan:**

- **Booking Jadwal**: Saat order dibuat, jadwal provider ditautkan.
- **Cek Ketersediaan**: Sistem memeriksa apakah jadwal sudah dibooking sebelum order diterima.

---

### 31. orders → custom_tasks (many-to-one, optional)

| Aspek | Detail |
|---|---|
| **Tipe** | Many-to-One (optional) |
| **Tabel Parent** | `custom_tasks` (PK: `id` UUID) |
| **Tabel Child** | `orders` (FK: `custom_task_id` UUID, opsional) |
| **On Delete** | NoAction |
| **On Update** | NoAction |
| **Constraint Name** | `fk_order_custom_task` |

**Alasan Desain:**

Order bisa berasal dari custom task (tender) atau langsung (manual). Jika dari custom task, `custom_task_id` diisi. Jika order manual, `custom_task_id` NULL. Relasi ini opsional.

**Fitur yang menggunakan:**

- **Custom Task → Order**: Saat provider menerima custom task, order otomatis dibuat dengan `custom_task_id` terisi.
- **Order Manual**: Order dibuat langsung tanpa custom task — `custom_task_id` NULL.

**Kekhususan:**

- `custom_task_id` NULLABLE — order tidak selalu dari custom task.
- `ON DELETE NoAction`: Custom task tidak bisa dihapus jika ada order terkait.

---

### 32. orders → task_providers (many-to-one, optional)

| Aspek | Detail |
|---|---|
| **Tipe** | Many-to-One (optional) |
| **Tabel Parent** | `task_providers` (PK: `id` UUID) |
| **Tabel Child** | `orders` (FK: `task_provider_id` UUID, opsional) |
| **On Delete** | NoAction |
| **On Update** | NoAction |
| **Constraint Name** | `fk_order_task_provider` |

**Alasan Desain:**

Jika order berasal dari custom task, `task_provider_id` menunjuk ke record task_providers (hubungan spesifik antara task dan provider yang menerima). Ini memberikan jejak lengkap: custom_task → task_providers → order.

**Fitur yang menggunakan:**

- **Custom Task Flow**: Melacak provider mana yang menerima task → order mana yang dihasilkan.
- **Payout Task**: Menghubungkan payout task_providers dengan order terkait.

**Kekhususan:**

- `task_provider_id` NULLABLE — order manual tidak punya task_provider.
- Bersama relasi #31, membentuk rantai: `custom_tasks → task_providers → orders`.

---

### Domain: Custom Tasks (Tender)

---

### 33. custom_tasks → task_locations

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `custom_tasks` (PK: `id` UUID) |
| **Tabel Child** | `task_locations` (FK: `task_id` UUID) |
| **On Delete** | CASCADE |
| **On Update** | — |
| **Constraint Name** | `fk_tloc_task` |

**Alasan Desain:**

Custom task bisa punya banyak lokasi (contoh: pindahan dari rumah A ke rumah B ke rumah C). `stop_order` menentukan urutan kunjungan. Multi-lokasi penting untuk task yang melibatkan perpindahan.

**Fitur yang menggunakan:**

- **Buat Custom Task**: Customer menambahkan beberapa lokasi tujuan.
- **Navigasi Provider**: Provider melihat rute kunjungan sesuai `stop_order`.

**Kekhususan:**

- `ON DELETE CASCADE`: Hapus custom task → hapus semua lokasi terkait.
- `label` opsional: Nama lokasi (misal: "Rumah Lama", "Rumah Baru").
- `stop_order`: Menentukan urutan kunjungan (0, 1, 2, ...).
- Menggunakan PostGIS `geometry(Point, 4326)`.
- Index `idx_task_locations_tid` untuk query berdasarkan task.

---

### 34. custom_tasks → task_providers

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `custom_tasks` (PK: `id` UUID) |
| **Tabel Child** | `task_providers` (FK: `task_id` UUID) |
| **On Delete** | NoAction (Prisma default) |
| **On Update** | — |
| **Constraint Name** | `fk_tprov_task` |

**Alasan Desain:**

Junction table: "Custom task X diterima oleh provider Y". Satu task bisa diterima banyak provider (hingga `required_people`). `accepted_count` di `custom_tasks` di-update setiap provider menerima.

**Fitur yang menggunakan:**

- **Custom Task Marketplace**: Provider menerima custom task → record baru di `task_providers`.
- **Status Task**: Task berubah dari `open` → `in_progress` → `active` → `completed` berdasarkan jumlah provider yang menerima.
- **Tracking Pekerjaan**: Setiap task_provider punya status kerja sendiri (`work_status`).

**Kekhususan:**

- `@@unique([task_id, provider_id])`: Satu provider hanya bisa menerima satu task sekali.
- `accepted_at`: Waktu provider menerima task.
- `completed_at`: Waktu provider menyelesaikan task.
- `payout_confirmed` & `payout_at`: Status pembayaran per provider.

---

### 35. custom_tasks → orders

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `custom_tasks` (PK: `id` UUID) |
| **Tabel Child** | `orders` (FK: `custom_task_id` UUID, opsional) |
| **On Delete** | NoAction |
| **On Update** | NoAction |
| **Constraint Name** | `fk_order_custom_task` |

**Alasan Desain:**

Satu custom task bisa menghasilkan banyak order (satu per provider yang diterima). Ini adalah sisi "parent" dari relasi #31.

**Fitur yang menggunakan:**

- **Custom Task → Order**: Ketika provider menerima task, order otomatis dibuat.
- **Riwayat Task**: Customer melihat semua order yang dihasilkan dari task-nya.

---

### 36. task_providers → orders

| Aspek | Detail |
|---|---|
| **Tipe** | One-to-Many |
| **Tabel Parent** | `task_providers` (PK: `id` UUID) |
| **Tabel Child** | `orders` (FK: `task_provider_id` UUID, opsional) |
| **On Delete** | NoAction (Prisma default) |
| **On Update** | — |
| **Constraint Name** | `fk_order_task_provider` |

**Alasan Desain:**

Satu task_provider → bisa ada banyak order (jika task melibatkan multi-lokasi atau ekstensi). Ini adalah sisi "parent" dari relasi #32.

**Fitur yang menggunakan:**

- **Custom Task Flow**: Setiap task_provider memiliki order terkait untuk tracking pekerjaan.
- **Payout Task**: Menghubungkan pembayaran dengan pekerjaan yang dilakukan.

---

## Ringkasan: Cascade Behavior

| Parent | Child | On Delete | Alasan |
|---|---|---|---|
| `roles` | `users` | NoAction | Role tidak boleh dihapus jika masih ada user |
| `users` | `profiles_customer` | CASCADE | Hapus user → hapus profil (data tidak relevan) |
| `users` | `provider_profiles` | CASCADE | Hapus user → hapus profil provider dan semua data terkait |
| `users` | `user_devices` | CASCADE | Hapus user → hapus semua device registration |
| `users` | `reports` | NoAction | Laporan harus tetap ada (audit trail) |
| `users` | `reviews` (customer) | CASCADE | Hapus user → hapus ulasan yang diberikan |
| `users` | `reviews` (provider) | CASCADE | Hapus user → hapus ulasan yang diterima |
| `users` | `custom_tasks` | NoAction | Task harus tetap ada (riwayat) |
| `provider_profiles` | `provider_documents` | CASCADE | Hapus provider → hapus dokumen |
| `provider_profiles` | `identity_verifications` | CASCADE | Hapus provider → hapus data verifikasi sensitif |
| `provider_profiles` | `provider_payout_methods` | NoAction | Data payout perlu audit trail |
| `orders` | `reviews` | CASCADE | Hapus order → hapus ulasan |
| `custom_tasks` | `task_locations` | CASCADE | Hapus task → hapus lokasi terkait |
| `custom_tasks` | `task_providers` | NoAction | Riwayat penerimaan task penting |
| Lainnya | Lainnya | NoAction | Default — data tidak boleh dihapus secara kaskade |

---

## Ringkasan: Index pada Foreign Keys

| Tabel | Kolom | Index | Kegunaan |
|---|---|---|---|
| `users` | `email` | `idx_users_email` | Login by email |
| `users` | `google_id` | `idx_users_google_id` | Login by Google |
| `users` | `phone` | `idx_users_phone` | Login by phone |
| `profiles_customer` | `user_id` | `idx_profiles_user_id` | Cari profil dari user |
| `provider_documents` | `provider_id` | `idx_provider_documents_pid` | Dokumen per provider |
| `identity_verifications` | `provider_id` | `idx_identity_verifications_pid` | Verifikasi per provider |
| `user_devices` | `user_id` | `idx_user_devices_pid` | Device per user |
| `order_extensions` | `order_id` | `idx_order_extensions_oid` | Ekstensi per order |
| `task_locations` | `task_id` | `idx_task_locations_tid` | Lokasi per task |
| `task_providers` | `provider_id` | `idx_task_providers_pid` | Task per provider |
| `reports` | `reporter_id` | `idx_reports_reporter_id` | Laporan per user |
| `reports` | `status` | `idx_reports_status` | Filter laporan by status |
| `orders` | `customer_id` | `idx_orders_customer_id` | Order per customer |
| `orders` | `provider_id` | `idx_orders_provider_id` | Order per provider |
| `orders` | `status` | `idx_orders_status` | Filter order by status |
| `payments` | `order_id` | `idx_payments_oid` | Pembayaran per order |
| `reviews` | `customer_id` | `idx_reviews_customer_id` | Ulasan per customer |
| `reviews` | `provider_id` | `idx_reviews_provider_id` | Ulasan per provider |
| `services` | `category_id` | `idx_services_category_id` | Layanan per kategori |
| `provider_services` | `provider_id` | `idx_provider_services_pid` | Layanan per provider |
| `provider_service_prices` | `provider_service_id` | `idx_provider_service_prices_psid` | Harga per layanan provider |
| `provider_locations` | `location` | `provider_locations_geo_idx` (GIST) | Query geospasial |
| `provider_schedules` | `provider_id, work_date` | Komposit | Jadwal per provider per tanggal |

---

## Catatan Khusus

### 1. Relasi Many-to-Many tanpa Tabel Junction

Beberapa relasi many-to-many diatasi tanpa tabel junction eksplisit:

- **users ↔ orders**: Melalui `profiles_customer` (customer) dan `provider_profiles` (provider). Tabel `orders` punya FK ke kedua tabel.
- **categories ↔ pricing_types**: Satu kategori punya banyak pricing type, tapi pricing type juga bisa global (NULL category_id).

### 2. PostGIS Tables

Tabel dengan kolom `geometry`:
- `provider_locations.location` — lokasi real-time provider
- `order_locations.location` — lokasi order
- `custom_tasks.location` — lokasi custom task utama
- `task_locations.location` — lokasi multi-stop task

Semua menggunakan SRID 4326 (WGS 84, koordinat GPS standar).

### 3. UUID Generation

- Mayoritas tabel: `uuid_generate_v4()` (PostgreSQL extension `uuid-ossp`)
- `user_devices`: `gen_random_uuid()` (PostgreSQL native, lebih cepat)
- `roles`: `SERIAL` (auto-increment integer, satu-satunya tabel non-UUID PK)
