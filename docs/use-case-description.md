# Deskripsi Use Case — Jasaku

Daftar use case lengkap untuk tiga aktor: **Admin**, **Customer**, dan **Mitra (Provider)**.

---

# A. Admin

## UC-ADM-01 — Login

| Item | Detail |
|---|---|
| **Use Case** | Login |
| **Aktor** | Admin |
| **Deskripsi** | Admin masuk ke sistem menggunakan email dan password yang telah terdaftar |
| **Pra Kondisi** | 1. Admin sudah memiliki akun terdaftar di sistem<br>2. Admin memiliki akses ke halaman login admin |
| **Alur** | 1. Admin membuka halaman login<br>2. Admin memasukkan email dan password<br>3. Sistem memvalidasi kredensial<br>4. Sistem menghasilkan token JWT |
| **Pasca Kondisi** | 1. Admin mendapatkan token JWT<br>2. Admin diarahkan ke halaman Dashboard |

## UC-ADM-02 — Lihat Dashboard & Metrik

| Item | Detail |
|---|---|
| **Use Case** | Lihat Dashboard & Metrik |
| **Aktor** | Admin |
| **Deskripsi** | Admin melihat gambaran umum platform termasuk jumlah pengguna, pendapatan, dan statistik pesanan |
| **Pra Kondisi** | 1. Admin sudah login<br>2. Admin berada di halaman dashboard |
| **Alur** | 1. Admin membuka halaman dashboard<br>2. Sistem mengambil data metrik dari database<br>3. Sistem menampilkan grafik dan statistik<br>4. Admin melihat ringkasan platform |
| **Pasca Kondisi** | 1. Admin melihat data metrik platform<br>2. Admin dapat memantau kesehatan bisnis |

## UC-ADM-03 — Verifikasi Mitra (Review KYC)

| Item | Detail |
|---|---|
| **Use Case** | Verifikasi Mitra (Review KYC) |
| **Aktor** | Admin |
| **Deskripsi** | Admin meninjau dokumen KYC mitra (KTP, selfie, ijazah, portofolio, sertifikat) serta data OCR dan liveness, kemudian menyetujui atau menolak dengan catatan |
| **Pra Kondisi** | 1. Admin sudah login<br>2. Terdapat mitra dengan status verifikasi `pending`<br>3. Dokumen KYC mitra sudah diupload |
| **Alur** | 1. Admin membuka daftar mitra pending verifikasi<br>2. Admin memilih mitra untuk direview<br>3. Admin melihat dokumen KTP, selfie, ijazah, portofolio, sertifikat<br>4. Admin memeriksa data OCR dan hasil liveness<br>5. Admin memutuskan: setujui (verified) atau tolak (rejected)<br>6. Jika ditolak, admin menulis catatan penolakan<br>7. Sistem memperbarui status verifikasi mitra |
| **Pasca Kondisi** | 1. Jika disetujui: status mitra berubah menjadi `verified`<br>2. Jika ditolak: status mitra menjadi `rejected` disertai catatan penolakan<br>3. Mitra mendapat notifikasi hasil verifikasi |

## UC-ADM-04 — Kelola Kategori

| Item | Detail |
|---|---|
| **Use Case** | Kelola Kategori |
| **Aktor** | Admin |
| **Deskripsi** | Admin membuat, melihat, mengubah, dan menghapus kategori layanan (misal: Kelistrikan, Bangunan, Kebersihan) |
| **Pra Kondisi** | 1. Admin sudah login<br>2. Admin berada di halaman manajemen kategori |
| **Alur** | 1. Admin membuka halaman kelola kategori<br>2. Admin melihat daftar kategori yang ada<br>3. Admin memilih: tambah, edit, atau hapus kategori<br>4. Sistem menyimpan perubahan ke database |
| **Pasca Kondisi** | 1. Data kategori tersimpan/berubah di database<br>2. Perubahan langsung terlihat di aplikasi Customer |

## UC-ADM-05 — Kelola Layanan & Tipe Harga

| Item | Detail |
|---|---|
| **Use Case** | Kelola Layanan & Tipe Harga |
| **Aktor** | Admin |
| **Deskripsi** | Admin mengelola layanan dan tipe harga (flat, per jam, per unit) dalam setiap kategori |
| **Pra Kondisi** | 1. Admin sudah login<br>2. Kategori layanan sudah tersedia |
| **Alur** | 1. Admin memilih kategori yang akan dikelola<br>2. Admin menambah/mengedit/menghapus layanan di kategori tersebut<br>3. Admin mengatur tipe harga yang tersedia (flat, per jam, per unit)<br>4. Sistem menyimpan perubahan ke database |
| **Pasca Kondisi** | 1. Layanan dan tipe harga tersimpan di database<br>2. Mitra dapat memilih layanan tersebut saat onboarding |

## UC-ADM-06 — Konfirmasi Pembayaran (Rekber)

| Item | Detail |
|---|---|
| **Use Case** | Konfirmasi Pembayaran (Rekber) |
| **Aktor** | Admin |
| **Deskripsi** | Admin mengonfirmasi pembayaran yang sudah ditransfer customer ke rekening escrow admin, lalu mencairkan dana ke mitra setelah pekerjaan selesai |
| **Pra Kondisi** | 1. Admin sudah login<br>2. Customer sudah melakukan transfer ke rekber admin<br>3. Terdapat pesanan dengan status menunggu konfirmasi pembayaran |
| **Alur** | 1. Admin membuka daftar pesanan menunggu konfirmasi pembayaran<br>2. Admin memverifikasi bukti transfer dari customer<br>3. Admin mengkonfirmasi pembayaran<br>4. Sistem mengubah status pembayaran menjadi `paid`<br>5. Mitra mendapat notifikasi untuk mulai bekerja<br>6. Setelah mitra selesai, admin mencairkan dana ke mitra |
| **Pasca Kondisi** | 1. Status pembayaran berubah menjadi `paid`<br>2. Mitra mendapat notifikasi untuk mulai bekerja<br>3. Setelah mitra selesai, admin mencairkan dana |

