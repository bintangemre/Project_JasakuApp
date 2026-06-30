import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlong;
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import 'customer_orders.dart';

/*class Providerlist extends StatelessWidget {
  final String servicesId;
  final String servicesName;

  const Providerlist({
    super.key,
    required this.servicesId,
    required this.servicesName,
  });

  // ini untuk ambil api list provider terdekat dari lokasi karena ini ambil lokasi provider. provider mengaktifkan lokasi agar data lokasi masuk begitu pula pada customer
  /* Future<Providerlist> _fetchProviderList () async {
    try {
      final response = await ApiClient ().dio.get (
        '${ApiEndpoints.getProviderByService}$servicesId',
      );
        final data = response.data['data'] as Map<String, dynamic>;
        return Providerlist.fromJson(data);
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? e.message);
    }
  }
  */

  // sementara untuk lihat tampilan nya
  Future<List<ProviderModel>> _fetchProviderList() async {
    try {
      // 1. Fungsi dio.get langsung ditutup dengan kurung ) setelah URL selesai
      final response = await ApiClient().dio.get(
        '${ApiEndpoints.getProvidersByServiceWithoutDistance}$servicesId',
      );

      // 2. Proses membaca data dipisahkan di bawahnya
      final data = response.data['data'] as List<dynamic>;

      // 3. Mengembalikan dalam bentuk List data ProviderModel
      return data
          .map((item) => ProviderModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw Exception(e.response?.data['message'] ?? e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Daftar Tukang $servicesName'),
      ),
      body: const Center(
        child: Text('Gunakan FutureBuilder di sini untuk menampilkan daftar tukang'),
      ),
    );
  }
}
  class ProviderModel {
    final String id;
    final String name;

    ProviderModel({required this.id, required this.name});

  factory ProviderModel.fromJson(Map<String, dynamic> json) {
    return ProviderModel(
      id: json['id'] as String,
      name: json['name'] as String, // sesuaikan dengan field database/backend kamu
    );
  }
}
*/

// --- SCREEN UTAMA: DAFTAR MITRA DARI DATABASE (GAMBAR 1) ---
class ProviderListScreen extends StatelessWidget {
  final String servicesId;
  final String servicesName;

  const ProviderListScreen({
    super.key,
    required this.servicesId,
    required this.servicesName,
  });

  Future<Position> _getCurrentLocation() async {
    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw Exception('Layanan lokasi tidak aktif. Aktifkan GPS.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Izin lokasi ditolak.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Izin lokasi ditolak permanen. Atur di pengaturan perangkat.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Future<List<ProviderModel>> _fetchProviderList() async {
    try {
      final response = await ApiClient().dio.get(
        '${ApiEndpoints.getProvidersByServiceWithoutDistance}/$servicesId',
      );

      if (response.data == null || response.data['data'] == null) {
        return [];
      }

      List<ProviderModel> providers;

      if (response.data['data'] is! List) {
        if (response.data['data'] is Map<String, dynamic>) {
          providers = [
            ProviderModel.fromJson(
              response.data['data'] as Map<String, dynamic>,
            ),
          ];
        } else {
          return [];
        }
      } else {
        final dataList = response.data['data'] as List<dynamic>;
        providers = dataList
            .map((item) {
              try {
                return ProviderModel.fromJson(item as Map<String, dynamic>);
              } catch (e) {
                debugPrint("Gagal parsing satu item provider: $e");
                return null;
              }
            })
            .whereType<ProviderModel>()
            .toList();
      }

      Position? userPos;
      try {
        userPos = await _getCurrentLocation();
      } catch (e) {
        debugPrint("Gagal mendapat lokasi: $e");
        return providers;
      }

      final distanceCalc = latlong.Distance();
      final userLatLng = latlong.LatLng(userPos.latitude, userPos.longitude);

      for (final provider in providers) {
        if (provider.lat != null && provider.lng != null) {
          final providerLatLng =
              latlong.LatLng(provider.lat!, provider.lng!);
          final meters = distanceCalc.as(
            latlong.LengthUnit.Meter,
            userLatLng,
            providerLatLng,
          );
          final distance = (provider.distance = _formatDistance(meters));
          debugPrint("Jarak ke ${provider.name}: $distance");
        }
      }

      providers.sort((a, b) {
        if (a.distance == null && b.distance == null) return 0;
        if (a.distance == null) return 1;
        if (b.distance == null) return -1;
        return 0;
      });

      providers.sort((a, b) {
        if (a.lat == null || a.lng == null) return 1;
        if (b.lat == null || b.lng == null) return -1;
        final distA = distanceCalc.as(
            latlong.LengthUnit.Meter, userLatLng, latlong.LatLng(a.lat!, a.lng!));
        final distB = distanceCalc.as(
            latlong.LengthUnit.Meter, userLatLng, latlong.LatLng(b.lat!, b.lng!));
        return distA.compareTo(distB);
      });

      return providers;
    } on DioException catch (e) {
      debugPrint("=== DIO ERROR ===");
      debugPrint("URL: ${e.requestOptions.uri}");
      debugPrint("Status: ${e.response?.statusCode}");
      debugPrint("Data: ${e.response?.data}");
      debugPrint("Message: ${e.message}");
      throw Exception(e.response?.data['message'] ?? e.message);
    } catch (e) {
      debugPrint("=== GENERAL ERROR: $e ===");
      throw Exception("Gagal memproses data dari server.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              servicesName,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.w700, // Font tebal sesuai figma
                fontFamily:
                    'PlusJakartaSans', // Jika proyekmu memakai font custom
              ),
            ),
            const Text(
              "Bangunan & Konstruksi",
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 10, bottom: 10),
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(
                Icons.tune_rounded,
                size: 16,
                color: Color(0xFF1E293B),
              ),
              label: const Text(
                "Urutkan",
                style: TextStyle(
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
        ],
      ),
      body: FutureBuilder<List<ProviderModel>>(
        future: _fetchProviderList(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.blue),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Gagal memuat data:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final providers = snapshot.data ?? [];

          if (providers.isEmpty) {
            return const Center(
              child: Text(
                'Tidak ada mitra/tukang yang tersedia untuk layanan ini.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: providers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final provider = providers[index];
              return _buildProviderCard(context, provider);
            },
          );
        },
      ),
    );
  }

