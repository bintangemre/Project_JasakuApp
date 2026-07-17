# 00 — Overview: Aplikasi Mitra Jasaku (Provider)

## Deskripsi

Mitra Jasaku adalah aplikasi mobile untuk **provider/pekerja layanan** di platform Jasaku. Aplikasi ini dibangun dengan Flutter 3.7+ menggunakan arsitektur **shared codebase** bersama aplikasi customer, namun memiliki entry point, tema, dan route yang berbeda.

### Stack Teknologi

| Komponen | Teknologi |
|---|---|
| Framework | Flutter 3.7+ |
| State Management | Riverpod |
| Networking | Dio (singleton + interceptor JWT) |
| Peta | FlutterMap + OpenStreetMap tiles |
| Lokasi | Geolocator |
| Notifikasi | Firebase Cloud Messaging (FCM) + flutter_local_notifications |
| Penyimpanan Lokal | flutter_secure_storage |
| Backend | Express 5 / TypeScript / Prisma 7 / PostgreSQL |

### Tema Aplikasi

- **Warna utama**: Teal (`#0F766E` untuk Material theme, `#00A651` untuk UI dashboard)
- **Warna sekunder**: Biru (`#2563EB`) untuk tombol aksi
- **Background**: Putih abu (`#F8FAFC`)
- **Material 3**: Aktif (`useMaterial3: true`)

## Entry Point

File: `lib/main_provider.dart`

```dart
void main() {
  bootstrap(
    const ProviderScope(
      child: JasakuProviderApp(),
    ),
  );
}
```

### Bootstrap Flow (`core/bootstrap.dart`)

1. `WidgetsFlutterBinding.ensureInitialized()` — inisialisasi binding Flutter
2. `Firebase.initializeApp()` — inisialisasi Firebase dengan `DefaultFirebaseOptions`
3. `FcmManager().initialize()` — setup FCM: request permission, register device token, listen foreground messages
4. `RoutingService.init(ORS_API_KEY)` — inisialisasi OpenRouteService untuk perhitungan rute
5. `initializeDateFormatting('id')` — format tanggal Bahasa Indonesia
6. `runApp(app)` — jalankan aplikasi

### Route Aplikasi

| Route | Screen | Keterangan |
|---|---|---|
| `/welcome` | `ProviderWelcomeScreen` | Halaman selamat datang (initial route) |
| `/login` | `ProviderLoginScreen` | Login email/password |
| `/register` | `ProviderRegisterCategoryScreen` | Form registrasi multi-step |
| `/faq` | `ProviderFaqScreen` | FAQ |
| `/terms` | `ProviderTermsScreen` | Syarat & ketentuan |
| `/provider/shell` | `ProviderShell` | Shell utama setelah login |

## Bottom Navigation (ProviderShell)

ProviderShell menggunakan `IndexedStack` untuk mempertahankan state setiap halaman:

| Index | Label | Icon | Halaman |
|---|---|---|---|
| 0 | Beranda | `grid_view_rounded` | `ProviderHomePage` (Dashboard) |
| 1 | Permintaan | `history_toggle_off` | `ProviderRequestsPage` (Incoming requests) |
| 2 | Orderan | `assignment_outlined` | `ProviderOrderManagementPage` (3-tab order) |
| 3 | Profil | `person_outline` | `ProviderProfilePage` |
| 4 (admin) | Admin | `admin_panel_settings` | `AdminPendingExtensionsPage` |

**Badge logic**:
- Badge Permintaan = `unreadCount` (dari notifikasi) atau `pendingRequests` (dari API)
- Badge Orderan = `todayOrders + upcomingOrders`

**Timer otomatis**: Fetch counts dilakukan setiap **30 detik** via `Timer.periodic`.

## Perbedaan dengan Customer App

| Aspek | Customer App | Provider (Mitra) App |
|---|---|---|
| Entry point | `main_customer.dart` | `main_provider.dart` |
| Tema warna | Biru (`#1976D2`) | Teal (`#0F766E`) |
| Package name (Android) | `com.jasaku.app` | `com.jasaku.mitra` |
| Nama aplikasi | Jasaku | Jasaku Mitra |
| Route utama | `/customer/shell` | `/provider/shell` |
| Bottom nav | Beranda, Pesanan, Riwayat, Profil | Beranda, Permintaan, Orderan, Profil |

## File Structure

```
lib/
├── main_provider.dart                          # Entry point provider
├── core/
│   ├── bootstrap.dart                          # Firebase + FCM init
│   ├── constants/
│   │   ├── api_endpoints.dart                  # Semua endpoint API
│   │   └── app_colors.dart                     # Warna theme
│   ├── network/
│   │   └── api_client.dart                     # Dio singleton + JWT interceptor
│   ├── theme/
│   │   └── app_theme.dart                      # Theme definitions
│   └── utils/
│       ├── operating_hours.dart                # Cek jam operasional
│       ├── storage.dart                        # Secure storage wrapper
│       ├── image_url.dart                      # URL builder untuk gambar
│       └── image_compressor.dart               # Kompresi gambar sebelum upload
├── features/
│   ├── auth/                                   # Login, register, verifikasi
│   ├── provider/                               # Dashboard, profil, order management
│   ├── customer/                               # (Digunakan oleh customer app)
│   ├── orders/                                 # Model & provider order
│   ├── custom_tasks/                           # Custom task (provider + customer)
│   ├── location/                               # Location tracking
│   ├── notifications/                          # FCM manager
│   ├── payments/                               # Payout methods
│   ├── reports/                                # Laporan masalah
│   └── tracking/                               # Live tracking map
├── services/
│   ├── routing_service.dart                    # ORS route calculation
│   ├── notification_service.dart               # Notification helper
│   └── location_service.dart                   # Location helper
└── firebase/
    ├── firebase_options.dart                   # Firebase config
    └── firebase_api.dart                       # Firebase API helper
```

## Status

**SUKSES** — Aplikasi provider berfungsi dengan baik. Bootstrap flow, bottom navigation, dan semua fitur utama telah bekerja.
