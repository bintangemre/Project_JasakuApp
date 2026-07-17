# Profil Saya

## Deskripsi

Halaman profil customer menampilkan informasi akun, memberikan akses ke pengaturan, riwayat pesanan, laporan, dan logout. Fitur edit profil memungkinkan customer memperbarui nama panggilan, nomor telepon, jenis kelamin, tanggal lahir, alamat, dan foto avatar.

## Flow

### 1. Melihat Profil (CustomerProfile)

1. Customer buka tab **Profil** di bottom navigation
2. `customerProfileProvider` memanggil `GET /api/customer/profile`
3. Data profil ditampilkan dalam beberapa bagian:

**Kartu Profil:**
- Foto avatar (atau placeholder icon person)
- Tombol kamera di pojok kanan bawah avatar → ganti avatar
- Nama lengkap
- Nickname (jika ada): `@nickname`
- Email

**Kartu Info Akun:**
- Icon + email → tap untuk ke halaman **Edit Info Akun**

**Menu Section:**
| Menu | Icon | Aksi |
|---|---|---|
| Riwayat Pesanan | receipt_long | Navigasi ke `CustomerOrderListPage` |
| Laporkan Masalah | shield | Navigasi ke `ReportFormPage` |
| Riwayat Laporan | history | Navigasi ke `ReportHistoryPage` |
| Tentang Aplikasi | info | Dialog "Tentang Jasaku" (versi 1.0.0) |

**Tombol Logout:**
- OutlinedButton merah: "Logout"
- Konfirmasi → hapus token → navigasi ke `/login`

### 2. Ganti Avatar

1. Tap ikon kamera di avatar
2. `ImagePicker` dari galeri (maxWidth/maxHeight: 512px)
3. `customerProfileProvider.notifier.uploadAvatar(path)` dipanggil
4. Avatar diupload ke backend
5. Profil refresh dengan avatar baru

### 3. Edit Info Akun (CustomerEditInfoPage)

1. Dari halaman profil, tap kartu **"Info Akun"**
2. Form edit ditampilkan dengan data yang sudah ada:
   - **Nama Panggilan**: TextField (opsional)
   - **Nomor Telepon**: TextField (opsional, keyboardType: phone)
   - **Jenis Kelamin**: Dropdown (Laki-laki / Perempuan)
   - **Tanggal Lahir**: DatePicker (1950 - sekarang)
   - **Alamat**: TextField multiline (opsional)
3. Perubahan ditandai dengan `_hasChanges = true`
4. Tombol **"Simpan"** di AppBar (disabled jika tidak ada perubahan)
5. `customerProfileProvider.notifier.updateProfile()` dipanggil
6. `PATCH /api/customer/profile` dengan data yang diubah
7. Jika sukses → SnackBar "Profil berhasil diperbarui" → navigasi kembali
8. Jika gagal → SnackBar error

### 4. Tentang Aplikasi

Dialog `AlertDialog` menampilkan:
- Nama aplikasi: "Jasaku"
- Deskripsi: "Aplikasi jasa home-service untuk kebutuhan harianmu."
- Versi: 1.0.0
- Copyright: © 2026 Jasaku Apps

## API Endpoints

| Endpoint | Method | Keterangan |
|---|---|---|
| `/api/customer/profile` | GET | Ambil profil customer |
| `/api/customer/profile` | PATCH | Update profil customer |

### Response — Profil

```json
{
  "data": {
    "email": "user@example.com",
    "phone": "08123456789",
    "profile": {
      "full_name": "Budi Santoso",
      "nickname": "budi",
      "avatar_url": "https://...",
      "gender": "Laki-laki",
      "birth_date": "1995-05-15",
      "address": "Jl. Merdeka No. 123"
    }
  }
}
```

### Request — Update Profil

```json
{
  "nickname": "budi_baru",
  "phone": "08987654321",
  "gender": "Laki-laki",
  "birthDate": "1995-05-15",
  "address": "Jl. Baru No. 456"
}
```

## Provider State Management

| Provider | Tipe | Keterangan |
|---|---|---|
| `customerProfileProvider` | `StateNotifier<CustomerProfileNotifier, CustomerProfileState>` | State profil customer |

### CustomerProfileState

```dart
class CustomerProfileState {
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final CustomerProfileData? data;
}
```

### CustomerProfileData

```dart
class CustomerProfileData {
  final String? email;
  final String? phone;
  final ProfileInfo? profile;
}

class ProfileInfo {
  final String? fullName;
  final String? nickname;
  final String? avatarUrl;
  final String? gender;
  final String? birthDate;
  final String? address;
}
```

### Methods

| Method | Keterangan |
|---|---|
| `fetchProfile()` | Ambil profil dari backend |
| `updateProfile(...)` | Update field profil |
| `uploadAvatar(path)` | Upload foto avatar |

## Screen Files

| Screen | Path |
|---|---|
| Profil Saya | `features/customer/presentation/screens/customer_profile.dart` |
| Edit Info | `features/customer/presentation/screens/customer_edit_info_page.dart` |
| Profile Provider | `features/customer/presentation/providers/customer_profile_provider.dart` |

## Status

**(SUKSES)** — Profil customer berfungsi penuh: tampilan profil, edit info (nama, telepon, gender, tanggal lahir, alamat), upload avatar, dan logout. Semua perubahan tersimpan ke backend via PATCH.
