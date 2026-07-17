# 11 — Notifikasi

## Deskripsi

Sistem notifikasi menggunakan Firebase Cloud Messaging (FCM) untuk mengirim push notification ke provider. Notifikasi mencakup pesanan baru, status update, pembayaran, verifikasi, custom task, dan lainnya. Badge counter di bottom navigation di-update real-time.

### Komponen Utama

| File | Fungsi |
|---|---|
| `fcm_manager.dart` | FcmManager — inisialisasi FCM, register token, handle messages |
| `notification_provider.dart` | State provider notifikasi |
| `provider_shell.dart` | Badge counter + handle notification tap |
| `notification_service.dart` | Notification helper service |

## Flow

### 1. Inisialisasi FCM

FCM diinisialisasi saat aplikasi bootstrap:

```dart
// core/bootstrap.dart
await FcmManager().initialize();
```

**Proses initialize():**
1. **Request permission**: `_messaging.requestPermission(alert: true, badge: true, sound: true)`
2. **Setup local notifications**: Android channel "jasaku_channel"
3. **Register background handler**: `FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage)`
4. **Ambil FCM token**: `_messaging.getToken()`
5. **Register device ke backend**: `POST /api/notifications/devices/register`
6. **Listen token refresh**: `_messaging.onTokenRefresh.listen(_registerDevice)`
7. **Listen foreground messages**: `FirebaseMessaging.onMessage.listen(_onForegroundMessage)`
8. **Listen notification tap (app closed)**: `FirebaseMessaging.onMessageOpenedApp.listen(...)`
9. **Handle initial message**: `_messaging.getInitialMessage()` (app dibuka dari notifikasi)

### 2. Re-register FCM di ProviderShell

Saat ProviderShell dimuat, FCM di-re-register untuk memastikan token terbaru terkirim:

```dart
// provider_shell.dart → initState()
_reRegisterFcm();
```

```dart
Future<void> _reRegisterFcm() async {
  final token = await FirebaseMessaging.instance.getToken();
  if (token != null) {
    await _dio.post(ApiEndpoints.registerDevice, data: {
      'fcmToken': token,
      'deviceType': 'android',
    });
  }
}
```

### 3. Handle Foreground Message

Saat notifikasi masuk ketika aplikasi terbuka:

```dart
void _handleForegroundMessage(RemoteMessage message) {
  final type = data['type'] ?? '';
  
  // Update badge counter
  if (['NEW_ORDER', 'NEW_CUSTOM_TASK', 'CUSTOM_TASK_ACCEPTED',
       'CUSTOM_TASK_PAYOUT_CONFIRMED', 'NEW_REVIEW'].contains(type)) {
    ref.read(unreadProviderProvider.notifier).state++;
  }
  
  // Refresh dashboard data
  if (['PAYMENT_RECEIVED', 'ORDER_CANCELLED', 'EXTENSION_APPROVED',
       'EXTENSION_REJECTED', 'EXTENSION_ACTIVATED', 'NEW_ORDER',
       'CUSTOM_TASK_ACCEPTED', 'CUSTOM_TASK_COMPLETED',
       'PROVIDER_VERIFIED', 'PROVIDER_REJECTED',
       'CUSTOM_TASK_PAYOUT_CONFIRMED', 'CUSTOM_TASK_FULL'].contains(type)) {
    ref.read(dashboardProvider.notifier).loadDashboard();
  }
}
```

Notifikasi foreground juga ditampilkan sebagai local notification via `flutter_local_notifications`.

### 4. Handle Notification Tap

Saat provider mengetuk notifikasi:

```dart
void _handleNotificationTap(String type, Map<String, String> data) {
  ref.read(unreadProviderProvider.notifier).state = 0;  // Reset badge
  ref.read(dashboardProvider.notifier).loadDashboard();  // Refresh data
  
  switch (type) {
    case 'NEW_CUSTOM_TASK':
    case 'CUSTOM_TASK_ACCEPTED':
    case 'CUSTOM_TASK_COMPLETED':
    case 'CUSTOM_TASK_FULL':
      // → ProviderMyBidsPage
      break;
    case 'NEW_ORDER':
      // → Tab "Permintaan"
      break;
    case 'ORDER_CANCELLED':
    case 'PAYMENT_RECEIVED':
    case 'EXTENSION_APPROVED':
    case 'EXTENSION_REJECTED':
    case 'EXTENSION_ACTIVATED':
    case 'CUSTOM_TASK_PAYOUT_CONFIRMED':
      // → Tab "Orderan"
      break;
    case 'PROVIDER_VERIFIED':
      // → Tab "Profil" + reload profile
      break;
    case 'PROVIDER_REJECTED':
      // → ProviderVerificationPendingScreen
      break;
  }
}
```

### 5. Tipe Notifikasi

| Tipe | Navigasi | Keterangan |
|---|---|---|
| `NEW_ORDER` | Tab Permintaan | Pesanan baru masuk |
| `NEW_CUSTOM_TASK` | ProviderMyBidsPage | Custom task baru tersedia |
| `CUSTOM_TASK_ACCEPTED` | ProviderMyBidsPage | Task yang di-bid diterima |
| `CUSTOM_TASK_COMPLETED` | ProviderMyBidsPage | Task selesai dikerjakan |
| `CUSTOM_TASK_FULL` | ProviderMyBidsPage | Task sudah penuh |
| `CUSTOM_TASK_PAYOUT_CONFIRMED` | Tab Orderan | Pembayaran task dikonfirmasi |
| `PAYMENT_RECEIVED` | Tab Orderan | Pembayaran diterima |
| `ORDER_CANCELLED` | Tab Orderan | Pesanan dibatalkan customer |
| `EXTENSION_APPROVED` | Tab Orderan | Ekstensi disetujui |
| `EXTENSION_REJECTED` | Tab Orderan | Ekstensi ditolak |
| `EXTENSION_ACTIVATED` | Tab Orderan | Ekstensi aktif |
| `PROVIDER_VERIFIED` | Tab Profil | Verifikasi diterima |
| `PROVIDER_REJECTED` | VerificationPendingScreen | Verifikasi ditolak |
| `NEW_REVIEW` | Badge counter | Review baru dari customer |

### 6. Badge Counter

Badge di bottom navigation:
- **Tab Permintaan**: `unreadCount > 0 ? unreadCount : counts.pendingRequests`
- **Tab Orderan**: `todayOrders + upcomingOrders`
- Badge ditampilkan jika tab tidak sedang aktif (`_selectedIndex != index`)
- Badge reset ke 0 saat tab dibuka atau notifikasi di-tap

### 7. Data Flow

```
Backend (Event) → FCM → Firebase → Device
                                      ↓
                    ┌─────────────────┤
                    ↓                 ↓
          App Terbuka            App Tertutup
          (onMessage)           (onMessageOpenedApp)
                    ↓                 ↓
          Local Notification    Deep Link Navigation
          + Update Badge        + Load Data
```

## API Endpoints

| Method | Endpoint | Fungsi |
|---|---|---|
| `POST` | `/api/notifications/devices/register` | Register FCM token device |
| Body | `{ "fcmToken": "...", "deviceType": "android" }` | Token + tipe device |

## Provider State Management

### `unreadProviderProvider` (StateProvider<int>)

```dart
final unreadProviderProvider = StateProvider<int>((ref) => 0);
```

- Di-increment saat notifikasi foreground diterima
- Di-reset ke 0 saat tab dibuka atau notifikasi di-tap
- Digunakan untuk badge di tab Permintaan

## Status

**SUKSES**

Notifikasi berfungsi dengan baik. FCM token ter-register, notifikasi foreground dan background ditangani, deep link navigation berfungsi, dan badge counter di-update real-time.
