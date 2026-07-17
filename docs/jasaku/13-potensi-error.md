# Potensi Error dan Masalah yang Diketahui

## Ringkasan

Dokumen ini mencatat semua potensi error, bug, dan masalah yang telah teridentifikasi dalam aplikasi Jasaku Customer, beserta level risiko dan solusi yang disarankan.

---

## 1. Timezone Issue — DateTime.now() vs WITA

**Level: TINGGI**

**Deskripsi:**
`OperatingHours` menggunakan `DateTime.now()` yang bergantung pada timezone perangkat. Jika customer berada di luar zona WITA (UTC+8), validasi jam operasional akan salah.

**Lokasi Masalah:**
- `core/utils/operating_hours.dart` → `isWithinOperatingHours()`, `canOrderNow()`, `isToday()`

**Contoh Bug:**
- Customer di Jakarta (WIB, UTC+7) pukul 07:00 WIB → `DateTime.now().hour == 7` → dianggap "sebelum jam operasional" padahal di WITA sudah 08:00 (waktu operasional aktif)
- Customer di Makassar (WITA) pukul 16:30 WITA → dianggap "setelah operasional" (benar), tapi customer di Jakarta pukul 16:30 WIB (17:30 WITA) juga dianggap "setelah operasional" (benar secara kebetulan)

**Solusi:**
```dart
// Gunakan konversi timezone manual
static DateTime get nowWita {
  return DateTime.now().toUtc().add(const Duration(hours: 8));
}
```
Atau gunakan package `timezone` + `flutter_localizations` untuk konversi yang lebih robust.

---

## 2. Custom Task — Alur Pembayaran Manual

**Level: SEDANG**

**Deskripsi:**
Pembayaran custom task memerlukan transfer manual ke rekening admin + upload bukti. Tidak ada payment gateway otomatis. Ini menciptakan beberapa masalah:

1. Customer bisa upload bukti palsu
2. Admin harus verifikasi manual satu per satu
3. Delay pembayaran memperlambat pekerjaan provider

**Lokasi Masalah:**
- `features/custom_tasks/presentation/pages/customer_payment_page.dart`
- `features/custom_tasks/presentation/pages/task_detail_page.dart`

**Solusi:**
- Integrasi payment gateway (Midtrans/Xendit) untuk pembayaran otomatis
- Implementasi virtual account atau QRIS yang terverifikasi otomatis

---

## 3. Tracking — Polling HTTP, Bukan WebSocket

**Level: SEDANG**

**Deskripsi:**
Tracking pesanan menggunakan HTTP polling setiap 5 detik (`Timer.periodic(Duration(seconds: 5))`). Ini tidak efisien dari sisi bandwidth dan battery, serta delay maksimal 5 detik untuk update posisi.

**Lokasi Masalah:**
- `features/orders/presentation/pages/order_tracking_page.dart` → `_pollTimer = Timer.periodic(const Duration(seconds: 5), ...)`

**Solusi:**
- Implementasi WebSocket atau Server-Sent Events (SSE) untuk real-time updates
- Atau gunakan Firebase Realtime Database untuk lokasi provider

---

## 4. Provider List — Sorting Jarak Tidak Konsisten

**Level: RENDAH**

**Deskripsi:**
Sorting jarak di `ProviderListScreen` menggunakan dua pass `sort()` yang kedua bisa mengoverride yang pertama. Jika provider tidak punya koordinat, mereka ditempatkan di akhir tapi bisa tersortir ulang oleh pass kedua.

**Lokasi Masalah:**
- `features/customer/presentation/screens/customer_provider_list.dart` → `_fetchProviderList()`

**Solusi:**
- Gabungkan kedua pass sorting menjadi satu dengan comparator yang benar
- Handle null koordinat secara eksplisit dalam satu comparator

---

## 5. FCM Token — Re-registration Setiap Init

**Level: RENDAH**

**Deskripsi:**
`CustomerShell` melakukan re-register FCM token setiap kali statefulWidget diinisialisasi. Jika user navigasi bolak-balik, ini akan membuat banyak request yang tidak perlu.

**Lokasi Masalah:**
- `features/customer/presentation/screens/customer_shell.dart` → `_reRegisterFcm()`

**Solusi:**
- Tambahkan flag atau cek apakah token sudah ter-register (bandingkan dengan token tersimpan)
- Atau gunakan SharedPreferences untuk menyimpan last-registered token

