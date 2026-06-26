// customer_providers_by_category.dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
// 1. Pastikan mengimpor file tujuan navigasi kamu di sini
import 'customer_provider_list.dart'; 

class CustomerProvidersByCategory extends ConsumerWidget {
  final String categoryId;
  final String categoryName;

  const CustomerProvidersByCategory({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  Future<CategoryWithServices> _fetchCategoryServices() async {
    try {
      final response = await ApiClient().dio.get(
        '${ApiEndpoints.getCategoriesByid}$categoryId',
      );
      final data = response.data['data'] as Map<String, dynamic>;
      return CategoryWithServices.fromJson(data);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? e.message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: FutureBuilder<CategoryWithServices>(
        future: _fetchCategoryServices(),
        builder: (context, snapshot) {
          // Kondisi 1: Menunggu Jaringan (Loading)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Kondisi 2: Terjadi Gangguan/Error
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: Text(categoryName), leading: const BackButton()),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text('Terjadi kesalahan: ${snapshot.error}', style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ),
              ),
            );
          }

          final category = snapshot.data;

          // Kondisi 3: Data Kosong
          if (category == null || category.services.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: Text(categoryName), leading: const BackButton()),
              body: Center(
                child: Text('Tidak ada layanan di kategori "$categoryName".', style: const TextStyle(color: Colors.grey)),
              ),
            );
          }

          // Kondisi 4: Sukses (Merakit UI Sesuai Gambar Referensi)
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ORANYE LAYANAN (PERSIS SEPERTI DI GAMBAR) ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 50, bottom: 32, left: 20, right: 20),
                decoration: const BoxDecoration(
                  color: Colors.orange, // Menggunakan warna dasar oranye tema Jasaku
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tombol Kembali Custom
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back, color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text("Kembali", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Judul Kategori & Sub-deskripsi
                    Row(
                      children: [
                        // Kotak Putih Tempat Icon Kategori
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.construction, color: Colors.white, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.name, // Diambil dinamis dari database
                                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                "Renovasi, konstruksi, dan perbaikan bangunan",
                                style: TextStyle(color: Colors.white, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // --- SUB-TEKS INSTRUKSI PILIHAN ---
              const Padding(
                padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 12),
                child: Text(
                  "Pilih keahlian yang Anda butuhkan\nuntuk melihat daftar mitra tersedia",
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.4),
                ),
              ),

              // --- LIST CONTAINER DAFTAR LAYANAN (GAMBAR REFERENSI) ---
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: category.services.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final service = category.services[index];

                    // Bungkus kartu dengan InkWell agar bisa diklik menuju halaman provider
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          // --- NAVIGASI JALUR ESTAFET DATA MENUJU SCREEN B ---
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => ProviderListScreen(
                                servicesId: service.id,       // Mengirimkan ID layanan
                                servicesName: service.name,   // Mengirimkan nama layanan
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              // Tempat Icon Dummy di Sisi Kiri
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(
                                  index % 2 == 0 ? Icons.construction : Icons.engineering, 
                                  color: Colors.amber.shade700, 
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              
                              // Informasi Judul dan Deskripsi Layanan
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      service.name,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      service.description ?? 'Tenaga ahli untuk kebutuhan Anda.',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.3),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              
                              // Tanda Panah Navigasi Abu-abu di Sisi Kanan
                              const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1), size: 24),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// --- MODEL DATA (TETAP SAMA SEPERTI KODE LAMA KAMU) ---
class CategoryWithServices {
  final String id;
  final String name;
  final List<CategoryService> services;

  CategoryWithServices({
    required this.id,
    required this.name,
    required this.services,
  });

  factory CategoryWithServices.fromJson(Map<String, dynamic> json) {
    return CategoryWithServices(
      id: json['id'] as String,
      name: json['name'] as String,
      services: (json['services'] as List<dynamic>?)
              ?.map((item) => CategoryService.fromJson(item as Map<String, dynamic>))
              .toList() ?? [],
    );
  }
}

class CategoryService {
  final String id;
  final String name;
  final String? description;

  CategoryService({required this.id, required this.name, this.description});

  factory CategoryService.fromJson(Map<String, dynamic> json) {
    return CategoryService(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
    );
  }
}