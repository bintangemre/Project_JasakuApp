# Rencana Implementasi — Order Flow Rules (7 Aturan)

## Latar Belakang

Proyek Jasaku memiliki 7 aturan bisnis terkait order flow yang perlu diimplementasikan. Berikut hasil validasi kode saat ini dan rencana implementasi untuk aturan yang belum ada.

---

## Ringkasan Status

| Aturan | Status | Prioritas |
|--------|--------|-----------|
| #1 — Eksekusi Order Hari Ini | ✅ Sudah (minor gap) | — |
| #2 — Multi-Ordering (Konkurensi Provider) | ⚠️ Gap di `createOrder` | Tinggi |
| #3 — Booking Masa Depan | ✅ Sudah (minor) | — |
| #4 — Jam Operasional 08:00-16:00 WITA | ❌ Belum ada | **Tertinggi** |
| #5 — Visibilitas Tombol Eksekusi | ❌ Belum ada | Tinggi |
| #6 — Ekstensi Dilarang jika Ada Order Masa Depan | ❌ Belum ada | Sedang |
| #7 — Tombol Selesai + Jam Operasional | ❌ Belum ada | Sedang |

---

## Detail Implementasi

### Fase 1: Utility Jam Operasional (Backend)

**Target:** `src/utils/operating-hours.ts` (file baru)

Konsep: Jam operasional **fixed** untuk semua provider: 08:00-16:00 WITA.
- Toleransi klik "Selesai" sampai 16:59.
- Order cutoff: 15:00 (setelah itu tidak bisa order untuk hari ini).
- Warning mepet: 14:30-15:00.

```typescript
// operating-hours.ts
const OP_START = 8;      // 08:00
const OP_END = 17;       // 17:00 (toleransi 16:59)
const ORDER_CUTOFF = 15; // 15:00 — batas order hari ini
const WARNING_START = 14.5; // 14:30

function getWitaTime(): { hour: number; minute: number } {
  const now = new Date();
  // Konversi ke WITA (UTC+8)
  // bisa pake Intl.DateTimeFormat atau offset manual
  const wita = new Date(now.getTime() + 8 * 60 * 60 * 1000);
  return { hour: wita.getUTCHours(), minute: wita.getUTCMinutes() };
}

function isWithinOperatingHours(): boolean {
  const { hour, minute } = getWitaTime();
  const totalMinutes = hour * 60 + minute;
  return totalMinutes >= OP_START * 60 && totalMinutes < OP_END * 60;
}

function canCompleteOrder(): boolean {
  const { hour, minute } = getWitaTime();
  const totalMinutes = hour * 60 + minute;
  return totalMinutes >= OP_START * 60 && totalMinutes < OP_END * 60;
}

function canOrderNow(): { allowed: boolean; reason?: string } {
  const { hour, minute } = getWitaTime();
  const totalMinutes = hour * 60 + minute;
  if (totalMinutes < OP_START * 60) {
    return { allowed: false, reason: "Belum jam operasional (08:00-16:00 WITA)" };
  }
  if (totalMinutes > ORDER_CUTOFF * 60) {
    return { allowed: false, reason: "Sudah lewat jam operasional, silahkan order besok" };
  }
  if (totalMinutes >= WARNING_START * 60) {
    return { allowed: true, reason: "Waktu mepet, sarankan order besok" };
  }
  return { allowed: true };
}

function isSameDay(date: Date): boolean {
  const now = new Date();
  // Bandingkan tanggal dalam lokal WITA
  // ...
}
```

---

### Fase 2: Validasi createOrder (Backend)

**Target:** `src/modules/orders/orders.service.ts` — `createOrder()`

**Perubahan:**