## UC-ADM-07 — Setujui / Tolak Perpanjangan

| Item | Detail |
|---|---|
| **Use Case** | Setujui / Tolak Perpanjangan |
| **Aktor** | Admin |
| **Deskripsi** | Admin menyetujui atau menolak permintaan perpanjangan waktu dari mitra untuk pesanan yang sedang berlangsung (1-3 hari tambahan) |
| **Pra Kondisi** | 1. Admin sudah login<br>2. Mitra sudah mengirim permintaan perpanjangan<br>3. Pesanan sedang dalam status `in_progress` |
| **Alur** | 1. Admin membuka daftar permintaan perpanjangan<br>2. Admin melihat detail permintaan (durasi, alasan)<br>3. Admin memutuskan setujui atau tolak<br>4. Sistem memperbarui durasi pesanan jika disetujui<br>5. Mitra mendapat notifikasi hasil keputusan |
| **Pasca Kondisi** | 1. Jika disetujui: durasi pesanan diperpanjang<br>2. Jika ditolak: mitra harus menyelesaikan sesuai waktu awal |

## UC-ADM-08 — Kelola Pengguna (Ban/Unban)

| Item | Detail |
|---|---|
| **Use Case** | Kelola Pengguna |
| **Aktor** | Admin |
| **Deskripsi** | Admin melihat daftar customer dan mitra, serta dapat memblokir (ban) atau membuka blokir (unban) akun pengguna |
| **Pra Kondisi** | 1. Admin sudah login<br>2. Pengguna target sudah terdaftar di sistem |
| **Alur** | 1. Admin membuka halaman daftar pengguna (customer/mitra)<br>2. Admin mencari pengguna target<br>3. Admin memilih ban atau unban<br>4. Sistem memperbarui status akun pengguna |
| **Pasca Kondisi** | 1. Jika diban: pengguna tidak bisa login atau menggunakan layanan<br>2. Jika diunban: akses pengguna dikembalikan |

## UC-ADM-09 — Tangani Laporan

| Item | Detail |
|---|---|
| **Use Case** | Tangani Laporan |
| **Aktor** | Admin |
| **Deskripsi** | Admin melihat laporan masuk dari pengguna (customer/mitra) dan memberikan tanggapan serta resolusi |
| **Pra Kondisi** | 1. Admin sudah login<br>2. Terdapat laporan dari pengguna yang masuk |
| **Alur** | 1. Admin membuka daftar laporan masuk<br>2. Admin memilih laporan yang akan ditangani<br>3. Admin melihat detail laporan<br>4. Admin memberikan tanggapan dan resolusi<br>5. Sistem menyimpan dan mengirim notifikasi ke pelapor |
| **Pasca Kondisi** | 1. Laporan mendapatkan status resolusi<br>2. Pengguna mendapat notifikasi tanggapan |

## UC-ADM-10 — Kelola Akun Pembayaran (Rekber)

| Item | Detail |
|---|---|
| **Use Case** | Kelola Akun Pembayaran (Rekber) |
| **Aktor** | Admin |
| **Deskripsi** | Admin mengelola akun escrow (rekber) untuk menerima pembayaran dari customer, termasuk rekening bank, e-wallet, dan upload gambar QRIS |
| **Pra Kondisi** | 1. Admin sudah login<br>2. Admin memiliki data akun pembayaran yang valid |
| **Alur** | 1. Admin membuka halaman kelola akun pembayaran<br>2. Admin menambah/mengedit/menghapus akun pembayaran<br>3. Admin mengisi detail bank/e-wallet atau upload QRIS<br>4. Sistem menyimpan perubahan ke database |
| **Pasca Kondisi** | 1. Akun pembayaran tersimpan/berubah di database<br>2. Akun baru muncul sebagai pilihan pembayaran customer |

## UC-ADM-11 — Konfirmasi Pembayaran Custom Task

| Item | Detail |
|---|---|
| **Use Case** | Konfirmasi Pembayaran Custom Task |
| **Aktor** | Admin |
| **Deskripsi** | Admin mengonfirmasi pembayaran customer untuk custom task, lalu mencairkan dana ke mitra setelah task selesai dikerjakan |
| **Pra Kondisi** | 1. Admin sudah login<br>2. Customer sudah membayar untuk custom task<br>3. Mitra sudah menyelesaikan task |
| **Alur** | 1. Admin membuka daftar custom task menunggu konfirmasi<br>2. Admin mengonfirmasi pembayaran customer<br>3. Task tersedia untuk diambil mitra<br>4. Mitra menyelesaikan task dan menandai selesai<br>5. Admin mengonfirmasi payout ke mitra |
| **Pasca Kondisi** | 1. Pembayaran customer terkonfirmasi<br>2. Mitra menerima pencairan dana<br>3. Task dianggap selesai |

## UC-ADM-12 — Kirim Notifikasi Push

