import 'package:flutter/material.dart';

class ProviderFaqScreen extends StatelessWidget {
  const ProviderFaqScreen({super.key});

  static const _faqs = [
    {
      'q': 'Apa itu Jasaku?',
      'a': 'Jasaku adalah platform marketplace jasa yang menghubungkan pelanggan dengan penyedia jasa profesional berdasarkan kategori layanan, lokasi, dan ketersediaan waktu. Saat ini, Jasaku menyediakan layanan Perbaikan Bangunan dan Kelistrikan.',
    },
    {
      'q': 'Bagaimana cara memesan jasa?',
      'a': 'Pelanggan dapat melakukan langkah berikut:\n\n1. Memilih kategori layanan.\n2. Memilih jenis pekerjaan yang dibutuhkan.\n3. Memilih metode pengerjaan.\n4. Memilih penyedia jasa secara manual atau menggunakan fitur pencarian otomatis.\n5. Mengisi detail pekerjaan dan lokasi.\n6. Melakukan pembayaran sesuai metode yang dipilih.',
    },
    {
      'q': 'Mengapa penyedia jasa yang saya pilih berstatus sedang mengerjakan pekerjaan lain?',
      'a': 'Penyedia jasa yang sedang memiliki pekerjaan aktif akan ditandai dengan status "Sedang mengerjakan pesanan lain." Pelanggan tetap dapat melakukan pemesanan dengan cara:\n\n• Menentukan jadwal pada hari yang berbeda, atau\n• Masuk ke dalam antrean apabila memesan pada hari yang sama.',
    },
    {
      'q': 'Bagaimana sistem antrean bekerja?',
      'a': 'Jika terdapat beberapa pelanggan yang memesan penyedia jasa yang sama pada hari yang sama, maka sistem akan mengatur urutan antrean berdasarkan waktu pemesanan dan jadwal pekerjaan yang telah ditentukan.',
    },
    {
      'q': 'Apakah saya dapat melacak lokasi penyedia jasa?',
      'a': 'Ya. Setelah penyedia jasa berangkat menuju lokasi pelanggan, pelanggan dapat melihat posisi penyedia jasa secara real-time melalui peta berbasis OpenStreetMap.',
    },
    {
      'q': 'Metode pembayaran apa saja yang tersedia?',
      'a': 'Jasaku mendukung beberapa metode pembayaran:\n\n• Tunai (Cash)\n• Transfer Bank\n• E-Wallet\n• QRIS',
    },
    {
      'q': 'Apakah data rekening dan e-wallet saya akan disimpan?',
      'a': 'Ya. Data pembayaran dapat disimpan secara aman untuk mempermudah transaksi berikutnya. Pelanggan dapat mengubah atau menghapus data tersebut kapan saja melalui pengaturan akun.',
    },
    {
      'q': 'Bagaimana jika penyedia jasa tidak memiliki sertifikat?',
      'a': 'Sertifikat dan portofolio bersifat opsional. Penyedia jasa tetap dapat bergabung dan bekerja selama telah memenuhi proses verifikasi identitas yang berlaku dan mendapatkan penilaian positif dari pelanggan.',
    },
    {
      'q': 'Kapan saya dapat memberikan rating dan ulasan?',
      'a': 'Pelanggan dapat memberikan rating dan ulasan setelah pekerjaan selesai. Setiap pesanan hanya dapat diberikan satu ulasan.',
    },
    {
      'q': 'Bagaimana jika penyedia jasa membatalkan pesanan?',
      'a': 'Pelanggan akan menerima notifikasi dan dapat memilih penyedia jasa lain atau menggunakan fitur pencarian otomatis dari sistem.',
    },
    {
      'q': 'Bagaimana cara menghubungi pihak Jasaku?',
      'a': 'Pelanggan dapat menghubungi layanan bantuan melalui menu Bantuan atau Kontak yang tersedia pada aplikasi.',
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
        title: const Text('FAQ — Jasaku',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: _faqs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final faq = _faqs[index];
            return ExpansionTile(
              title: Text(
                '${index + 1}. ${faq['q']}',
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
              childrenPadding:
                  const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              children: [
                Text(
                  faq['a']!,
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
