# Autentikasi — Login, Register, Google OAuth

## Deskripsi

Modul autentikasi menangani proses masuk dan pendaftaran akun customer. Mendukung login dengan email/password, login via Google OAuth, dan registrasi akun baru. Token JWT disimpan secara aman di `flutter_secure_storage`.

## Flow

### 1. Welcome Screen

1. Customer membuka aplikasi → halaman `/welcome` ditampilkan
2. Dua tombol utama: **"Masuk"** (ke `/login`) dan **"Daftar"** (ke `/register`)
3. Jika sudah login sebelumnya, otomatis redirect ke `/customer/shell`

### 2. Login Email/Password

1. Customer mengisi form **Email** dan **Password**
2. Tekan tombol **"Masuk"**
3. Validasi form: email wajib diisi, password wajib diisi
4. `authProvider.notifier.login()` dipanggil dengan parameter `expectedRole: 'customer'`
5. Backend memproses `POST /api/auth/login` → mengembalikan JWT token
6. Token disimpan ke `flutter_secure_storage` (key: `jwt_token`)
7. Navigasi ke `/customer/shell` (dashboard utama)

### 3. Login Google OAuth

1. Di halaman login, tekan tombol **"Google"**
2. `authProvider.notifier.loginWithGoogle(expectedRole: 'customer')` dipanggil
3. Google Sign-In flow dimulai (native Google OAuth)
4. Backend memproses `POST /api/auth/login/google` → mengembalikan JWT token
5. Token disimpan → navigasi ke `/customer/shell`

### 4. Register Customer

1. Dari halaman login, tekan link **"Daftar"** → navigasi ke `/register`
2. Isi form: **Nama Lengkap**, **Nomor Telepon** (opsional), **Email**, **Password**
3. Tekan tombol **"Daftar"**
4. Validasi: semua field wajib diisi (email, password, nama)
5. `authProvider.notifier.registerCustomer()` dipanggil
6. Backend memproses `POST /api/auth/register/customer`
7. Jika sukses → SnackBar "Registrasi berhasil! Silakan login." → navigasi kembali ke halaman login

### 5. Error Handling

- Jika email tidak ditemukan → tampilkan pesan error + tombol **"Belum punya akun? Daftar sekarang"**
- Jika password salah → tampilkan pesan error
- Semua error ditampilkan dalam container merah di bawah form

### 6. Logout

1. Dari halaman **Profil** → tekan tombol **"Logout"**
2. `authProvider.notifier.logout()` dipanggil → token dihapus dari storage
3. Navigasi ke `/login` dengan `pushNamedAndRemoveUntil` (hapus semua route sebelumnya)

## API Endpoints

| Endpoint | Method | Keterangan |
|---|---|---|
| `/api/auth/login` | POST | Login email/password |
| `/api/auth/login/google` | POST | Login via Google OAuth |
| `/api/auth/register/customer` | POST | Registrasi customer baru |
| `/api/auth/logout` | POST | Logout |
| `/api/auth/me` | GET | Ambil data user dari token (restore session) |

### Request Body — Login

```json
{
  "email": "user@example.com",
  "password": "secret123",
  "role": "customer"
}
```

### Request Body — Register

```json
{
  "email": "user@example.com",
  "password": "secret123",
  "name": "Budi Santoso",
  "phone": "08123456789",
  "role": "customer"
}
```

### Response — Login

```json
{
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "user": {
      "id": "uuid",
      "email": "user@example.com",
      "displayName": "Budi Santoso",
      "role": "customer"
    }
  }
}
```

## Provider State Management

| Provider | Tipe | Keterangan |
|---|---|---|
| `authProvider` | `StateNotifier<AuthState>` | State autentikasi global |

### AuthState

```dart
class AuthState {
  final bool isLoading;
  final String? error;
  final User? user;
}
```

### AuthProvider Methods

| Method | Parameter | Keterangan |
|---|---|---|
| `login()` | email, password, expectedRole | Login email/password |
| `loginWithGoogle()` | expectedRole | Login Google OAuth |
| `registerCustomer()` | email, password, name, phone | Register customer |
| `logout()` | — | Hapus token, reset state |
| `restoreSession()` | meData | Restore user dari `/api/auth/me` |

## Screen Files

| Screen | Path |
|---|---|
| Welcome | `features/welcome/presentation/screens/welcome_screen.dart` |
| Login | `features/auth/presentation/screens/customer_login_screen.dart` |
| Register | `features/auth/presentation/screens/customer_register_screen.dart` |

## Status

**(SUKSES)** — Login email/password, Google OAuth, dan registrasi customer berfungsi penuh. Session restore otomatis via `/api/auth/me` saat shell dimuat.