| Item | Detail |
|---|---|
| **Use Case** | Kirim Notifikasi Push |
| **Aktor** | Admin |
| **Deskripsi** | Admin mengirim notifikasi push ke perangkat pengguna tertentu (customer atau mitra) melalui Firebase Cloud Messaging |
| **Pra Kondisi** | 1. Admin sudah login<br>2. Pengguna target sudah mendaftarkan FCM token perangkat<br>3. Firebase Admin SDK terkonfigurasi |
| **Alur** | 1. Admin memilih pengguna target<br>2. Admin menulis judul dan isi notifikasi<br>3. Sistem mengirim notifikasi via FCM<br>4. Pengguna menerima notifikasi di perangkat |
| **Pasca Kondisi** | 1. Pengguna menerima notifikasi di perangkatnya<br>2. Notifikasi dapat mengarahkan pengguna ke halaman tertentu |

---

# B. Customer

## UC-CST-01 — Daftar Akun

| Item | Detail |
|---|---|
| **Use Case** | Daftar Akun |
| **Aktor** | Customer |
| **Deskripsi** | Customer membuat akun baru dengan mengisi email, password, nama, nomor telepon, jenis kelamin, dan tanggal lahir |
| **Pra Kondisi** | 1. Customer belum memiliki akun<br>2. Customer membuka halaman registrasi |
| **Alur** | 1. Customer membuka halaman register<br>2. Customer mengisi formulir data diri<br>3. Customer menekan tombol daftar<br>4. Sistem memvalidasi data & membuat akun<br>5. Sistem langsung login dan memberikan token JWT |
| **Pasca Kondisi** | 1. Akun customer tersimpan di database<br>2. Customer langsung login dan mendapat token JWT<br>3. Customer diarahkan ke halaman utama |

## UC-CST-02 — Login (Email / Google)

| Item | Detail |
|---|---|
| **Use Case** | Login |
| **Aktor** | Customer |
| **Deskripsi** | Customer masuk ke aplikasi menggunakan email & password atau melalui Google OAuth. Login Google otomatis mendaftarkan akun baru jika belum terdaftar |
| **Pra Kondisi** | 1. Customer sudah memiliki akun (untuk login email)<br>2. Customer membuka halaman login |
| **Alur** | 1. Customer membuka halaman login<br>2. Customer memilih metode login (email atau Google)<br>3a. Email: masukkan email & password → sistem validasi → JWT<br>3b. Google: pilih akun Google → Google OAuth → sistem cek/daftarkan akun → JWT<br>4. Customer diarahkan ke halaman utama |
| **Pasca Kondisi** | 1. Customer mendapat token JWT<br>2. Customer diarahkan ke halaman utama |

## UC-CST-03 — Lihat Kategori Layanan

| Item | Detail |
|---|---|
| **Use Case** | Lihat Kategori Layanan |
| **Aktor** | Customer |
| **Deskripsi** | Customer melihat semua kategori layanan yang tersedia di halaman utama dalam bentuk grid ikon atau daftar lengkap |
| **Pra Kondisi** | 1. Customer sudah login<br>2. Customer berada di halaman utama (home) |
| **Alur** | 1. Customer membuka aplikasi<br>2. Sistem mengambil data kategori dari API<br>3. Sistem menampilkan grid ikon kategori di halaman utama<br>4. Customer melihat dan memilih kategori |
| **Pasca Kondisi** | 1. Customer melihat daftar kategori layanan<br>2. Customer bisa memilih kategori untuk melihat layanan di dalamnya |

## UC-CST-04 — Cari Mitra berdasarkan Jarak

| Item | Detail |
|---|---|
| **Use Case** | Cari Mitra berdasarkan Jarak |
| **Aktor** | Customer |
| **Deskripsi** | Customer memilih layanan dan melihat daftar mitra yang menyediakan layanan tersebut, diurutkan berdasarkan jarak terdekat dan rating |
| **Pra Kondisi** | 1. Customer sudah login<br>2. Customer memilih kategori/layanan tertentu<br>3. Terdapat mitra yang menyediakan layanan tersebut |
| **Alur** | 1. Customer memilih kategori layanan<br>2. Customer memilih layanan spesifik<br>3. Sistem mencari mitra dengan layanan tersebut<br>4. Sistem mengurutkan mitra berdasarkan jarak & rating<br>5. Customer melihat daftar mitra |
| **Pasca Kondisi** | 1. Customer melihat daftar mitra dengan jarak, rating, dan jumlah pekerjaan<br>2. Customer dapat memilih mitra untuk melihat detail |

## UC-CST-05 — Lihat Detail Mitra

| Item | Detail |
|---|---|
| **Use Case** | Lihat Detail Mitra |
| **Aktor** | Customer |
| **Deskripsi** | Customer melihat informasi lengkap mitra dalam bentuk bottom sheet, termasuk profil, rating, jumlah pekerjaan, portofolio, harga layanan, ketersediaan, dan jadwal |
| **Pra Kondisi** | 1. Customer sudah login<br>2. Customer memilih mitra dari daftar pencarian |
| **Alur** | 1. Customer menekan kartu mitra<br>2. Sistem mengambil data detail mitra dari API<br>3. Sistem menampilkan bottom sheet detail mitra<br>4. Customer melihat informasi profil, harga, ulasan, portofolio |
| **Pasca Kondisi** | 1. Customer mendapat informasi lengkap mitra<br>2. Customer dapat melanjutkan ke pembuatan pesanan |

## UC-CST-06 — Buat Pesanan

