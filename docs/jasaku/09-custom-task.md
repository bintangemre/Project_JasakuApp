# Custom Task

## Deskripsi

Custom Task memungkinkan customer membuat tugas khusus yang tidak tersedia dalam kategori layanan standard. Customer mendeskripsikan kebutuhan, menentukan budget, jumlah mitra yang dibutuhkan, dan lokasi. Provider yang berminat akan mengajukan bid, lalu customer memilih provider untuk mengerjakan.

## Flow

### 1. Membuat Task Baru (CustomerCreateTaskPage)

1. Akses dari grid kategori Beranda → tombol **"Custom Task"** → `CustomerMyTasksPage` → tombol **"Buat"**
2. Isi form:
   - **Judul Task** (wajib): Contoh "Bantu angkut barang pindahan"
   - **Deskripsi** (opsional): Detail pekerjaan
   - **Lokasi & Titik Tujuan**:
     - Peta FlutterMap dengan lokasi GPS otomatis
     - Tap peta → dialog "Tambah Titik" → tambah titik tujuan
     - Pencarian tempat via Nominatim (min 3 karakter)
     - Daftar titik ditampilkan dengan nomor urut
   - **Detail Lokasi** (opsional): Alamat detail rumah/gedung
   - **Masa Publish**: 1, 2, atau 3 hari (ChoiceChip)
   - **Budget per Orang** (wajib): Input angka dalam Rupiah
   - **Jumlah Orang** (wajib): Default 1
   - **Foto Pendukung** (opsional): Maksimal 5 foto, kualitas 70%

3. **Ringkasan Pembayaran** otomatis:
   ```
   Budget per orang:     Rp 100.000/orang
   Jumlah orang:         2 orang
   Total budget:         Rp 200.000
   Fee aplikasi 5%:      Rp 10.000
   ─────────────────────
   Total dibayar:        Rp 210.000
   ```

4. Tap **"Buat Task"** → `POST /api/custom-tasks/`

### 2. Task Saya (CustomerMyTasksPage)

1. `GET /api/custom-tasks/mine` → daftar task yang dibuat customer
2. Setiap kartu task menampilkan:
   - Judul + badge status
   - Jumlah mitra diterima / jumlah yang dibutuhkan
   - Budget per orang
   - Jumlah titik lokasi
   - Mini peta (lokasi awal)
   - Info kedaluwarsa

3. **Status Task**:

| Status | Label | Warna |
|---|---|---|
| `open` (belum ada bid) | Mencari Mitra | Biru |
| `open` (sudah ada bid diterima) | Berjalan | Kuning |
| `in_progress` | Berjalan | Kuning |
| `completed` / `fulfilled` | Selesai | Hijau |
| `cancelled` | Dibatalkan | Abu-abu |

4. **Aksi per task**:
   - Tap kartu → navigasi ke `TaskDetailPage`
   - Status `in_progress` → tombol **"Lacak Mitra"** → `CustomTaskTrackingPage`
   - Status `completed`/`fulfilled` → progress selesai + tombol **"Hapus"**
   - Status `open` + kedaluwarsa → tombol **"Publikasi Ulang"**

### 3. Detail Task (TaskDetailPage)

**Info Task:**
- Judul, deskripsi, gambar
- Status badge
- Banner status:
  - "Menunggu diterima provider" (biru)
  - "Pembayaran Diperlukan" (merah) + tombol **"Bayar"**
  - "Menunggu Konfirmasi" (kuning) — bukti sudah dikirim
  - "Pembayaran sudah dikonfirmasi" (hijau)

**Budget Detail:**
- Budget per orang × jumlah mitra = Total budget
- Fee aplikasi 5%
- Total dibayar

**Lokasi:**
- Peta dengan semua titik (lokasi awal + titik tujuan)
- Daftar alamat per titik

**Daftar Mitra:**
- Nama mitra + badge status (Berjalan/Selesai)

### 4. Tracking Custom Task (CustomTaskTrackingPage)

1. `GET /api/custom-tasks/{taskId}/tracking` → ambil `orderId`
2. Jika ada `orderId` → redirect ke `OrderTrackingPage` (tracking standar)
3. Jika tidak ada → tampilkan SnackBar "Belum ada pesanan aktif"

