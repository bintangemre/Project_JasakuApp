# 01 — Autentikasi dan Verifikasi Provider

## Deskripsi

Modul autentikasi menangani registrasi, login, dan alur verifikasi dokumen untuk provider (mitra). Provider harus melalui proses verifikasi dokumen oleh admin sebelum dapat menerima pesanan.

### Komponen Utama

| File | Fungsi |
|---|---|
| `provider_welcome_screen.dart` | Halaman selamat datang (pilihan login/register) |
| `provider_login_screen.dart` | Form login email + password |
| `provider_register_screen.dart` | Form registrasi multi-step (4 langkah) |
| `provider_register_category_screen.dart` | Pilih kategori layanan (awal registrasi) |
| `provider_register_document_screen.dart` | Upload dokumen verifikasi |
| `provider_register_personal_screen.dart` | Data diri lengkap |
| `provider_profile_completion_screen.dart` | Lengkapi profil setelah register |
| `provider_verification_pending_screen.dart` | Status verifikasi (pending/ditolak) |
| `provider_edit_resubmission_screen.dart` | Form perbaiki data untuk pengajuan ulang |
| `auth_provider.dart` | State management autentikasi (Riverpod) |

## Flow Registrasi Provider

### Langkah 1: Pilih Kategori Layanan

1. Provider membuka aplikasi → halaman Welcome
2. Ketuk **"Daftar sebagai Mitra"** → masuk `ProviderRegisterCategoryScreen`
3. Pilih kategori layanan yang dikuasai
4. Ketuk **"Lanjut"** → masuk ke form registrasi multi-step

### Langkah 2: Form Registrasi Multi-Step (4 Step)

#### Step 1 — Dokumen Verifikasi
1. Upload **Foto Profil Resmi** (wajib) — dari kamera atau galeri
2. Upload **Foto KTP / Identitas** (wajib)
3. Upload **Foto Selfie Pegang KTP** (wajib) — untuk face match
4. (Opsional) Tambah **Portofolio Pengalaman Kerja** — maksimal 5 foto
5. (Opsional) Upload **Ijazah**
6. (Opsional) Tambah **Sertifikat Penunjang** — pilih kategori layanan + deskripsi

#### Step 2 — Keahlian Jasa
1. Pilih jenis keahlian dari daftar layanan yang tersedia
2. Tulis deskripsi keahlian
3. Masukkan patokan harga (Rp)
4. Pilih tipe hitungan tarif (per item, per jam, dll)
5. Ketuk **"Tambahkan Jasa Ke List"** — dapat menambah banyak layanan
6. Lanjut ke Step 3

#### Step 3 — Ringkasan Tarif
1. Review semua layanan yang sudah ditambahkan
2. Dapat menghapus layanan yang tidak diperlukan
3. Ketuk **"Lanjut ke Data Diri"**

#### Step 4 — Data Diri
1. Isi nama lengkap (sesuai KTP)
2. Isi nama panggilan lapangan (nickname)
3. Isi email aktif
4. Isi nomor WhatsApp aktif
5. Pilih tanggal lahir
6. Isi gender (pria/wanita)
7. Isi kota domisili
8. Isi alamat rumah lengkap
9. Buat kata sandi + konfirmasi kata sandi
10. Ketuk **"Daftar Sekarang"**

### Langkah 3: Setelah Registrasi

1. Aplikasi menampilkan halaman **Izin Lokasi** → minta izin GPS
2. Setelah izin ditangani → arahkan ke halaman **Login**
3. Provider login dengan email + password yang baru dibuat

## Flow Login

1. Buka aplikasi → halaman Welcome → ketuk **"Masuk"**
2. Masukkan **Email** dan **Password**
3. Ketuk tombol **"Masuk"**
4. Sistem memanggil `POST /api/auth/login` dengan `expectedRole: 'provider'`

### Hasil Login — 4 kemungkinan:

| Kondisi | Navigasi |
|---|---|
| Verifikasi `pending` | → `ProviderVerificationPendingScreen(status: 'pending')` |
| Verifikasi `rejected` | → `ProviderVerificationPendingScreen(status: 'rejected')` |
| Onboarding belum selesai | → `ProviderProfileCompletionScreen` |
| Semua OK | → `/provider/shell` (dashboard) |

### Login Google OAuth

- Endpoint: `POST /api/auth/login/google`
- Flow: Tap tombol Google → Firebase Auth → kirim ID token ke backend → backend create/find user → return JWT