| Item | Detail |
|---|---|
| **Use Case** | Buat Pesanan |
| **Aktor** | Customer |
| **Deskripsi** | Customer membuat pesanan baru dengan mengisi tanggal & waktu, memilih lokasi di peta, menambahkan deskripsi dan foto, serta menentukan jumlah |
| **Pra Kondisi** | 1. Customer sudah login<br>2. Customer sudah memilih mitra<br>3. Customer sudah melihat detail dan harga layanan |
| **Alur** | 1. Customer menekan tombol "Buat Pesanan"<br>2. Customer mengisi form: tanggal, waktu, lokasi (peta), deskripsi, foto, jumlah<br>3. Customer menekan tombol "Kirim"<br>4. Sistem membuat pesanan dengan status `pending`<br>5. Mitra mendapat notifikasi permintaan masuk |
| **Pasca Kondisi** | 1. Pesanan tersimpan dengan status `pending`<br>2. Mitra mendapat notifikasi permintaan masuk<br>3. Customer diarahkan ke pembayaran |

## UC-CST-07 — Bayar via Rekber (Escrow)

| Item | Detail |
|---|---|
| **Use Case** | Bayar via Rekber (Escrow) |
| **Aktor** | Customer |
| **Deskripsi** | Customer memilih metode pembayaran (transfer bank, e-wallet, QRIS) dan melakukan transfer ke rekening escrow admin sesuai nominal yang tertera |
| **Pra Kondisi** | 1. Customer sudah membuat pesanan<br>2. Pesanan masih berstatus `pending`<br>3. Customer melihat instruksi pembayaran |
| **Alur** | 1. Customer melihat halaman instruksi pembayaran<br>2. Customer memilih metode pembayaran (transfer bank/e-wallet/QRIS)<br>3. Customer melihat detail rekening escrow admin<br>4. Customer melakukan transfer ke rekening tersebut<br>5. Customer mengkonfirmasi telah transfer<br>6. Admin akan memverifikasi pembayaran |
| **Pasca Kondisi** | 1. Pembayaran tercatat menunggu konfirmasi admin<br>2. Admin mendapat notifikasi untuk konfirmasi pembayaran<br>3. Status pesanan berubah setelah admin konfirmasi |

## UC-CST-08 — Lacak Pesanan (Peta Langsung)

| Item | Detail |
|---|---|
| **Use Case** | Lacak Pesanan (Peta Langsung) |
| **Aktor** | Customer |
| **Deskripsi** | Customer melihat lokasi mitra secara real-time di peta beserta rute polyline dari mitra ke lokasi pesanan, diperbarui setiap 5 detik |
| **Pra Kondisi** | 1. Customer sudah login<br>2. Pesanan sudah dikonfirmasi dan sedang aktif<br>3. Mitra sudah mengupdate lokasinya |
| **Alur** | 1. Customer membuka halaman lacak pesanan<br>2. Sistem memuat peta dengan lokasi customer & mitra<br>3. Sistem mengambil rute dari ORS (OpenRouteService)<br>4. Sistem menampilkan rute polyline di peta<br>5. Peta diperbarui setiap 5 detik dengan posisi terbaru mitra |
| **Pasca Kondisi** | 1. Customer mengetahui posisi mitra secara langsung<br>2. Customer dapat memperkirakan waktu kedatangan |

## UC-CST-09 — Batalkan Pesanan

| Item | Detail |
|---|---|
| **Use Case** | Batalkan Pesanan |
| **Aktor** | Customer |
| **Deskripsi** | Customer membatalkan pesanan yang masih berstatus `pending` atau `accepted` (sebelum mitra mulai perjalanan) |
| **Pra Kondisi** | 1. Customer sudah login<br>2. Pesanan berstatus `pending` atau `accepted`<br>3. Customer berada di halaman detail pesanan |
| **Alur** | 1. Customer membuka detail pesanan<br>2. Customer menekan tombol "Batalkan Pesanan"<br>3. Sistem meminta konfirmasi pembatalan<br>4. Customer mengkonfirmasi pembatalan<br>5. Sistem mengubah status pesanan menjadi `cancelled` |
| **Pasca Kondisi** | 1. Status pesanan berubah menjadi `cancelled`<br>2. Mitra mendapat notifikasi pembatalan |

## UC-CST-10 — Beri Rating & Ulasan

| Item | Detail |
|---|---|
| **Use Case** | Beri Rating & Ulasan |
| **Aktor** | Customer |
| **Deskripsi** | Customer memberikan rating bintang (1-5) dan ulasan teks untuk mitra setelah pesanan selesai. Hanya satu ulasan per pesanan |
| **Pra Kondisi** | 1. Customer sudah login<br>2. Pesanan sudah berstatus `completed`<br>3. Customer belum pernah memberi ulasan untuk pesanan ini |
| **Alur** | 1. Customer membuka halaman detail pesanan selesai<br>2. Customer memilih rating bintang (1-5)<br>3. Customer menulis teks ulasan<br>4. Customer menekan tombol "Kirim Ulasan"<br>5. Sistem menyimpan rating & ulasan ke database |
| **Pasca Kondisi** | 1. Rating dan ulasan tersimpan di database<br>2. Rating mitra diperbarui (rata-rata)<br>3. Ulasan muncul di halaman profil mitra |

## UC-CST-11 — Lihat Riwayat Pesanan

| Item | Detail |
|---|---|
| **Use Case** | Lihat Riwayat Pesanan |
| **Aktor** | Customer |
| **Deskripsi** | Customer melihat daftar semua pesanan yang pernah dibuat, dapat difilter berdasarkan status: Semua, Aktif, atau Selesai |
| **Pra Kondisi** | 1. Customer sudah login<br>2. Customer memiliki riwayat pesanan |
| **Alur** | 1. Customer membuka halaman "Pesanan Saya"<br>2. Sistem mengambil daftar pesanan dari API<br>3. Customer memilih filter (Semua/Aktif/Selesai)<br>4. Sistem menampilkan pesanan sesuai filter |
| **Pasca Kondisi** | 1. Customer melihat daftar pesanan<br>2. Customer dapat memilih pesanan untuk melihat detail |