1. **Fix multi-order gap (#2)** — Tambah query cek active order langsung di tabel `orders`:
```typescript
// Setelah provider ditemukan, sebelum masuk transaction
const existingActiveOrder = await prisma.orders.findFirst({
  where: {
    provider_id: providerProfile.id,
    work_date: parsedDate,
    status: { in: ['pending', 'pending_payment', 'accepted', 'on_the_way', 'arrived', 'in_progress'] }
  }
});
if (existingActiveOrder) {
  throw new Error("Provider sudah memiliki pesanan di tanggal ini, tidak bisa dipesan lagi");
}
```

2. **Validasi jam operasional (#4)** — Jika `workDate == hari ini`:
```typescript
if (isSameDay(parsedDate)) {
  const orderCheck = canOrderNow();
  if (!orderCheck.allowed) {
    throw new Error(orderCheck.reason);
  }
  // Jika warning mepet, return warning di response
}
```

---

### Fase 3: Validasi receiveOrderStatus (Backend)

**Target:** `src/modules/orders/orders.service.ts` — `receiveOrderStatus()`

**Perubahan:**

1. **Setiap status transition cek jam operasional** — Kecuali `rejected` dan `cancelled`:
```typescript
// Di awal fungsi, setelah validasi ownership
if (['on_the_way', 'arrived', 'in_progress', 'completed'].includes(status)) {
  if (!isWithinOperatingHours()) {
    throw new Error("Di luar jam operasional (08:00-16:00 WITA)");
  }
}

// Khusus 'completed' — toleransi sampai 16:59:
if (status === 'completed') {
  if (!canCompleteOrder()) {
    throw new Error("Sudah lewat jam operasional. Batas konfirmasi selesai pukul 16:59 WITA");
  }
}
```

2. **Saat `completed`**:
- Set `provider_schedules.is_booked = false` untuk tanggal tersebut (sudah ada)
- Set `end_date = new Date()` (waktu selesai aktual, bukan `work_date + extension_days` lagi)
- Increment `total_jobs` (sudah ada)

---

### Fase 4: Validasi requestExtension (Backend)

**Target:** `src/modules/orders/orders.service.ts` — `requestExtension()`

**Perubahan (#6):**

```typescript
// Setelah validasi order status, cek apakah provider punya order di masa depan
const futureOrder = await prisma.orders.findFirst({
  where: {
    provider_id: profile.id,
    work_date: {
      gt: new Date()  // Besok atau setelahnya
    },
    status: { notIn: ['completed', 'cancelled', 'rejected'] },
    NOT: { id: orderId }
  }
});
if (futureOrder) {
  throw new Error(
    "Anda memiliki orderan untuk hari berikutnya. " +
    "Tidak bisa mengajukan tambahan waktu. " +
    "Selesaikan order hari ini dan buat order baru nanti."
  );
}
```

---

### Fase 5: Backend — API Order dengan Scope

**Target:** `src/modules/orders/orders.service.ts` — `getProviderOrders()`

**Perubahan (#5):**

Tambah parameter `scope?: 'today' | 'upcoming' | 'history'`:

```typescript
async getProviderOrders(userId: string, statusFilter?: string, scope?: string) {
  // ...
  if (scope === 'today') {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);
    whereClause.work_date = { gte: today, lt: tomorrow };
  } else if (scope === 'upcoming') {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    whereClause.work_date = { gt: today };
  } else if (scope === 'history') {
    whereClause.status = 'completed';
  }
  // ...
}
```

**Route baru / ubah:** `GET /provider/orders?scope=today&status=...`

---

### Fase 6: Flutter — Provider Dashboard

**Target:** `provider_dashboard.dart` + `provider_dashboard_provider.dart`

**Perubahan:**

**6A. Filter activeOrder by today (#5)**

`provider_dashboard_provider.dart`:
```dart
// Ubah getter activeOrder
Map<String, dynamic>? get activeOrder {
  try {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);
    return orders.firstWhere(
      (o) {
        final isActive = ['accepted', 'on_the_way', 'arrived', 'in_progress'].contains(o['status']);
        final isToday = o['work_date'] == todayStr;
        return isActive && isToday;
      },
    );
  } catch (_) {
    return null;
  }
}
```

**6B. Halaman Manajemen Orderan (#5)**

Buat halaman baru atau ganti navigasi "Riwayat" menjadi "Manajemen Orderan" dengan 3 tab:

1. **Tab "Hari Ini"** — Order dengan `work_date == today`, status aktif.
   - Tampilkan tombol eksekusi (Berangkat, Tiba, Mulai, Selesai) sesuai status.
   - Map dengan lokasi (seperti dashboard saat ini).
   - Tampilkan peringatan jika di luar jam operasional.

2. **Tab "Akan Datang"** — Order dengan `work_date > today`.
   - Tampilkan daftar order.
   - **Tanpa** tombol eksekusi.
   - **Tanpa** map/lokasi.
   - Hanya info: jadwal, customer, alamat (teks saja).

3. **Tab "Riwayat"** — Order dengan `status == completed`.
   - Sama seperti riwayat yang sudah ada.

**6C. Cek jam operasional untuk tombol**

Di dalam jam operasional (08:00-16:59):
- Tombol normal, bisa diklik.

Di luar jam operasional:
- Tombol disabled, text "Di luar jam operasional".
- Atau tombol hilang dan tampilkan banner saja.

---

### Fase 7: Flutter — Customer View

**Target:** `customer_provider_list.dart` + `customer_orders.dart`

**Perubahan (#4):**

**7A. Peringatan di profil provider**

Di `DetailProviderSheet`, setelah status active order, tambah:

```dart
// Cek jam operasional
if (!_isWithinOperatingHours) ...[
  Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Color(0xFFFEFCE8),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Color(0xFFFDE68A)),
    ),
    child: const Row(
      children: [
        Icon(Icons.access_time, color: Color(0xFFCA8A04), size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Anda sedang di luar jam operasional (08:00-16:00 WITA), '
            'silakan cek jadwal penyedia jasa',
            style: TextStyle(color: Color(0xFF92400E), fontSize: 13),
          ),
        ),
      ],
    ),
  ),
]
```

**7B. Peringatan waktu mepet (14:30-15:00)**

Di halaman order (`customer_orders.dart`), saat pilih tanggal hari ini:

```dart
if (_isWithinWarningWindow) ...[
  Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Color(0xFFFFF7ED),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Color(0xFFFFD6A8)),
    ),
    child: const Text(
      'Waktu pemesanan mepet dengan jam operasional berakhir. '
      'Sarankan order besok pagi jam 08:00 atau lihat jadwal mitra.',
      style: TextStyle(fontSize: 12, color: Color(0xFF9C6B3E)),
    ),
  ),
]
```

---

### Fase 8: Flutter — Extension Button Logic

**Target:** `provider_dashboard.dart`

**Perubahan (#6):**

Tombol "Minta Perpanjangan" — panggil backend, handle error:

```dart
try {
  await _dio.post(ApiEndpoints.requestExtension(orderId), data: {'additionalDays': days});
  toast('Permintaan ekstensi dikirim');
} on DioException catch (e) {
  final msg = e.response?.data?['message'] ?? e.message;
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Tidak Bisa Ekstensi'),
      content: Text(msg),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup'))],
    ),
  );
}
```

---

### Fase 9: Flutter — Tracking Page

**Target:** `order_tracking_page.dart`

**Perubahan (opsional):**

Tracking page tetap bisa diakses kapan saja. Tapi:
- Sebelum 08:00 — tampilkan banner "Provider akan bekerja mulai jam 08:00".
- Setelah 16:00 — tampilkan banner "Jam operasional telah berakhir".

---

## Daftar File yang Akan Diubah

### Backend
| File | Perubahan |
|------|-----------|
| `src/utils/operating-hours.ts` | **BARU** — Utility jam operasional |
| `src/modules/orders/orders.service.ts` | `createOrder()` — validasi jam + fix multi-order; `receiveOrderStatus()` — cek jam; `requestExtension()` — cek future order; `getProviderOrders()` — tambah scope param |
| `src/modules/orders/orders.routes.ts` | Ubah/sesuaikan route |

### Flutter
| File | Perubahan |
|------|-----------|
| `lib/features/provider/presentation/providers/provider_dashboard_provider.dart` | Filter `activeOrder` by date |
| `lib/features/provider/presentation/screens/provider_dashboard.dart` | Cek jam operasional untuk tombol, ubah navigasi riwayat |
| `lib/features/provider/presentation/screens/provider_order_management_page.dart` | **BARU** — Halaman Manajemen Orderan (3 tab) |
| `lib/features/customer/presentation/screens/customer_provider_list.dart` | Peringatan jam operasional di profil provider |
| `lib/features/customer/presentation/screens/customer_orders.dart` | Peringatan waktu mepet |
| `lib/features/orders/presentation/pages/order_tracking_page.dart` | Banner jam operasional |
| `lib/features/provider/presentation/screens/provider_shell.dart` | Navigasi ke halaman manajemen orderan |
| `lib/core/utils/operating_hours.dart` | **BARU** — Utility jam operasional Flutter |

---

## Catatan Penting

1. **WITA fixed** — Semua perhitungan jam menggunakan WITA (UTC+8). Server laptop dan HP ada di WITA.
2. **Toleransi 16:59** — Provider bisa klik "Selesai" sampai 16:59, bukan 16:00.
3. **Order cutoff 15:00** — Setelah jam 15:00, customer tidak bisa order untuk hari ini.
4. **Warning 14:30-15:00** — Customer masih boleh order tapi dikasih peringatan.
5. **Future booking tetap lepas** — Customer tetap bisa order untuk H+1 kapan saja, tanpa batasan jam.
6. **Pengecekan jam di backend** — Jangan hanya di Flutter, backend juga harus validasi untuk keamanan.
