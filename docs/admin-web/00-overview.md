# Overview — Admin Web Panel Jasaku

## Deskripsi

Admin Web Panel adalah SPA (Single Page Application) berbasis browser yang digunakan oleh admin Jasaku untuk mengelola seluruh operasional platform: mulai dari konfirmasi pembayaran, pencairan dana, verifikasi mitra, manajemen konten, hingga penanganan laporan.

Panel ini dijalankan sebagai statis file yang dilayani oleh Express server di path `/admin` (`jasaku-backend/public/admin/`).

## Tech Stack

| Komponen | Teknologi | Keterangan |
|---|---|---|
| Frontend Framework | Alpine.js 3.x (CDN) | Reactive UI tanpa build step |
| CSS Framework | Tailwind CSS (CDN via `cdn.tailwindcss.com`) | Utility-first CSS |
| Icons | Font Awesome 6.5.1 (CDN) | Ikon konsisten di seluruh UI |
| Backend API | Express 5 + TypeScript | REST API dengan JWT auth |
| ORM | Prisma 7 | Akses database PostgreSQL (Supabase) |
| File Storage | Supabase Storage | Upload bukti bayar, QRIS, dokumen |

**Tidak ada build step.** Semua file JS/CSS di-import langsung via CDN. File `app.js` dan `app.css` adalah vanilla JS/CSS custom.

## Struktur File

```
jasaku-backend/public/admin/
├── index.html    — Seluruh markup HTML (SPA, ~1513 baris)
├── app.js        — Logic Alpine.js components & utilities (~385 baris)
└── app.css       — Custom CSS + dark mode rules (~461 baris)
```

## Autentikasi

### Flow Login

1. Admin membuka `/admin` → halaman login ditampilkan
2. Admin memasukkan email + password
3. Frontend mengirim `POST /api/auth/login` dengan body `{ email, password }`
4. Server mengembalikan `{ success: true, data: { token, user } }`
5. Token disimpan di `localStorage` dengan key `admin_token`
6. Data user disimpan di `localStorage` dengan key `admin_user`
7. Redirect ke halaman Dashboard (`#dashboard`)

### Autentikasi Request API

Setiap request ke API (kecuali login) disertai header:
```
Authorization: Bearer <admin_token>
```

Fungsi `apiFetch()` di `app.js:23-44` otomatis menambahkan header ini. Jika server mengembalikan `401 Unauthorized`, token dihapus dan admin di-redirect ke halaman login.

### Logout

Logout menghapus `admin_token` dan `admin_user` dari `localStorage`, lalu redirect ke halaman login.

## Sidebar Menu

Sidebar memiliki **12 item** yang dikelompokkan dalam **5 grup header**:

| # | Grup Header | ID Menu | Label | Ikon | Badge |
|---|---|---|---|---|---|
| 1 | Utama | `dashboard` | Beranda | `fa-chart-pie` | — |
| 2 | Transaksi | `confirm-payment` | Konfirmasi Bayar | `fa-hand-holding-usd` | `pendingPayments` |
| 3 | Transaksi | `order-payout` | Pencairan Dana | `fa-money-bill-wave` | `pendingOrderPayouts` |
| 4 | Transaksi | `confirm-extension` | Konfirmasi Ekstensi | `fa-calendar-plus` | `pendingExtensions` |
| 5 | Transaksi | `custom-tasks` | Custom Task | `fa-tasks` | `pendingTaskPayments` |
| 6 | Manajemen | `providers` | Mitra | `fa-hard-hat` | `pendingProviders` |
| 7 | Manajemen | `customers` | Pelanggan | `fa-users` | — |
| 8 | Konten | `categories` | Kategori | `fa-tags` | — |
| 9 | Konten | `services` | Layanan | `fa-tools` | — |
| 10 | Konten | `payments` | Pembayaran | `fa-credit-card` | — |
| 11 | Konten | `pricing-types` | Tipe Harga | `fa-dollar-sign` | — |
| 12 | Lainnya | `reports` | Laporan | `fa-flag` | `openReports` |

### Behavior Sidebar

- **Desktop**: Sidebar visible di kiri, bisa di-collapse (lebar 68px) atau expanded (lebar 256px). Tombol collapse/expand di bagian bawah sidebar.
- **Mobile**: Sidebar disembunyikan, diakses via hamburger menu di top bar. Overlay transparan backdrop saat sidebar terbuka.
- **Active state**: Menu aktif ditandai dengan background putih + shadow + warna text indigo.
- **Header group**: Label grup (seperti "Utama", "Transaksi") ditampilkan di atas item pertama setiap grup, dengan style uppercase + tracking-widest + warna redup.

