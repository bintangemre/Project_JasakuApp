# Overview — Aplikasi Jasaku Customer

## Deskripsi

Jasaku Customer adalah aplikasi mobile marketplace jasa home-service untuk pelanggan (customer). Aplikasi ini memungkinkan customer mencari penyedia jasa (mitra/provider), melakukan pemesanan, melacak pesanan, membayar, dan memberikan ulasan.

Aplikasi customer berbagi codebase yang sama dengan aplikasi Mitra/Provider (`jasaku_app/`), namun memiliki entry point, tema, dan route terpisah.

## Tech Stack

| Komponen | Teknologi |
|---|---|
| Framework | Flutter 3.7+ |
| State Management | Riverpod (flutter_riverpod) |
| HTTP Client | Dio (singleton dengan JWT interceptor) |
| Peta | FlutterMap + OpenStreetMap tiles |
| Routing | OpenRouteService (ORS) |
| Auth Token Storage | flutter_secure_storage |
| Firebase | Firebase Core + Firebase Messaging (FCM) |
| Lokasi | Geolocator |
| Format Tanggal | intl (locale `id`) |

## Entry Point

- **File**: `lib/main_customer.dart`
- **Class**: `JasakuCustomerApp`
- **Theme**: Biru (`AppTheme.customerTheme`), warna utama `Color(0xFF2563EB)`
- **Initial Route**: `/welcome`

## Bootstrap Flow

```
main() → bootstrap(ProviderScope(child: JasakuCustomerApp()))
  ├── WidgetsFlutterBinding.ensureInitialized()
  ├── Firebase.initializeApp()
  ├── FcmManager().initialize()          ← Setup FCM listener
  ├── RoutingService.init(ORS_API_KEY)   ← Setup OpenRouteService
  ├── initializeDateFormatting('id')     ← Locale Indonesia
  └── runApp(app)
```

## Route Aplikasi

| Route | Screen | Keterangan |
|---|---|---|
| `/welcome` | `WelcomeScreen` | Halaman pembuka, pilihan login/register |
| `/login` | `CustomerLoginScreen` | Login email/password + Google OAuth |
| `/register` | `CustomerRegisterScreen` | Registrasi akun customer baru |
| `/customer/shell` | `CustomerShell` | Main shell dengan bottom navigation |

## Bottom Navigation (CustomerShell)

| Tab | Icon | Halaman | Keterangan |
|---|---|---|---|
| **Beranda** | `Icons.home` | `CustomerHome` | Dashboard, grid kategori, pesanan terbaru |
| **Pesanan** | `Icons.access_time` | `CustomerOrderListPage` | Daftar pesanan dengan filter |
| **Profil** | `Icons.person` | `CustomerProfile` | Profil, menu settings, logout |

**Catatan**: Tab Notifikasi dihilangkan dari bottom nav, akses melalui ikon lonceng di header Beranda.

## Arsitektur Networking

```
ApiClient (Singleton)
  ├── Dio instance
  │     ├── baseUrl: ApiEndpoints.baseUrl (via --dart-define=BASE_URL)
  │     ├── connectTimeout: 60 detik
  │     ├── receiveTimeout: 30 detik
  │     └── Headers: Content-Type: application/json
  └── InterceptorsWrapper
        ├── onRequest: Sisipkan JWT token dari StorageService
        └── onError: Forward error
```

## Penyimpanan Token

- **Library**: `flutter_secure_storage`
- **Key**: `jwt_token`
- **Class**: `StorageService` (`core/utils/storage.dart`)
- **Operasi**: `saveToken()`, `getToken()`, `deleteToken()`, `hasToken()`

## File Structure (Fitur Customer)

```
lib/
├── main_customer.dart                          ← Entry point
├── core/
│   ├── bootstrap.dart                          ← Firebase + FCM init
│   ├── constants/
│   │   ├── api_endpoints.dart                  ← URL semua API
│   │   └── app_colors.dart                     ← Warna tema
│   ├── network/
│   │   └── api_client.dart                     ← Dio singleton
│   ├── theme/
│   │   └── app_theme.dart                      ← Tema biru customer
│   └── utils/
│       ├── storage.dart                        ← JWT secure storage
│       ├── operating_hours.dart                ← Utilitas jam operasional
│       └── image_url.dart                      ← Helper URL gambar
└── features/
    ├── auth/                                   ← Login, register, OAuth
    ├── customer/                               ← Halaman utama customer
    │   └── presentation/
    │       ├── screens/                        ← Semua halaman customer
    │       └── providers/                      ← Customer profile & search
    ├── orders/                                 ← Pemesanan & tracking
    ├── payments/                               ← Pembayaran & instruksi
    ├── tracking/                               ← Live tracking peta
    ├── custom_tasks/                           ← Custom task (customer & provider)
    ├── notifications/                          ← FCM & notifikasi
    ├── reports/                                ← Laporan/ komplain
    ├── services/                               ← Service categories
    ├── welcome/                                ← Welcome screen
    └── location/                               ← Location tracker (provider)
```

## Perbedaan Customer vs Mitra

| Aspek | Customer (Jasaku) | Mitra (Jasaku Mitra) |
|---|---|---|
| Entry point | `main_customer.dart` | `main_provider.dart` |
| Tema | Biru (`0xFF2563EB`) | Teal (`0xFF0D9488`) |
| Aplikasi ID | `com.jasaku.app` | `com.jasaku.mitra` |
| Peran | Mencari & memesan jasa | Menerima & mengerjakan order |
| Menu utama | Beranda, Pesanan, Profil | Dashboard, Pesanan, Profil |

## Status

**(SUKSES)** — Aplikasi customer berfungsi penuh dengan semua fitur utama: autentikasi, pencarian layanan, pemesanan, pembayaran, tracking, review, custom task, notifikasi, dan laporan.
