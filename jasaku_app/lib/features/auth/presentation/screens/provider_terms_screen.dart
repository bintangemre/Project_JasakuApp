import 'package:flutter/material.dart';

class ProviderTermsScreen extends StatelessWidget {
  const ProviderTermsScreen({super.key});

  static const _sections = [
    {
      'title': '1. Ketentuan Umum',
      'body':
          'Jasaku merupakan platform yang mempertemukan pelanggan dengan penyedia jasa berdasarkan kategori layanan yang tersedia. Dengan menggunakan aplikasi ini, pengguna dianggap telah membaca, memahami, dan menyetujui seluruh syarat dan ketentuan yang berlaku.',
    },
    {
      'title': '2. Ketentuan Akun',
      'body':
          '2.1 Pelanggan\n\nPelanggan wajib:\n\n• Memberikan data yang benar dan akurat.\n• Menjaga kerahasiaan akun dan kata sandi.\n• Tidak menggunakan akun untuk tindakan yang melanggar hukum.\n\n2.2 Penyedia Jasa\n\nPenyedia jasa wajib:\n\n• Memberikan informasi identitas yang benar.\n• Melakukan proses verifikasi sesuai ketentuan.\n• Memberikan layanan secara profesional dan bertanggung jawab.\n• Menjaga kualitas pekerjaan sesuai kesepakatan dengan pelanggan.',
    },
    {
      'title': '3. Verifikasi Penyedia Jasa',
      'body':
          'Penyedia jasa yang berusia 18 tahun atau lebih wajib melakukan verifikasi identitas melalui dokumen yang ditentukan oleh sistem.\n\nSertifikat, portofolio, dan pengalaman kerja merupakan informasi tambahan yang bersifat opsional.',
    },
    {
      'title': '4. Pemesanan Layanan',
      'body':
          'Pelanggan dapat melakukan pemesanan dengan:\n\n• Memilih penyedia jasa secara langsung; atau\n• Menggunakan fitur pencarian otomatis yang disediakan oleh sistem.\n\nJasaku berhak mengatur antrean dan jadwal pekerjaan apabila penyedia jasa sedang menangani pekerjaan lain.',
    },
    {
      'title': '5. Sistem Antrean',
      'body':
          'Jika pelanggan melakukan pemesanan pada waktu yang sama dengan pekerjaan aktif penyedia jasa, maka pesanan dapat dimasukkan ke dalam antrean sesuai jadwal yang tersedia.\n\nPelanggan akan memperoleh informasi mengenai estimasi waktu penyelesaian pekerjaan sebelumnya.',
    },
    {
      'title': '6. Pembayaran',
      'body':
          'Jasaku mendukung metode pembayaran berikut:\n\n• Tunai (Cash)\n• Transfer Bank\n• E-Wallet\n• QRIS\n\nPembayaran melalui sistem elektronik akan diproses sesuai ketentuan penyedia layanan pembayaran yang digunakan.',
    },
    {
      'title': '7. Pembatalan Pesanan',
      'body':
          'Pelanggan dan penyedia jasa dapat melakukan pembatalan pesanan sesuai kebijakan yang berlaku.\n\nJasaku berhak membatasi atau menindak akun yang melakukan pembatalan secara berlebihan atau merugikan pihak lain.',
    },
    {
      'title': '8. Rating dan Ulasan',
      'body':
          'Pelanggan dapat memberikan rating dan ulasan setelah pekerjaan selesai.\n\nUlasan harus:\n\n• Bersifat objektif;\n• Tidak mengandung unsur penghinaan;\n• Tidak mengandung informasi palsu;\n• Tidak melanggar hukum yang berlaku.\n\nJasaku berhak menghapus ulasan yang tidak sesuai dengan ketentuan.',
    },
    {
      'title': '9. Pelacakan Lokasi',
      'body':
          'Untuk meningkatkan keamanan dan kenyamanan, Jasaku dapat menampilkan lokasi penyedia jasa secara real-time ketika penyedia jasa menuju lokasi pelanggan.\n\nData lokasi hanya digunakan selama proses pelayanan berlangsung dan dikelola sesuai kebijakan privasi yang berlaku.',
    },
    {
      'title': '10. Tanggung Jawab Platform',
      'body':
          'Jasaku berperan sebagai platform penghubung antara pelanggan dan penyedia jasa.\n\nPelaksanaan pekerjaan merupakan tanggung jawab masing-masing pihak sesuai kesepakatan yang dibuat melalui aplikasi.',
    },
    {
      'title': '11. Larangan Penggunaan',
      'body':
          'Pengguna dilarang:\n\n• Menggunakan aplikasi untuk kegiatan ilegal;\n• Memberikan data palsu;\n• Melakukan penipuan atau tindakan yang merugikan pengguna lain;\n• Menyalahgunakan sistem pembayaran dan antrean.\n\nPelanggaran terhadap ketentuan ini dapat mengakibatkan pembatasan atau penghapusan akun.',
    },
    {
      'title': '12. Perubahan Syarat dan Ketentuan',
      'body':
          'Jasaku berhak mengubah syarat dan ketentuan sewaktu-waktu untuk meningkatkan kualitas layanan dan menyesuaikan dengan perkembangan sistem.\n\nPengguna akan memperoleh informasi mengenai perubahan tersebut melalui aplikasi.',
    },
    {
      'title': '13. Persetujuan Pengguna',
      'body':
          'Dengan menggunakan aplikasi Jasaku, pengguna dianggap telah membaca, memahami, dan menyetujui seluruh syarat dan ketentuan yang berlaku.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Syarat & Ketentuan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: _sections.length,
          separatorBuilder: (_, __) => const Divider(height: 24),
          itemBuilder: (context, index) {
            final section = _sections[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section['title']!,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  section['body']!,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.5,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