## Sistem Badge Notifikasi

Badge notifikasi menampilkan jumlah item yang menunggu tindakan admin. Badge muncul di dua tempat:

1. **Sidebar menu**: Badge merah kecil di sisi kanan menu item
2. **Bell icon (top bar)**: Badge total di pojok kanan atas ikon lonceng

### Data yang ditampilkan

Badge dihitung oleh endpoint `GET /api/admin/notifications/counts` dan mengembalikan:

| Key | Keterangan |
|---|---|
| `pendingPayments` | Order reguler dengan status `pending_payment` |
| `pendingExtensions` | Ekstensi dengan status `pending_payment` |
| `pendingTaskPayments` | Custom task order dengan status `pending_payment` |
| `pendingTaskPayouts` | Custom task yang completed tapi payout belum dikonfirmasi |
| `pendingOrderPayouts` | Order reguler yang completed tapi payout belum dikonfirmasi |
| `pendingProviders` | Mitra dengan `verification_status = pending` |
| `openReports` | Laporan dengan `status = open` |
| `total` | Jumlah seluruh badge (kecuali `pendingTaskPayouts`) |

### Auto-refresh

Badge di-polling setiap **15 detik** via `setInterval`. Polling dimulai saat admin login dan dihentikan saat logout.

### Dropdown Notifikasi

Klik ikon bell membuka dropdown yang menampilkan daftar item menunggu tindakan. Setiap item bisa diklik untuk langsung navigate ke halaman terkait. Jika semua sudah ditindak, dropdown menampilkan pesan "Semua sudah ditindak".

## Dark Mode

- Toggle dark mode ada di bagian bawah sidebar (ikon bulan/matahari)
- Preference disimpan di `localStorage` dengan key `dark`
- Pada load pertama, mendeteksi `prefers-color-scheme: dark` dari OS
- Dark mode diterapkan dengan menambahkan class `dark` pada `<html>`
- Seluruh komponen UI (cards, tables, forms, badges, modals) memiliki style dark mode

## Hash-Based Routing

Navigasi antar halaman menggunakan URL hash:

| URL | Halaman |
|---|---|
| `/admin#login` | Login |
| `/admin#dashboard` | Beranda/Dashboard |
| `/admin#confirm-payment` | Konfirmasi Pembayaran |
| `/admin#order-payout` | Pencairan Dana |
| `/admin#confirm-extension` | Konfirmasi Ekstensi |
| `/admin#custom-tasks` | Custom Task |
| `/admin#providers` | Mitra |
| `/admin#provider-detail` | Detail Mitra |
| `/admin#customers` | Pelanggan |
| `/admin#categories` | Kategori |
| `/admin#services` | Layanan |
| `/admin#payments` | Pembayaran |
| `/admin#pricing-types` | Tipe Harga |
| `/admin#reports` | Laporan |

Fungsi `navigate(page)` di `app.js:8-11` mengatur `window.location.hash` dan `Alpine.store('nav').page`. Pada load, hash dibaca untuk menentukan halaman awal.

## Modal System

Admin panel menggunakan beberapa modal:

| Modal | Fungsi |
|---|---|
| Confirm Modal | Konfirmasi aksi hapus/danger dengan tombol Batal/Ya |
| Prompt Modal | Input textarea untuk catatan (opsional) |
| Category Modal | Form tambah/edit kategori |
| Service Modal | Form tambah/edit layanan |
| Payment Modal | Form tambah/edit rekening + upload QRIS |
| QRIS Modal | Preview gambar QRIS |
| Proof Modal | Preview bukti pembayaran |
| Pricing Modal | Form tambah tipe harga |
| Report Modal | Form tanggapi laporan |
| Verification Checklist Modal | Checklist verifikasi mitra saat penolakan |

## Responsive Design

- **Desktop (>=768px)**: Layout sidebar + content, tabel horizontal scroll
- **Mobile (<768px)**: Sidebar overlay, tabel full-width dengan negative margin

## Status: (SUKSES)

Panel berfungsi dengan baik. Seluruh fitur utama sudah terimplementasi dan terhubung ke backend API.

**Lokasi file:**
- `jasaku-backend/public/admin/index.html`
- `jasaku-backend/public/admin/app.js`
- `jasaku-backend/public/admin/app.css`
