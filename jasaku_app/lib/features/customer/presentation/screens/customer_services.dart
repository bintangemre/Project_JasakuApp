// Screen service utama untuk pelanggan, melihat daftar kategori layanan dan penyedia jasa.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'customer_providers_by_category.dart';

class CustomerServices extends ConsumerWidget {
  const CustomerServices({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // List data kategori lokal sementara (disamakan dengan di Home)
    final List<Map<String, dynamic>> categories = [
      {
        'id': 'eba91362-4c0a-4045-bcca-51da9263a35d', // sesuaikan id dari database nanti
        'title': 'Perbaikan Bangunan',
        'icon': Icons.home_repair_service,
        'iconColor': const Color(0xFFFF6B00),
        'bgColor': const Color(0xFFFFEDD5),
      },
      {
        'id': 'a7003a03-7318-41e0-8ece-f4810e80abf7',
        'title': 'Perbaikan Kelistrikan',
        'icon': Icons.bolt,
        'iconColor': const Color(0xFFD4A100),
        'bgColor': const Color(0xFFFEF3C7),
      },
    ];

    return Scaffold(
      backgroundColor: const Color(
        0xFFF8FAFC,
      ), // Warna abu-abu terang netral (slate 50)
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Semua Kategori Jasa',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: categories.length,
        separatorBuilder:
            (context, index) =>
                const SizedBox(height: 16), // Jarak antar daftar
        itemBuilder: (context, index) {
          final item = categories[index];
          return _buildCategoryListTile(
            context: context,
            title: item['title'],
            icon: item['icon'],
            iconColor: item['iconColor'],
            bgColor: item['bgColor'],
            onTap: () {
              // TODO: Lanjut ke bagian dalam kategori (Menampilkan list penyedia jasa berdasarkan ID)
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (_) => CustomerProvidersByCategory(
                        categoryId: item['id'].toString(),
                        categoryName: item['title'],
                      ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Widget bantuan untuk membuat baris daftar ke bawah (ListTile)
  Widget _buildCategoryListTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Bagian wadah Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),

            const SizedBox(width: 16),

            // Judul Kategori
            Expanded(
              child: Text(
                title.replaceAll(
                  '\n',
                  ' ',
                ), // Menghilangkan baris baru (\n) agar teksnya memanjang ke samping
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),

            // Icon panah penunjuk di sebelah kanan
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