## Flow Verifikasi

### Status Verifikasi

| Status | Keterangan | Aksi di App |
|---|---|---|
| `pending` | Menunggu review admin | Tampilkan ikon jam + pesan "Akun belum diverifikasi" |
| `active` | Terverifikasi | Langsung masuk ke dashboard |
| `rejected` | Ditolak admin | Tampilkan alasan + opsi perbaiki data |

### Halaman Verifikasi Ditolak

Saat status `rejected`, layar menampilkan:

1. **Ikon cancel** + judul "Akun Ditolak"
2. **Hasil verifikasi admin** dalam format checklist:
   - ✅ / ❌ Nama lengkap sesuai KTP
   - ✅ / ❌ Foto profil wajar dan sesuai
   - ✅ / ❌ Foto KTP jelas dan terbaca
   - ✅ / ❌ Selfie sesuai KTP (face match)
   - ✅ / ❌ Dokumen ijazah/sertifikat jelas
   - ✅ / ❌ Nomor telepon valid
   - ✅ / ❌ Alamat domisili valid
   - ✅ / ❌ Layanan sesuai keahlian
3. **Catatan** dari admin

### Resubmit Verification (2 opsi)

**Opsi A — Perbaiki Data:**
1. Ketuk **"Perbaiki Data"** → masuk `ProviderEditResubmissionScreen`
2. Edit field yang diperlukan (nama, foto, KTP, selfie, dll)
3. Submit → backend update data + reset status ke `pending`
4. Tunggu verifikasi ulang admin

**Opsi B — Ajukan Ulang Langsung:**
1. Ketuk **"Ajukan Ulang Langsung"**
2. Sistem memanggil `POST /api/auth/provider/resubmit-verification` tanpa data baru
3. Status berubah ke `pending`
4. Tunggu verifikasi ulang admin

## API Endpoints

| Method | Endpoint | Fungsi |
|---|---|---|
| `POST` | `/api/auth/register/provider` | Registrasi provider baru (multipart: data + file) |
| `POST` | `/api/auth/login` | Login email + password |
| `POST` | `/api/auth/login/google` | Login via Google OAuth |
| `GET` | `/api/auth/provider/verification-status` | Cek status verifikasi |
| `POST` | `/api/auth/provider/resubmit-verification` | Ajukan ulang verifikasi |
| `POST` | `/api/provider/profile/complete` | Lengkapi profil onboarding |
| `POST` | `/api/provider/services/available-services` | Daftar layanan tersedia |
| `POST` | `/api/provider/services/available-pricing-types` | Daftar tipe harga |

## Provider State Management

**`authProvider`** (Riverpod `StateNotifierProvider<AuthNotifier, AuthState>`)

```dart
class AuthState {
  bool isLoading;
  String? error;
  User? user;                    // { id, email, role, isAdmin }
  String? verificationStatus;    // 'pending' | 'active' | 'rejected'
  String? verificationNotes;     // JSON checklist dari admin
  bool? onboardingCompleted;
  String? token;                 // JWT token
}
```

**Methods di `AuthNotifier`:**
- `login(email, password, expectedRole)` → JWT login
- `loginGoogle()` → Google OAuth login
- `registerProvider(...)` → registrasi multi-field + multipart file upload
- `resubmitVerification()` → ajukan ulang verifikasi
- `logout()` → hapus token + reset state

## Status

**POTENSI ERROR — SEDANG**

### Alasan:
1. **OCR & Face Match belum tentu akurat** — Verifikasi dokumen (KTP, selfie pegang KTP) bergantung pada kualitas foto yang diunggah. Foto buram, pencahayaan kurang, atau resolusi rendah dapat menyebabkan hasil verifikasi tidak akurat.
2. **Upload file besar** — Registrasi mengirim banyak file sekaligus (foto profil, KTP, selfie, portofolio, ijazah, sertifikat). Di jaringan lambat, request dapat timeout.
3. **Validasi client-side belum lengkap** — Beberapa field hanya divalidasi di client (opsional field tidak dikirim ke backend dengan benar).

### Solusi yang Disarankan:
1. Kompresi gambar sudah dilakukan (`image_quality: 70`) — pertahankan
2. Tambahkan validasi ukuran file maksimum di client
3. Tambahkan retry mechanism untuk upload file
4. Pertimbangkan implementasi OCR/face match di backend dengan library yang lebih robust