## UC-CST-12 — Buat Custom Task

| Item | Detail |
|---|---|
| **Use Case** | Buat Custom Task |
| **Aktor** | Customer |
| **Deskripsi** | Customer membuat task khusus dengan judul, deskripsi, budget, jumlah orang, dan lokasi di peta. Setelah membayar escrow, task bisa diambil oleh mitra |
| **Pra Kondisi** | 1. Customer sudah login<br>2. Customer memiliki kebutuhan layanan yang tidak tercakup di kategori standar |
| **Alur** | 1. Customer membuka halaman buat custom task<br>2. Customer mengisi judul, deskripsi, budget, jumlah orang<br>3. Customer memilih lokasi di peta<br>4. Customer menekan "Buat Task"<br>5. Customer melakukan pembayaran escrow<br>6. Admin mengkonfirmasi pembayaran<br>7. Task tersedia untuk diambil mitra |
| **Pasca Kondisi** | 1. Custom task tersimpan dengan status menunggu pembayaran<br>2. Customer melakukan pembayaran escrow<br>3. Task tersedia untuk dilihat mitra |

## UC-CST-13 — Kelola Profil

| Item | Detail |
|---|---|
| **Use Case** | Kelola Profil |
| **Aktor** | Customer |
| **Deskripsi** | Customer mengupdate data profil seperti nama, nomor telepon, dan foto avatar |
| **Pra Kondisi** | 1. Customer sudah login<br>2. Customer membuka halaman profil |
| **Alur** | 1. Customer membuka halaman profil<br>2. Customer menekan tombol edit<br>3. Customer mengubah data yang diinginkan<br>4. Customer menyimpan perubahan<br>5. Sistem memperbarui data di database |
| **Pasca Kondisi** | 1. Data profil tersimpan di database<br>2. Perubahan langsung terlihat di aplikasi |

## UC-CST-14 — Kirim Laporan

| Item | Detail |
|---|---|
| **Use Case** | Kirim Laporan |
| **Aktor** | Customer |
| **Deskripsi** | Customer melaporkan masalah terkait pesanan dengan mengirim subjek, deskripsi, dan lampiran |
| **Pra Kondisi** | 1. Customer sudah login<br>2. Customer memiliki masalah yang ingin dilaporkan |
| **Alur** | 1. Customer membuka halaman laporan<br>2. Customer mengisi subjek, deskripsi, dan lampiran<br>3. Customer menekan tombol "Kirim Laporan"<br>4. Sistem menyimpan laporan ke database<br>5. Admin mendapat notifikasi laporan masuk |
| **Pasca Kondisi** | 1. Laporan tersimpan di database<br>2. Admin mendapat notifikasi laporan masuk<br>3. Customer dapat memantau status laporan |

## UC-CST-15 — Cari Lokasi

| Item | Detail |
|---|---|
| **Use Case** | Cari Lokasi |
| **Aktor** | Customer |
| **Deskripsi** | Customer mencari alamat atau lokasi menggunakan geocoding (Photon API) saat membuat pesanan atau custom task |
| **Pra Kondisi** | 1. Customer sudah login<br>2. Customer sedang dalam proses pembuatan pesanan atau task |
| **Alur** | 1. Customer menekan field pencarian lokasi<br>2. Customer mengetik alamat atau nama tempat<br>3. Sistem memanggil Photon API untuk geocoding<br>4. Sistem menampilkan hasil pencarian<br>5. Customer memilih lokasi yang diinginkan |
| **Pasca Kondisi** | 1. Lokasi yang dipilih tersimpan di form pesanan/task<br>2. Koordinat latitude-longitude digunakan untuk map |

---

# C. Mitra (Provider)

## UC-MIT-01 — Daftar Akun (Multi-step)

| Item | Detail |
|---|---|
| **Use Case** | Daftar Akun (Multi-step) |
| **Aktor** | Mitra (Provider) |
| **Deskripsi** | Mitra mendaftar melalui proses multi-step: (1) pilih kategori & layanan, (2) isi data diri, (3) upload dokumen (KTP, selfie, portofolio, ijazah, sertifikat), (4) scan KTP via OCR, (5) deteksi liveness wajah, (6) setujui syarat & ketentuan. Status langsung `pending` menunggu verifikasi admin |
| **Pra Kondisi** | 1. Mitra belum memiliki akun<br>2. Mitra memiliki dokumen KTP dan foto selfie<br>3. Mitra membuka halaman registrasi mitra |
| **Alur** | 1. Mitra memilih kategori & layanan yang ditawarkan<br>2. Mitra mengisi data diri (nama, nickname, telepon, tgl lahir, gender, alamat)<br>3. Mitra upload dokumen: KTP, selfie, portofolio, ijazah, sertifikat<br>4. Sistem melakukan OCR pada KTP untuk auto-fill data<br>5. Mitra melakukan deteksi liveness (face capture)<br>6. Mitra menyetujui syarat & ketentuan<br>7. Sistem menyimpan data dengan status `pending`<br>8. Admin mendapat notifikasi mitra baru |
| **Pasca Kondisi** | 1. Akun mitra tersimpan dengan status `pending`<br>2. Data identitas & dokumen tersimpan<br>3. Admin mendapat notifikasi mitra baru perlu verifikasi |

## UC-MIT-02 — Login (Cek Verifikasi)

