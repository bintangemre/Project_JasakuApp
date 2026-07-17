# 13 — Ringkasan Potensi Error

## Deskripsi

Dokumen ini merangkum semua potensi error dan masalah yang ditemukan di aplikasi Mitra Jasaku (Provider), beserta analisis dampak dan solusi yang disarankan.

---

## 1. Operating Hours Check Tidak Konsisten

### Lokasi
- `provider_dashboard.dart` — tombol aksi di kartu pekerjaan aktif ✅ dicek
- `provider_order_detail_page.dart` — tombol aksi di detail order ✅ dicek
- `provider_order_management_page.dart` — tombol aksi di tab Hari Ini ✅ dicek

### Masalah
Pengecekan jam operasional (08:00–16:00 WITA) hanya dilakukan di:
- Dashboard (provider_dashboard.dart)
- Detail order (provider_order_detail_page.dart)
- Manajemen orderan tab Hari Ini (provider_order_management_page.dart)

**Tetapi TIDAK dicek di:**
- Custom task buttons di dashboard (provider_dashboard.dart — tombol custom task status)
- Direct API calls dari lokasi lain yang bisa memicu status update

### Dampak
Provider bisa meng-update status custom task di luar jam operasional karena tombol custom task **selalu aktif** tanpa operating hours gate.

### Solusi
Tambahkan `OperatingHours.isWithinOperatingHours()` check di tombol custom task status update, atau pindahkan validasi ke backend (recommended).

---

## 2. Location Tracking Battery Drain

### Lokasi
- `location_tracker_provider.dart`

### Masalah
- GPS stream aktif terus dengan `LocationAccuracy.high` dan `distanceFilter: 10`
- Timer 30 detik mengirim lokasi ke server meskipun tidak ada pekerjaan aktif
- Tidak ada mekanisme adaptive interval (lebih jarang saat idle)

### Dampak
- Baterai HP provider cepat habis, terutama jika digunakan sepanjang hari
- Provider mungkin menonaktifkan GPS untuk menghemat baterai → tracking berhenti
- Data lokasi tidak akurat jika GPS dimatikan

### Solusi
1. Gunakan `LocationAccuracy.medium` saat tidak ada pekerjaan aktif
2. Implementasi adaptive interval: 10 detik saat on_the_way, 60 detik saat idle
3. Kirim lokasi hanya jika ada order aktif (accepted/on_the_way/arrived/in_progress)
4. Tambahkan tombol manual "Mulai Tracking" / "Stop Tracking"

---

## 3. Countdown Timer 5 Menit Tidak Real-Time

### Lokasi
- `provider_requests_page.dart`

### Masalah
Timer countdown pada permintaan masuk dihitung dari waktu `created_at` + 5 menit. Visual countdown **hanya di-update setiap 30 detik** (saat `_refreshTimer` fires), bukan per detik.

```dart
// Timer hanya refresh data setiap 30 detik
_refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchRequests());
```

### Dampak
- User melihat waktu yang "lompat" setiap 30 detik, bukan countdown real-time
- Mungkin terlihat masih ada waktu padahal sebenarnya sudah habis (sebaliknya juga)
- UX kurang intuitif — user tidak menyadari bahwa waktu tersisa sudah habis

### Solusi
1. Tambahkan `Timer.periodic(Duration(seconds: 1))` terpisah untuk update visual countdown
2. Atau: fetch ulang data saat countdown mendekati 0
3. Backend sudah melakukan auto-cancel setelah 5 menit, jadi ini hanya masalah UX

---

## 4. Custom Task Multi-Provider Complexity

### Lokasi
- `custom_tasks_repository.dart`
- `provider_available_tasks_page.dart`
- `provider_my_bids_page.dart`

### Masalah
- Satu custom task bisa membutuhkan beberapa provider (`required_people`)
- Tidak ada mekanisme locking — beberapa provider bisa menerima task bersamaan
- Status `CUSTOM_TASK_FULL` dikirim ketika task sudah penuh, tapi race condition mungkin terjadi
- Pembayaran custom task dilakukan manual (transfer bank), belum terintegrasi otomatis

### Dampak
- Dua provider bisa mengambil task yang sama secara bersamaan
- Customer harus membayar beberapa provider secara manual
- Tidak ada escrow/rekber otomatis untuk custom task

### Solusi
1. Implementasi optimistic locking di backend (cek slot tersedia sebelum accept)
2. Integrasi payment gateway untuk custom task
3. Tambahkan fitur split payment untuk multi-provider task

---

## 5. Timezone Bergantung pada Device

### Lokasi
- `core/utils/operating_hours.dart`

