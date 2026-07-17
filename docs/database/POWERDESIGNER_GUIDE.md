# Panduan Import Jasaku Database ke PowerDesigner

## File yang Tersedia

| File | Kegunaan |
|---|---|
| `jasaku_ddl.sql` | SQL DDL script — import langsung ke PowerDesigner |
| `cdm.plantuml` | Conceptual Data Model (PlantUML) |
| `ldm.plantuml` | Logical Data Model (PlantUML) |
| `pdm.plantuml` | Physical Data Model (PlantUML) |
| `erd.plantuml` | Entity Relationship Diagram (PlantUML) |

---

## Cara Import ke PowerDesigner

### Langkah 1: Buat PDM dari SQL DDL

1. Buka **PowerDesigner**
2. **File** → **New Model** → **Model Types: Physical Data Model**
   - Model name: `Jasaku_PDM`
   - DBMS: **PostgreSQL 15.x** (atau versi yang kamu pakai)
   - Click **OK**
3. **Database** → **Reverse Engineer** → **Database...**
   - Script file: pilih `jasaku_ddl.sql`
   - Click **OK** / **Reverse**
4. PowerDesigner akan generate semua **31 tabel** beserta kolom, PK, FK, dan indexes
5. **Arrange** diagram: drag & drop tabel, gunakan **Layout > Arrange All** untuk auto-layout

### Langkah 2: Generate LDM dari PDM

Dari PDM yang sudah jadi:

1. **Tools** → **Generate Logical Data Model**
   - Name: `Jasaku_LDM`
   - PDM Selection: pilih `Jasaku_PDM`
   - Opsi:
     - ☑ Keep custom naming
     - ☑ Save generated model
   - Click **OK**
2. PowerDesigner akan convert tipe data physical → logical:
   - `UUID` → `Guid`
   - `VARCHAR(100)` → `Variable Characters (100)`
   - `DECIMAL(12,2)` → `Number (12,2)`
   - `BOOLEAN` → `Boolean`
   - `TIMESTAMP` → `Date & Time`
   - `GEOMETRY` → `Undefined (Spatial)`
   - `JSONB` → `Text`
   - `TEXT[]` → `Text`
3. **Cleanup**: hapus tipe data physical, ganti dengan logical type yang sesuai

### Langkah 3: Generate CDM dari LDM

Dari LDM yang sudah jadi:

1. **Tools** → **Generate Conceptual Data Model**
   - Name: `Jasaku_CDM`
   - LDM Selection: pilih `Jasaku_LDM`
   - Opsi:
     - ☑ Keep custom naming
     - ☑ Save generated model
   - Click **OK**
2. PowerDesigner akan:
   - Hapus atribut PK/FK (hanya entitas + relasi)
   - Group entitas berdasarkan namespace/subject area
3. **Manual cleanup**:
   - Group entitas per domain (Autentikasi, Layanan, Pesanan, Pembayaran, Custom Tasks, Ulasan)
   - Simplifikasi relasi (hilangkan FK, tampilkan cardinalitas saja)
   - Tambahkan warna per domain

---

## Tips PowerDesigner

### Auto-Layout
- Select semua tabel → **Layout** → **Arrange All**
- Atau drag manual untuk posisi yang lebih rapi

### Subject Areas (Grouping)
Untuk CDM/LDM, buat **Subject Areas** per domain:
1. **Edit** → **New Subject Area**
2. Buat 6 subject area:
   - Autentikasi & Pengguna
   - Katalog Layanan
   - Pesanan (Orders)
   - Pembayaran
   - Custom Tasks (Tender)
   - Ulasan & Laporan
3. Drag entitas ke subject area masing-masing

### Export ke Image
- **File** → **Print** → **Print to Image** (BMP/PNG)
- Atau **Edit** → **Copy Image** untuk paste ke dokumen

### Color Coding
Klik tabel → **Properties** → **Extended Attributes** → **Fill Color**:
- Users/Auth: `#E8F5E9` (hijau muda)
- Services: `#E3F2FD` (biru muda)
- Orders: `#FFF3E0` (orange muda)
- Payments: `#F3E5F5` (ungu muda)
- Custom Tasks: `#E0F7FA` (cyan muda)
- Reviews: `#FFF9C4` (kuning muda)

---

## Struktur 31 Tabel

### Autentikasi & Pengguna (9 tabel)
| Tabel | Fungsi |
|---|---|
| `roles` | Role user (customer, provider, admin) |
| `users` | Semua akun |
| `profiles_customer` | Profil customer |
| `provider_profiles` | Profil mitra |
| `provider_locations` | Lokasi GPS mitra |
| `provider_documents` | KTP, selfie, dll |
| `provider_payout_methods` | Rekening pencairan |
| `identity_verifications` | Verifikasi KTP + face match |
| `user_devices` | Token FCM |

### Katalog Layanan (5 tabel)
| Tabel | Fungsi |
|---|---|
| `categories` | Kategori layanan |
| `pricing_types` | Tipe harga (per jam, per meteri) |
| `services` | Sub-layanan |
| `provider_services` | Layanan yang ditawarkan mitra |
| `provider_service_prices` | Harga per mitra |

### Pesanan (6 tabel)
| Tabel | Fungsi |
|---|---|
| `orders` | Pesanan utama |
| `order_items` | Item dalam pesanan |
| `order_locations` | Lokasi tujuan |
| `order_attachments` | Lampiran foto |
| `order_extensions` | Perpanjangan waktu |
| `provider_schedules` | Jadwal kerja |

### Pembayaran (4 tabel)
| Tabel | Fungsi |
|---|---|
| `payments` | Status pembayaran |
| `admin_bank_accounts` | Rekening bank admin |
| `admin_ewallet_accounts` | E-wallet admin |
| `admin_qris_accounts` | QRIS admin |

### Custom Tasks (3 tabel)
| Tabel | Fungsi |
|---|---|
| `custom_tasks` | Task tender/bidding |
| `task_locations` | Titik lokasi multi-stop |
| `task_providers` | Mitra yang menerima task |

### Ulasan & Laporan (2 tabel)
| Tabel | Fungsi |
|---|---|
| `reviews` | Rating & ulasan |
| `reports` | Laporan aduan |