| Item | Detail |
|---|---|
| **Use Case** | Login (Cek Verifikasi) |
| **Aktor** | Mitra (Provider) |
| **Deskripsi** | Mitra login menggunakan email & password. Sistem memeriksa status verifikasi: ditolak tetap bisa login tetapi melihat layar penolakan, pending tidak bisa login |
| **Pra Kondisi** | 1. Mitra sudah terdaftar<br>2. Status verifikasi mitra sudah `verified` atau `rejected` |
| **Alur** | 1. Mitra membuka halaman login<br>2. Mitra memasukkan email dan password<br>3. Sistem memvalidasi kredensial dan mengecek status verifikasi<br>4a. Jika `verified`: masuk ke dashboard<br>4b. Jika `rejected`: menampilkan layar penolakan dengan opsi resubmit<br>4c. Jika `pending`: akses ditolak |
| **Pasca Kondisi** | 1. Jika `verified`: mitra masuk ke dashboard<br>2. Jika `rejected`: mitra melihat alasan penolakan dan opsi resubmit |

## UC-MIT-03 — Ajukan Ulang Verifikasi

| Item | Detail |
|---|---|
| **Use Case** | Ajukan Ulang Verifikasi |
| **Aktor** | Mitra (Provider) |
| **Deskripsi** | Mitra memperbaiki dokumen yang ditolak dan mengajukan ulang verifikasi setelah mendapatkan catatan penolakan dari admin |
| **Pra Kondisi** | 1. Mitra sudah login<br>2. Status verifikasi mitra adalah `rejected`<br>3. Mitra sudah memperbaiki dokumen sesuai catatan admin |
| **Alur** | 1. Mitra melihat catatan penolakan dari admin<br>2. Mitra memperbaiki dokumen yang ditolak<br>3. Mitra menekan tombol "Ajukan Ulang"<br>4. Sistem mengubah status kembali menjadi `pending`<br>5. Admin mendapat notifikasi untuk review ulang |
| **Pasca Kondisi** | 1. Status mitra kembali menjadi `pending`<br>2. Admin mendapat notifikasi untuk review ulang |

## UC-MIT-04 — Selesaikan Onboarding

| Item | Detail |
|---|---|
| **Use Case** | Selesaikan Onboarding |
| **Aktor** | Mitra (Provider) |
| **Deskripsi** | Setelah terverifikasi, mitra melengkapi profil: upload foto profil, mengatur layanan & harga per tipe (flat/jam/unit), dan menambahkan metode pencairan dana (bank/e-wallet) |
| **Pra Kondisi** | 1. Mitra sudah login<br>2. Status verifikasi mitra adalah `verified`<br>3. Mitra pertama kali masuk setelah diverifikasi |
| **Alur** | 1. Mitra disambut dengan halaman onboarding<br>2. Mitra upload foto profil<br>3. Mitra mengatur layanan & harga untuk setiap tipe harga<br>4. Mitra menambahkan metode pencairan dana (bank/e-wallet)<br>5. Sistem menyimpan semua data<br>6. Mitra diarahkan ke dashboard |
| **Pasca Kondisi** | 1. Profil mitra lengkap<br>2. Mitra sudah siap menerima pesanan<br>3. Mitra bisa toggle ketersediaan |

## UC-MIT-05 — Atur Ketersediaan

| Item | Detail |
|---|---|
| **Use Case** | Atur Ketersediaan |
| **Aktor** | Mitra (Provider) |
| **Deskripsi** | Mitra mengaktifkan atau menonaktifkan ketersediaan untuk menerima pesanan layanan dan custom task secara terpisah melalui toggle di dashboard |
| **Pra Kondisi** | 1. Mitra sudah login<br>2. Mitra sudah menyelesaikan onboarding<br>3. Mitra berada di halaman dashboard |
| **Alur** | 1. Mitra melihat toggle ketersediaan di dashboard<br>2. Mitra mengaktifkan/menonaktifkan toggle (terpisah untuk layanan & task)<br>3. Sistem memperbarui status ketersediaan di database |
| **Pasca Kondisi** | 1. Status ketersediaan mitra berubah<br>2. Customer melihat status ketersediaan saat mencari mitra |

## UC-MIT-06 — Lihat Permintaan Masuk

| Item | Detail |
|---|---|
| **Use Case** | Lihat Permintaan Masuk |
| **Aktor** | Mitra (Provider) |
| **Deskripsi** | Mitra melihat daftar permintaan pesanan masuk dengan timer hitung mundur 5 menit. Halaman auto-refresh setiap 30 detik |
| **Pra Kondisi** | 1. Mitra sudah login<br>2. Terdapat customer yang membuat pesanan ke mitra ini<br>3. Ketersediaan mitra sedang aktif |
| **Alur** | 1. Mitra membuka halaman "Permintaan"<br>2. Sistem mengambil daftar permintaan pending dari API<br>3. Sistem menampilkan timer hitung mundur 5 menit per permintaan<br>4. Halaman auto-refresh setiap 30 detik<br>5. Mitra melihat daftar permintaan |
| **Pasca Kondisi** | 1. Mitra melihat daftar permintaan<br>2. Mitra dapat menerima atau menolak pesanan |

## UC-MIT-07 — Terima / Tolak Pesanan