  // --- WIDGET KARTU MITRA (UI POLISH SESUAI FIGMA) ---
  Widget _buildProviderCard(BuildContext context, ProviderModel provider) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Foto Profil Bulat Bersih
                CircleAvatar(
                  radius: 32,
                  backgroundColor: const Color(0xFFF1F5F9),
                  backgroundImage: NetworkImage(
                    provider.image ??
                        'https://ui-avatars.com/api/?name=${provider.name}&background=DBEAFE&color=1E40AF',
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Baris Nama + Badge Verifikasi Samping Nama (Figma Style)
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              provider.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: Color(0xFF10B981),
                          ), // Badge Hijau Terverifikasi
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Baris Lokasi
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              "${provider.location ?? 'Lokasi tidak diatur'} • ${provider.distance ?? '- km'}",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Baris Rating & Total Pekerjaan
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Color(0xFFF59E0B),
                          ), // Bintang Oranye Emas
                          const SizedBox(width: 4),
                          Text(
                            "${provider.rating ?? '0.0'} ",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            "(312 ulasan)  •  ",
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Icon(
                            Icons.work_outline_rounded,
                            size: 14,
                            color: Color(0xFF3B82F6),
                          ), // Ikon koper kerja
                          const SizedBox(width: 4),
                          Text(
                            "${provider.jobsDone ?? 0} Selesai",
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          // Baris Informasi Harga & Aksi Profil
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mulai dari',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Rp ${provider.basePrice ?? '0'}',
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder:
                          (context) => DetailProviderSheet(
                            provider: provider,
                            servicesId: servicesId,
                          ),
                    );
                  },
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: const Row(
                    children: [
                      Text(
                        "Lihat Profil",
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: Color(0xFF2563EB),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- DETAIL MITRA BOTTOM SHEET (SINKRON FIGMA) ---
class DetailProviderSheet extends StatelessWidget {
  final ProviderModel provider;
  final String servicesId;

  const DetailProviderSheet({
    super.key,
    required this.provider,
    required this.servicesId,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // Pill Handle Bar Atas
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Header Informasi Utama Profil
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: const Color(0xFFF1F5F9),
                          backgroundImage: NetworkImage(
                            provider.image ??
                                'https://ui-avatars.com/api/?name=${provider.name}&background=DBEAFE&color=1E40AF',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      provider.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.verified_rounded,
                                    size: 18,
                                    color: Color(0xFF10B981),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${provider.location ?? 'Lokasi tidak diset'} • ${provider.distance ?? '- km'}",
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Baris Statistik/Metrik (Rating, Ulasan, Job, Pengalaman)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItemRow(
                            Icons.star_rounded,
                            provider.rating?.toString() ?? '0.0',
                            "Rating",
                            const Color(0xFFF59E0B),
                          ),
                          _buildStatItemRow(
                            Icons.rate_review_outlined,
                            "312",
                            "Ulasan",
                            const Color(0xFF64748B),
                          ),
                          _buildStatItemRow(
                            Icons.work_outline_rounded,
                            "${provider.jobsDone ?? 0}",
                            "Job",
                            const Color(0xFF3B82F6),
                          ),
                          _buildStatItemRow(
                            Icons.history_toggle_off_rounded,
                            "${provider.experience ?? 0} thn",
                            "Pengalaman",
                            const Color(0xFF10B981),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Atribut Kelebihan / Jaminan Layanan
                    const Row(
                      children: [
                        Icon(
                          Icons.bolt_rounded,
                          size: 16,
                          color: Color(0xFF10B981),
                        ),
                        Text(
                          " Respons kilat < 10 mnt   ",
                          style: TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Icon(
                          Icons.verified_user,
                          size: 16,
                          color: Color(0xFF2563EB),
                        ),
                        Text(
                          " Terverifikasi Asli",
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Navigasi Tab (Info, Katalog, Alat, Ulasan)
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          "Info",
                          style: TextStyle(
                            color: Color(0xFF2563EB),
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationThickness: 2,
                          ),
                        ),
                        Text(
                          "Katalog",
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          "Alat",
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          "Ulasan",
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Tentang Mitra",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.aboutMe ??
                          "Deskripsi tentang mitra belum diisi oleh provider.",
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        height: 1.5,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
              // Bagian Bawah yang Melayang Statis (Tombol Chat & Order)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: const Border(
                    top: BorderSide(color: Color(0xFFF1F5F9)),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Color(0xFF2563EB),
                            size: 24,
                          ),
                          onPressed: () {},
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (provider.pricingTypeId == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Tidak dapat memproses pesanan: pricing type tidak tersedia.',
                                  ),
                                ),
                              );
                              return;
                            }

                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => CustomerOrdersPage(
                                      providerId: provider.id,
                                      providerName: provider.name,
                                      serviceId: servicesId,
                                      pricingTypeId: provider.pricingTypeId!,
                                      basePrice:
                                          provider.basePrice?.toDouble() ?? 0.0,
                                    ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            "Pesan Sekarang",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Komponen Statistik dengan Susunan Rapi Ber-ikon
  Widget _buildStatItemRow(
    IconData icon,
    String value,
    String label,
    Color iconColor,
  ) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// --- MODEL DATA: PROVIDER MODEL (SUDAH FIXED TOTAL) ---
class ProviderModel {
  final String id;
  final String name;
  final String? image;
  final String? location;
  String? distance;
  final double? rating;
  final int? jobsDone;
  final int? basePrice;
  final String? pricingTypeId;
  final int? experience;
  final String? aboutMe;
  final double? lat;
  final double? lng;

  ProviderModel({
    required this.id,
    required this.name,
    this.image,
    this.location,
    this.distance,
    this.rating,
    this.jobsDone,
    this.basePrice,
    this.pricingTypeId,
    this.experience,
    this.aboutMe,
    this.lat,
    this.lng,
  });

  factory ProviderModel.fromJson(Map<String, dynamic> json) {
    final providerProfilesList = json['provider_profiles'] as List<dynamic>?;
    final profileData =
        providerProfilesList != null && providerProfilesList.isNotEmpty
            ? providerProfilesList.first as Map<String, dynamic>
            : null;

    final userData = profileData?['users'] as Map<String, dynamic>?;

    final locationsList = profileData?['provider_locations'] as List<dynamic>?;
    final locationData =
        locationsList != null && locationsList.isNotEmpty
            ? locationsList.first as Map<String, dynamic>
            : null;

    final pricesList =
        profileData?['provider_service_prices'] as List<dynamic>?;
    final priceData =
        pricesList != null && pricesList.isNotEmpty
            ? pricesList.first as Map<String, dynamic>
            : null;

    final serviceData = json['services'] as Map<String, dynamic>?;

    final pricingTypeIdRaw =
        priceData?['pricing_type_id'] ?? priceData?['pricingTypeId'];
    final pricingTypeId = pricingTypeIdRaw?.toString();

    // ✅ Parse rating secara aman
    double? parsedRating;
    final ratingRaw = profileData?['rating'];
    if (ratingRaw != null) {
      parsedRating = double.tryParse(ratingRaw.toString());
    }

    // ✅ Parse price secara aman
    int? parsedPrice;
    final priceRaw = priceData?['price'];
    if (priceRaw != null) {
      parsedPrice =
          priceRaw is num
              ? priceRaw.toInt()
              : int.tryParse(priceRaw.toString());
    }

    // ✅ Parse total_jobs secara aman
    int? parsedJobs;
    final jobsRaw = profileData?['total_jobs'];
    if (jobsRaw != null) {
      parsedJobs =
          jobsRaw is num ? jobsRaw.toInt() : int.tryParse(jobsRaw.toString());
    }

    // ✅ FIX UTAMA: Parse experience secara aman (bisa datang sebagai String "5" dari backend)
    int? parsedExperience;
    final expRaw = profileData?['experience'];
    if (expRaw != null) {
      parsedExperience =
          expRaw is num ? expRaw.toInt() : int.tryParse(expRaw.toString());
    }

    final parsedLat = (locationData?['lat'] as num?)?.toDouble();
    final parsedLng = (locationData?['lng'] as num?)?.toDouble();

    return ProviderModel(
      id:
          profileData?['provider_id']?.toString() ??
          json['provider_id']?.toString() ??
          '',
      name:
          userData?['full_name']?.toString() ??
          serviceData?['name']?.toString() ??
          'Mitra Jasaku',
      image: userData?['profile_photo'] as String?,
      location: locationData?['address'] as String?,
      distance: null,
      rating: parsedRating ?? (json['rating'] as num?)?.toDouble(),
      jobsDone: parsedJobs,
      basePrice: parsedPrice,
      pricingTypeId: pricingTypeId,
      experience: parsedExperience,
      aboutMe:
          json['description']?.toString() ??
          serviceData?['description']?.toString() ??
          'Deskripsi belum tersedia',
      lat: parsedLat,
      lng: parsedLng,
    );
  }
}
