import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_endpoints.dart';
import 'customer_providers_by_category.dart';

class CustomerServices extends ConsumerStatefulWidget {
  const CustomerServices({super.key});

  @override
  ConsumerState<CustomerServices> createState() => _CustomerServicesState();
}

class _CustomerServicesState extends ConsumerState<CustomerServices> {
  late final Future<List<Map<String, dynamic>>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = ApiClient().dio.get(ApiEndpoints.getAllCategories).then((res) {
      final data = res.data['data'] as List<dynamic>? ?? [];
      return data.map((c) {
        final rawName = c['name'] as String? ?? '';
        final name = rawName.trim();
        IconData icon;
        Color iconColor;
        Color bgColor;
        String? imagePath;
        if (name.contains('listrik') || name.contains('Listrik') || name.contains('KELISTRIKAN')) {
          icon = Icons.electric_bolt;
          iconColor = const Color(0xFFFFB300);
          bgColor = const Color(0xFFFEF3C7);
          imagePath = 'assets/icons/icon_perbaikan_kelistrikan.png';
        } else if (name.contains('Bangunan') || name.contains('bangunan')) {
          icon = Icons.home_repair_service;
          iconColor = const Color(0xFFFF6B00);
          bgColor = const Color(0xFFFFEDD5);
          imagePath = 'assets/icons/icon_perbaikan_bangunan.png';
        } else {
          icon = Icons.category;
          iconColor = Colors.grey;
          bgColor = const Color(0xFFF1F5F9);
        }
        return {
          'id': c['id'] as String,
          'title': name,
          'icon': icon,
          'iconColor': iconColor,
          'bgColor': bgColor,
          'imagePath': imagePath,
        };
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _categoriesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final categories = snapshot.data ?? [];
          if (categories.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Belum ada kategori jasa', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: categories.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final item = categories[index];
              return _buildCategoryListTile(
                context: context,
                title: item['title'],
                icon: item['icon'] as IconData,
                iconColor: item['iconColor'] as Color,
                bgColor: item['bgColor'] as Color,
                imagePath: item['imagePath'] as String?,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CustomerProvidersByCategory(
                        categoryId: item['id'].toString(),
                        categoryName: item['title'],
                      ),
                    ),
                  );
                },
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
    String? imagePath,
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
              child: imagePath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(imagePath, width: 28, height: 28, fit: BoxFit.cover),
                    )
                  : Icon(icon, color: iconColor, size: 28),
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