### 5. Pembayaran Custom Task (CustomerPaymentPage)

1. `GET /api/custom-tasks/{taskId}/payment-detail` → detail pembayaran
2. Tampilkan:
   - Status: Sudah dibayar / Menunggu konfirmasi / Belum dibayar
   - Rincian biaya: Budget/orang × jumlah provider + Fee
   - Rekening admin (bank, QRIS, e-wallet) dari `adminAccounts`
3. **Upload Bukti Transfer**:
   - Pilih foto dari galeri
   - Tap **"Kirim Bukti Pembayaran"**
   - `POST /api/custom-tasks/{taskId}/upload-proof`
4. Setelah upload → status berubah ke `proof_uploaded`
5. Admin memverifikasi → status berubah ke `paid`

### 6. Hapus Task

1. Tap tombol **"Hapus"** pada task selesai
2. Dialog konfirmasi: "Task akan dihapus permanen"
3. `DELETE /api/custom-tasks/{taskId}`

### 7. Publikasi Ulang

1. Jika task berstatus `open` tapi sudah kedaluwarsa
2. Tap **"Publikasi Ulang"** → `POST /api/custom-tasks/{taskId}/republish`
3. Task dipublikasi ulang dengan masa publish baru

## API Endpoints

| Endpoint | Method | Keterangan |
|---|---|---|
| `/api/custom-tasks/` | POST | Buat task baru |
| `/api/custom-tasks/mine` | GET | Daftar task customer |
| `/api/custom-tasks/{taskId}` | GET | Detail task |
| `/api/custom-tasks/{taskId}` | DELETE | Hapus task |
| `/api/custom-tasks/{taskId}/republish` | POST | Publikasi ulang |
| `/api/custom-tasks/{taskId}/tracking` | GET | Tracking task |
| `/api/custom-tasks/{taskId}/payment-detail` | GET | Detail pembayaran |
| `/api/custom-tasks/{taskId}/upload-proof` | POST | Upload bukti transfer |

## Fee Platform

- **Fee**: 5% dari total budget (budget per orang × jumlah orang)
- **Contoh**: Budget Rp 100.000 × 2 orang = Rp 200.000 → Fee Rp 10.000 → Total Rp 210.000

## Provider State Management

| Provider | Tipe | Keterangan |
|---|---|---|
| — | State lokal | Menggunakan `StatefulWidget` + `setState()` per halaman |
| — | `CustomTasksRepository` | Repository untuk semua API call custom task |

## Screen Files

| Screen | Path |
|---|---|
| Buat Task | `features/custom_tasks/presentation/pages/customer_create_task_page.dart` |
| Task Saya | `features/custom_tasks/presentation/pages/customer_my_tasks_page.dart` |
| Detail Task | `features/custom_tasks/presentation/pages/task_detail_page.dart` |
| Tracking Task | `features/custom_tasks/presentation/pages/custom_task_tracking_page.dart` |
| Pembayaran Task | `features/custom_tasks/presentation/pages/customer_payment_page.dart` |
| Repository | `features/custom_tasks/data/custom_tasks_repository.dart` |

## Status

**(POTENSI ERROR - SEDANG)**

**Alasan:**
1. **Multi-provider flow kompleks**: Satu task bisa dikerjakan beberapa provider, masing-masing punya order terpisah. Status perlu disinkronkan antar provider.
2. **Pembayaran manual ke admin**: Customer harus transfer manual ke rekening admin, lalu upload bukti. Tidak ada payment gateway otomatis.
3. **Status `fulfilled` vs `completed`**: Ada dua status selesai yang bisa membingungkan — `completed` (semua provider selesai) dan `fulfilled` (semua sudah dibayar).
4. **Kedaluwarsa task**: Task expired tapi provider bisa sudah menerima. Kasus edge case yang perlu penanganan lebih baik.

**Solusi yang Disarankan:**
- Tambahkan payment gateway (midtrans/xendit) untuk pembayaran otomatis
- Simplifikasi status: gunakan satu status `completed` saja
- Tambahkan validasi di backend untuk mencegah order pada task yang sudah expired