| Item | Detail |
|---|---|
| **Use Case** | Terima / Tolak Pesanan |
| **Aktor** | Mitra (Provider) |
| **Deskripsi** | Mitra menerima atau menolak permintaan pesanan masuk. Jika diterima status jadi `accepted`, jika ditolak status jadi `rejected` |
| **Pra Kondisi** | 1. Mitra sudah login<br>2. Terdapat permintaan pesanan yang masih `pending`<br>3. Mitra sudah melihat detail permintaan |
| **Alur** | 1. Mitra memilih permintaan dari daftar<br>2. Mitra melihat detail permintaan (lokasi, layanan, jadwal)<br>3. Mitra menekan "Terima" atau "Tolak"<br>4. Sistem memperbarui status pesanan<br>5. Customer mendapat notifikasi |
| **Pasca Kondisi** | 1. Jika diterima: customer dapat notifikasi mitra akan datang<br>2. Jika ditolak: customer dapat mencari mitra lain |

## UC-MIT-08 — Update Status Pesanan

| Item | Detail |
|---|---|
| **Use Case** | Update Status Pesanan |
| **Aktor** | Mitra (Provider) |
| **Deskripsi** | Mitra memperbarui status pesanan sesuai progres: `accepted` → `on_the_way` → `arrived` → `in_progress` → `completed` melalui tombol di dashboard |
| **Pra Kondisi** | 1. Mitra sudah login<br>2. Terdapat pesanan aktif yang sedang berjalan<br>3. Mitra berada di halaman dashboard |
| **Alur** | 1. Mitra melihat kartu pesanan aktif di dashboard<br>2. Mitra menekan tombol status sesuai progres (Berangkat/Tiba/Mulai/Selesai)<br>3. Sistem memperbarui status pesanan<br>4. Customer mendapat notifikasi perubahan status<br>5. Setelah `completed`, customer bisa memberi rating |
| **Pasca Kondisi** | 1. Status pesanan berubah sesuai progres<br>2. Customer mendapat notifikasi perubahan status<br>3. Setelah `completed`, customer bisa memberi rating |

## UC-MIT-09 — Minta Perpanjangan

| Item | Detail |
|---|---|
| **Use Case** | Minta Perpanjangan |
| **Aktor** | Mitra (Provider) |
| **Deskripsi** | Jika pekerjaan melebihi waktu yang ditentukan, mitra meminta perpanjangan waktu (1-3 hari) yang harus disetujui oleh admin |
| **Pra Kondisi** | 1. Mitra sudah login<br>2. Pesanan sedang dalam status `in_progress`<br>3. Mitra membutuhkan waktu tambahan |
| **Alur** | 1. Mitra membuka detail pesanan aktif<br>2. Mitra menekan tombol "Minta Perpanjangan"<br>3. Mitra memilih durasi perpanjangan (1-3 hari)<br>4. Mitra menambahkan alasan<br>5. Sistem mengirim permintaan ke admin<br>6. Admin menyetujui atau menolak |
| **Pasca Kondisi** | 1. Permintaan perpanjangan dikirim ke admin<br>2. Admin menyetujui atau menolak permintaan<br>3. Mitra mendapat notifikasi hasil persetujuan |

## UC-MIT-10 — Lihat Jadwal & Pendapatan

| Item | Detail |
|---|---|
| **Use Case** | Lihat Jadwal & Pendapatan |
| **Aktor** | Mitra (Provider) |
| **Deskripsi** | Mitra melihat jadwal hari ini, pendapatan bulanan, dan riwayat pesanan dalam rentang tanggal tertentu |
| **Pra Kondisi** | 1. Mitra sudah login<br>2. Mitra memiliki riwayat pesanan |
| **Alur** | 1. Mitra membuka halaman jadwal/dashboard<br>2. Sistem mengambil data jadwal & pendapatan dari API<br>3. Mitra melihat jadwal hari ini & pendapatan bulanan<br>4. Mitra dapat memfilter berdasarkan rentang tanggal |
| **Pasca Kondisi** | 1. Mitra melihat jadwal dan pendapatan<br>2. Mitra dapat merencanakan jadwal kerja |

## UC-MIT-11 — Kelola Layanan & Harga

| Item | Detail |
|---|---|
| **Use Case** | Kelola Layanan & Harga |
| **Aktor** | Mitra (Provider) |
| **Deskripsi** | Mitra menambah atau mengupdate layanan yang ditawarkan beserta deskripsi dan harga per tipe harga (flat, per jam, per unit) |
| **Pra Kondisi** | 1. Mitra sudah login<br>2. Mitra menyelesaikan onboarding |
| **Alur** | 1. Mitra membuka halaman "Layanan Saya"<br>2. Mitra melihat daftar layanan yang ditawarkan<br>3. Mitra memilih layanan untuk diedit atau menambah layanan baru<br>4. Mitra mengubah deskripsi dan harga per tipe<br>5. Mitra menyimpan perubahan |
| **Pasca Kondisi** | 1. Layanan dan harga tersimpan<br>2. Customer melihat layanan & harga terbaru di profil mitra |

## UC-MIT-12 — Kelola Metode Pencairan

| Item | Detail |
|---|---|
| **Use Case** | Kelola Metode Pencairan |
| **Aktor** | Mitra (Provider) |
| **Deskripsi** | Mitra menambah, mengubah, dan menghapus metode pencairan dana (rekening bank atau e-wallet) untuk menerima pembayaran dari admin |
| **Pra Kondisi** | 1. Mitra sudah login<br>2. Mitra sudah menyelesaikan onboarding |
| **Alur** | 1. Mitra membuka halaman "Metode Pencairan"<br>2. Mitra melihat daftar metode yang tersimpan<br>3. Mitra menambah metode baru (bank/e-wallet) atau mengedit/menghapus yang ada<br>4. Mitra mengisi detail rekening/nomor e-wallet<br>5. Sistem menyimpan perubahan |
| **Pasca Kondisi** | 1. Metode pencairan tersimpan di database<br>2. Admin dapat mencairkan dana ke metode tersebut |