---

## 6. Review — Tidak Ada Mekanisme Edit/Hapus

**Level: RENDAH**

**Deskripsi:**
Customer tidak dapat mengedit atau menghapus review yang sudah dikirim. Jika salah rating atau typo, satu-satunya cara adalah menghubungi admin.

**Lokasi Masalah:**
- `features/orders/presentation/pages/review_bottom_sheet.dart`

**Solusi:**
- Tambahkan tombol edit/delete review (dengan batas waktu, misal 24 jam setelah submit)

---

## 7. Order Form — Tidak Ada Cek Jadwal Provider Saat Submit

**Level: SEDANG**

**Deskripsi:**
Form pemesanan menampilkan warning jam operasional, tapi tidak melakukan pengecekan jadwal provider di sisi client saat submit. Jika provider sudah dibooking di tanggal yang sama, error akan muncul dari backend setelah submit.

**Lokasi Masalah:**
- `features/customer/presentation/screens/customer_orders.dart`

**Solusi:**
- Fetch jadwal provider saat tanggal dipilih
- Disable tanggal yang sudah dibooking di date picker
- Atau tampilkan warning jika tanggal sudah ada booking

---

## 8. Network Error — Tidak Ada Retry Logic

**Level: SEDANG**

**Deskripsi:**
Kebanyakan API call tidak memiliki retry logic. Jika jaringan putus sesaat, request gagal dan user harus manual refresh. Beberapa tempat ada `RefreshIndicator` tapi banyak yang tidak.

**Lokasi Masalah:**
- Seluruh file yang menggunakan `ApiClient().dio`

**Solusi:**
- Tambahkan `RetryInterceptor` pada Dio
- Atau implementasi retry manual dengan exponential backoff untuk request kritis

---

## 9. Image Upload — Tidak Ada Validasi Ukuran File

**Level: RENDAH**

**Deskripsi:**
Upload foto (order, custom task, payment proof, avatar) hanya membatasi jumlah foto (max 5) dan kompresi quality (70%), tapi tidak memvalidasi ukuran file maksimal. File yang sangat besar bisa menyebabkan timeout.

**Lokasi Masalah:**
- `features/customer/presentation/screens/customer_orders.dart` → `_pickImage()`
- `features/custom_tasks/presentation/pages/customer_create_task_page.dart` → `_pickImage()`
- `features/payments/presentation/screens/payment_instruction_screen.dart` → `_pickProof()`

**Solusi:**
- Tambahkan validasi ukuran file (misal max 5MB per foto)
- Tampilkan pesan error jika file terlalu besar

---

## 10. Customer Home — FutureBuilder Tanpa Error Handling yang Konsisten

**Level: RENDAH**

**Deskripsi:**
Grid kategori di Beranda menggunakan `FutureBuilder` tanpa `errorBuilder` yang robust. Jika API gagal, grid kosong tanpa pesan error yang jelas.

**Lokasi Masalah:**
- `features/customer/presentation/screens/customer_home.dart` → `_buildServiceGrid()`

**Solusi:**
- Tambahkan error state di FutureBuilder
- Tampilkan pesan "Gagal memuat kategori" dengan tombol retry

---

## Ringkasan Level Risiko

| Level | Jumlah | Keterangan |
|---|---|---|
| TINGGI | 1 | Timezone issue — berdampak pada validasi jam operasional |
| SEDANG | 4 | Custom task payment manual, polling tracking, cek jadwal, retry logic |
| RENDAH | 5 | Sorting provider, FCM re-register, review edit, image validation, error handling |

## Prioritas Perbaikan

1. **[TINGGI]** Perbaiki timezone: gunakan WITA secara eksplisit di `OperatingHours`
2. **[SEDANG]** Tambahkan retry logic untuk API call kritis
3. **[SEDANG]** Cek jadwal provider di client saat pilih tanggal order
4. **[SEDANG]** Evaluasi kebutuhan WebSocket untuk tracking
5. **[SEDANG]** Evaluasi payment gateway untuk custom task
6. **[RENDAH]** Perbaiki sorting provider list
7. **[RENDAH]** Kurangi FCM re-registration
8. **[RENDAH]** Tambahkan validasi ukuran file upload
9. **[RENDAH]** Tambahkan error handling di FutureBuilder
10. **[RENDAH]** Tambahkan mekanisme edit/delete review