### Masalah
Pengecekan jam operasional menggunakan `DateTime.now()` yang mengikuti timezone device:

```dart
static bool isWithinOperatingHours() {
  final now = DateTime.now();  // Mengikuti timezone device
  final total = _totalMinutes(now.hour, now.minute);
  return total >= _totalMinutes(startHour, startMinute) &&
         total < _totalMinutes(endHour, endMinute);
}
```

### Dampak
- Jika HP provider di-setting ke timezone selain WITA (UTC+8), pengecekan jam operasional akan salah
- Provider di luar WITA (misal: WIB, WIT) tidak akan bisa meng-update status meskipun seharusnya bisa
- Order cutoff (15:59) juga akan salah jika timezone device tidak benar

### Solusi
1. Gunakan timezone WITA secara eksplisit: `DateTime.now().toUtc().add(Duration(hours: 8))`
2. Atau gunakan package `timezone` untuk konversi yang akurat
3. Tambahkan setting timezone di profil provider (opsional)

---

## 6. Error Handling Network yang Tidak Spesifik

### Lokasi
- Semua halaman yang melakukan API call

### Masalah
Banyak error handler hanya menampilkan `e.toString()` tanpa pesan yang user-friendly:

```dart
catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
  );
}
```

### Dampak
- User melihat error teknis (misal: "DioException [403]: ...") yang tidak dipahami
- Tidak ada pembedaan antara error network, error server, dan error validasi

### Solusi
1. Buat centralized error handler yang memetakan error ke pesan user-friendly
2. Tangani secara spesifik: timeout, no connection, 401 (token expired), 403, 404, 500
3. Untuk 401 → auto-redirect ke login

---

## 7. State Management Tidak Konsisten

### Lokasi
- `provider_shell.dart` — state lokal + Riverpod
- `provider_dashboard.dart` — state lokal + Riverpod
- `provider_requests_page.dart` — state lokal
- `provider_order_management_page.dart` — state lokal

### Masalah
- Beberapa halaman menggunakan Riverpod (`dashboardProvider`, `profileProvider`)
- Beberapa halaman menggunakan state lokal (`_requests`, `_orders`)
- Tidak ada konsistensi dalam approach state management
- Data bisa tidak sinkron antar halaman

### Dampak
- Perubahan di satu halaman mungkin tidak terlihat di halaman lain
- Pull-to-refresh diperlukan di setiap halaman secara manual
- Memory leak potential dari Timer yang tidak di-cancel dengan benar

### Solusi
1. Standarisasi ke Riverpod untuk semua state
2. Gunakan `family` provider untuk data spesifik
3. Implementasi shared state untuk data yang sering diakses

---

## 8. Upload File Tanpa Batas Ukuran

### Lokasi
- `provider_register_screen.dart`
- `provider_profile_edit_screen.dart`

### Masalah
- Upload foto profil, KTP, selfie, portofolio, ijazah, sertifikat tidak memiliki validasi ukuran file maksimum di client-side
- Hanya kompresi `image_quality: 70` yang diterapkan
- Tidak ada retry mechanism untuk upload yang gagal

### Dampak
- File berukuran besar bisa menyebabkan timeout atau out-of-memory
- Upload multi-file (registrasi) bisa memakan waktu sangat lama di jaringan lambat

### Solusi
1. Tambahkan validasi ukuran file maksimum (misal: 5MB per file)
2. Implementasi retry mechanism dengan exponential backoff
3. Tambahkan progress indicator untuk upload
4. Kompresi lebih aggressive jika ukuran melebihi batas

---

## Ringkasan Level Risiko

| Fitur | Level | Alasan Utama |
|---|---|---|
| Autentikasi & Verifikasi | SEDANG | OCR & face match belum tentu akurat |
| Dashboard | SUKSES | Berfungsi dengan baik |
| Manajemen Pesanan | SUKSES | Berfungsi dengan baik |
| Permintaan Masuk | SUKSES | Berfungsi dengan baik |
| Riwayat Pesanan | SUKSES | Berfungsi dengan baik |
| Perpanjangan Waktu | SUKSES | Berfungsi dengan baik |
| Profil & Layanan | SUKSES | Berfungsi dengan baik |
| Metode Pencairan | SUKSES | Berfungsi dengan baik |
| Custom Task | SEDANG | Multi-provider flow, payment manual |
| Lokasi & Tracking | RENDAH | GPS accuracy, battery drain |
| Notifikasi | SUKSES | Berfungsi dengan baik |
| Laporan | SUKSES | Berfungsi dengan baik |
| Operating Hours Gate | RENDAH | Tidak konsisten di semua path |
| Timezone | RENDAH | Bergantung pada device setting |