## UC-MIT-13 — Update Lokasi Langsung

| Item | Detail |
|---|---|
| **Use Case** | Update Lokasi Langsung |
| **Aktor** | Mitra (Provider) |
| **Deskripsi** | Aplikasi secara otomatis mengirim lokasi GPS mitra ke server setiap 30 detik melalui background stream Geolocator untuk memungkinkan customer melacak posisi |
| **Pra Kondisi** | 1. Mitra sudah login<br>2. Mitra memberikan izin akses lokasi<br>3. Aplikasi berjalan di latar depan/belakang |
| **Alur** | 1. Aplikasi menginisialisasi Geolocator stream<br>2. Setiap 30 detik, sistem mengambil posisi GPS terkini<br>3. Sistem mengirim koordinat ke API `PUT /locations/update`<br>4. Server menyimpan lokasi terbaru mitra |
| **Pasca Kondisi** | 1. Lokasi mitra tersimpan di database<br>2. Customer dapat melihat posisi langsung mitra di peta |

## UC-MIT-14 — Cari Custom Task Tersedia

| Item | Detail |
|---|---|
| **Use Case** | Cari Custom Task Tersedia |
| **Aktor** | Mitra (Provider) |
| **Deskripsi** | Mitra mencari task khusus yang tersedia di sekitar lokasinya, melihat detail budget dan deskripsi, lalu memutuskan untuk mengambil task tersebut |
| **Pra Kondisi** | 1. Mitra sudah login<br>2. Ketersediaan custom task aktif<br>3. Ada customer yang membuat custom task dan sudah bayar |
| **Alur** | 1. Mitra membuka halaman "Task Tersedia"<br>2. Sistem mengambil task di sekitar lokasi mitra<br>3. Mitra melihat daftar task dengan budget & deskripsi<br>4. Mitra memilih task untuk melihat detail |
| **Pasca Kondisi** | 1. Mitra melihat daftar task tersedia<br>2. Mitra dapat memilih task untuk diambil |

## UC-MIT-15 — Terima Custom Task

| Item | Detail |
|---|---|
| **Use Case** | Terima Custom Task |
| **Aktor** | Mitra (Provider) |
| **Deskripsi** | Mitra menerima/mengambil custom task yang tersedia untuk dikerjakan |
| **Pra Kondisi** | 1. Mitra sudah login<br>2. Mitra menemukan task yang sesuai dari daftar task tersedia<br>3. Task belum diambil mitra lain |
| **Alur** | 1. Mitra membuka detail task<br>2. Mitra menekan tombol "Terima Task"<br>3. Sistem mengikat task ke mitra tersebut<br>4. Customer mendapat notifikasi mitra telah mengambil task |
| **Pasca Kondisi** | 1. Task terikat ke mitra yang mengambil<br>2. Customer mendapat notifikasi mitra telah mengambil task |

## UC-MIT-16 — Selesaikan Custom Task

| Item | Detail |
|---|---|
| **Use Case** | Selesaikan Custom Task |
| **Aktor** | Mitra (Provider) |
| **Deskripsi** | Mitra menandai custom task sebagai selesai, yang memicu alur konfirmasi pencairan dana oleh admin |
| **Pra Kondisi** | 1. Mitra sudah login<br>2. Mitra sudah mengambil task tersebut<br>3. Pekerjaan sudah selesai dilakukan |
| **Alur** | 1. Mitra membuka detail task yang sedang dikerjakan<br>2. Mitra menekan tombol "Selesaikan"<br>3. Sistem mengubah status task menunggu konfirmasi admin<br>4. Admin memproses pencairan dana ke mitra |
| **Pasca Kondisi** | 1. Status task berubah menunggu konfirmasi admin<br>2. Admin memproses pencairan dana ke mitra |

## UC-MIT-17 — Kelola Profil

| Item | Detail |
|---|---|
| **Use Case** | Kelola Profil |
| **Aktor** | Mitra (Provider) |
| **Deskripsi** | Mitra mengupdate data diri, foto profil, portofolio, dan dokumen pendukung |
| **Pra Kondisi** | 1. Mitra sudah login<br>2. Mitra membuka halaman profil |
| **Alur** | 1. Mitra membuka halaman profil<br>2. Mitra menekan tombol edit<br>3. Mitra mengubah data yang diinginkan (foto, data diri, portofolio)<br>4. Mitra menyimpan perubahan<br>5. Sistem memperbarui data di database |
| **Pasca Kondisi** | 1. Data profil tersimpan di database<br>2. Perubahan langsung terlihat oleh customer |

## UC-MIT-18 — Lihat Ulasan

| Item | Detail |
|---|---|
| **Use Case** | Lihat Ulasan |
| **Aktor** | Mitra (Provider) |
| **Deskripsi** | Mitra melihat semua ulasan yang diberikan oleh customer, termasuk rating bintang dan teks ulasan |
| **Pra Kondisi** | 1. Mitra sudah login<br>2. Mitra memiliki riwayat pesanan yang sudah selesai dan diulas |
| **Alur** | 1. Mitra membuka halaman "Ulasan"<br>2. Sistem mengambil daftar ulasan dari API<br>3. Mitra melihat daftar ulasan dengan rating & teks<br>4. Mitra dapat mengevaluasi kualitas layanan |
| **Pasca Kondisi** | 1. Mitra melihat daftar ulasan<br>2. Mitra dapat mengevaluasi kualitas layanan |
