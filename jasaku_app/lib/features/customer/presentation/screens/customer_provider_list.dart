import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlong;
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/image_url.dart';
import '../../../../core/utils/operating_hours.dart';
import '../../../../core/utils/date_utils.dart';
import 'customer_orders.dart';
import 'customer_provider_reviews_page.dart';

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

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    final intVal = price is num ? price.toInt() : int.tryParse(price.toString()) ?? 0;
    final str = intVal.toString();
    final buf = StringBuffer();
    for (var i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return buf.toString();
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
          provider.distance = _formatDistance(meters);
        }
      }

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
      debugPrint("[ProviderList] DioError: ${e.response?.statusCode} ${e.message}");
      throw Exception(e.response?.data['message'] ?? e.message);
    } catch (e) {
      debugPrint("[ProviderList] Error: $e");
      throw Exception("Gagal memproses data dari server.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
            Text(
              servicesName,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [],
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
    final isDisabled = !provider.isActive;
    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            if (isDisabled)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: const Text(
                  'Sedang tidak tersedia',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Foto Profil Bulat Bersih
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: ClipOval(
                      child: Image.network(
                        provider.image != null && provider.image!.isNotEmpty
                            ? imageUrl(provider.image)
                            : 'https://ui-avatars.com/api/?name=N&background=DBEAFE&color=1E40AF',
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            width: 64,
                            height: 64,
                            color: const Color(0xFFF1F5F9),
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF94A3B8)),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          width: 64,
                          height: 64,
                          color: const Color(0xFFF1F5F9),
                          child: const Icon(Icons.person, color: Color(0xFF94A3B8), size: 32),
                        ),
                      ),
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
                              "${provider.location ?? ''}${provider.location != null ? ' • ' : ''}${provider.distance ?? '- km'}",
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
                            "${provider.rating?.toStringAsFixed(1) ?? '0.0'} ",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            "(${provider.totalReviews ?? 0} ulasan)  •  ",
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
                      'Rp ${_formatPrice(provider.basePrice)}',
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
    ),
  );
  }
}

// --- DETAIL MITRA BOTTOM SHEET (SINKRON FIGMA) ---
class DetailProviderSheet extends StatefulWidget {
  final ProviderModel provider;
  final String servicesId;

  const DetailProviderSheet({
    super.key,
    required this.provider,
    required this.servicesId,
  });

  @override
  State<DetailProviderSheet> createState() => _DetailProviderSheetState();
}

class _DetailProviderSheetState extends State<DetailProviderSheet> {
  bool _loadingStatus = true;
  bool _hasActiveOrder = false;
  bool _serviceAvailable = true;

  int _selectedTab = 0;
  List<Map<String, dynamic>>? _reviews;
  bool _loadingReviews = false;
  String? _errorReviews;

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchReviews() async {
    if (_reviews != null) return;
    setState(() => _loadingReviews = true);
    try {
      final res = await ApiClient().dio.get(
        '${ApiEndpoints.getProviderReviews}${widget.provider.id}',
      );
      final data = res.data['data'] as List<dynamic>? ?? [];
      setState(() {
        _reviews = data.map((e) => Map<String, dynamic>.from(e)).toList();
        _loadingReviews = false;
      });
    } catch (e) {
      setState(() {
        _errorReviews = e.toString();
        _loadingReviews = false;
      });
    }
  }

  Future<void> _fetchStatus() async {
    try {
      final res = await ApiClient().dio.get(
        ApiEndpoints.providerStatus(widget.provider.id),
      );
      final data = res.data['data'] as Map<String, dynamic>? ?? {};
      setState(() {
        _hasActiveOrder = data['hasActiveOrder'] == true;
        _serviceAvailable = data['is_active'] as bool? ?? true;
        _loadingStatus = false;
      });
    } catch (e) {
      debugPrint('[DetailProviderSheet] Status error: $e');
      setState(() => _loadingStatus = false);
    }
  }

  String _formatReviewDate(String iso) => AppDateUtils.formatShort(iso);

  Widget _buildReviewItem(Map<String, dynamic> r) {
    final customer = r['users_reviews_customer_idTousers'] as Map<String, dynamic>?;
    final profile = customer?['profiles_customer'] as Map<String, dynamic>?;
    final name = profile?['full_name']?.toString() ?? 'Pelanggan';
    final avatar = profile?['avatar_url']?.toString();
    final rating = r['rating'] as int? ?? 0;
    final review = r['review'] as String?;
    final createdAt = r['created_at'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: avatar != null ? NetworkImage(imageUrl(avatar)) : null,
            child: avatar == null ? Icon(Icons.person, color: Colors.grey.shade400, size: 20) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 3),
                Row(
                  children: List.generate(
                    5,
                    (j) => Icon(
                      j < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 16,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                ),
                if (review != null && review.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(review, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                ],
                if (createdAt != null) ...[
                  const SizedBox(height: 3),
                  Text(_formatReviewDate(createdAt), style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showScheduleDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final res = await ApiClient().dio.get(
        ApiEndpoints.providerSchedule(widget.provider.id),
      );
      final data = res.data['data'] as List<dynamic>? ?? [];
      final bookedDates = data.map((e) {
        final d = e['work_date'] as String;
        return DateTime.parse(d);
      }).toList();

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // tutup loading

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Jadwal Mitra'),
          content: SizedBox(
            width: double.maxFinite,
            child: bookedDates.isEmpty
                ? const Text('Tidak ada jadwal yang diboking')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: bookedDates.map((d) {
                      final months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
                      return ListTile(
                        leading: const Icon(Icons.calendar_today, color: Color(0xFF2563EB)),
                        title: Text('${d.day} ${months[d.month]} ${d.year}'),
                      );
                    }).toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // tutup loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memuat jadwal mitra')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
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
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: ClipOval(
                            child: Image.network(
                              provider.image != null && provider.image!.isNotEmpty
                            ? imageUrl(provider.image)
                                  : 'https://ui-avatars.com/api/?name=N&background=DBEAFE&color=1E40AF',
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                              loadingBuilder: (ctx, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  width: 72,
                                  height: 72,
                                  color: const Color(0xFFF1F5F9),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF94A3B8)),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (_, __, ___) => Container(
                                width: 72,
                                height: 72,
                                color: const Color(0xFFF1F5F9),
                                child: const Icon(Icons.person, color: Color(0xFF94A3B8), size: 36),
                              ),
                            ),
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
                                "${provider.location ?? ''}${provider.location != null ? ' • ' : ''}${provider.distance ?? '- km'}",
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
                    // Warning jika mitra tidak tersedia
                    if (!_loadingStatus && !_serviceAvailable) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Mitra sedang tidak tersedia',
                                style: TextStyle(
                                  color: Color(0xFF991B1B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Warning jika mitra sedang mengerjakan orderan hari ini
                    if (!_loadingStatus && _hasActiveOrder) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Color(0xFFDC2626), size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Tidak bisa order hari ini, silakan booking di hari lain',
                                style: TextStyle(
                                  color: Color(0xFF991B1B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Warning jam operasional
                    if (!_loadingStatus && !OperatingHours.isWithinOperatingHours()) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFD6A8)),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.access_time, color: Color(0xFFE67E22), size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Anda sedang di luar jam operasional (08:00-16:00 WITA), silahkan cek jadwal penyedia jasa',
                                style: TextStyle(
                                  color: Color(0xFF9C6B3E),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                            "${provider.totalReviews ?? 0}",
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
                    if (provider.isActive)
                      const Row(
                        children: [
                          Icon(
                            Icons.verified_user,
                            size: 16,
                            color: Color(0xFF2563EB),
                          ),
                          Text(
                            " Terverifikasi",
                            style: TextStyle(
                              color: Color(0xFF2563EB),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    // Navigasi Tab (Info, Ulasan)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _selectedTab = 0),
                          child: Text(
                            "Info",
                            style: TextStyle(
                              color: _selectedTab == 0
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF94A3B8),
                              fontWeight: _selectedTab == 0
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              decoration: _selectedTab == 0
                                  ? TextDecoration.underline
                                  : null,
                              decorationThickness: 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                        GestureDetector(
                          onTap: () {
                            setState(() => _selectedTab = 1);
                            _fetchReviews();
                          },
                          child: Text(
                            "Ulasan",
                            style: TextStyle(
                              color: _selectedTab == 1
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF94A3B8),
                              fontWeight: _selectedTab == 1
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              decoration: _selectedTab == 1
                                  ? TextDecoration.underline
                                  : null,
                              decorationThickness: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // ═══ TAB INFO ═══
                    if (_selectedTab == 0) ...[
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
                      if (provider.portfolios.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          "Portofolio",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 100,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: provider.portfolios.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, i) {
                              final url = provider.portfolios[i];
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: GestureDetector(
                                  onTap: () => _showImagePreview(context, url),
                                  child: Image.network(
                                    imageUrl(url),
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (ctx, child, progress) {
                                      if (progress == null) return child;
                                      return Container(
                                        width: 100,
                                        height: 100,
                                        color: const Color(0xFFF1F5F9),
                                        child: const Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF94A3B8)),
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 100,
                                      height: 100,
                                      color: const Color(0xFFF1F5F9),
                                      child: const Icon(Icons.broken_image, color: Color(0xFF94A3B8)),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Menu Jadwal Mitra
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.calendar_month_outlined,
                              color: Color(0xFF2563EB),
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'Jadwal Mitra',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Lihat jadwal yang sudah dibooking',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF94A3B8),
                          ),
                          onTap: _showScheduleDialog,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    // ═══ TAB ULASAN ═══
                    if (_selectedTab == 1) ...[
                      if (_loadingReviews) ...[
                        const SizedBox(height: 40),
                        const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
                      ] else if (_errorReviews != null) ...[
                        const SizedBox(height: 40),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.cloud_off_rounded, size: 40, color: Colors.grey.shade300),
                              const SizedBox(height: 8),
                              Text('Gagal memuat ulasan', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () { setState(() { _errorReviews = null; _reviews = null; }); _fetchReviews(); },
                                child: const Text('Coba Lagi'),
                              ),
                            ],
                          ),
                        ),
                      ] else if (_reviews == null || _reviews!.isEmpty) ...[
                        const SizedBox(height: 40),
                        Center(
                          child: Column(
                            children: [
                              Icon(Icons.rate_review_outlined, size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 8),
                              Text('Belum ada ulasan', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                      ] else ...[
                        for (final r in _reviews!.take(3)) ...[
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CustomerProviderReviewsPage(
                                    providerId: widget.provider.id,
                                    providerName: widget.provider.name,
                                  ),
                                ),
                              );
                            },
                            child: _buildReviewItem(r),
                          ),
                        ],
                        if (_reviews!.length > 3) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CustomerProviderReviewsPage(
                                    providerId: widget.provider.id,
                                    providerName: widget.provider.name,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  'Lihat Semua Ulasan (${_reviews!.length})',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                      ],
                    ],
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
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (_hasActiveOrder || !_serviceAvailable || !OperatingHours.isWithinOperatingHours())
                              ? null
                              : () {
                                  if (provider.pricingUnitId == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Tidak dapat memproses pesanan: pricing unit tidak tersedia.',
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
                                            serviceId: widget.servicesId,
                                            pricingUnitId: provider.pricingUnitId!,
                                            contractTypeId: provider.contractTypeId,
                                            basePrice:
                                                provider.basePrice?.toDouble() ?? 0.0,
                                          ),
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: (_hasActiveOrder || !_serviceAvailable || !OperatingHours.isWithinOperatingHours())
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            !_serviceAvailable
                                ? "Sedang Tidak Tersedia"
                                : _hasActiveOrder
                                    ? "Sedang Sibuk"
                                    : !OperatingHours.isWithinOperatingHours()
                                        ? "Di Luar Jam Operasional"
                                        : "Pesan Sekarang",
                            style: const TextStyle(
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

  void _showImagePreview(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: InteractiveViewer(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl(url),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 48),
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
          ),
        ),
      ),
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
  final String? pricingUnitId;
  final String? contractTypeId;
  final bool withMaterial;
  final int? totalReviews;
  final int? experience;
  final String? aboutMe;
  final List<String> portfolios;
  final double? lat;
  final double? lng;
  final bool isActive;

  ProviderModel({
    required this.id,
    required this.name,
    this.image,
    this.location,
    this.distance,
    this.rating,
    this.jobsDone,
    this.basePrice,
    this.pricingUnitId,
    this.contractTypeId,
    this.withMaterial = false,
    this.totalReviews,
    this.experience,
    this.aboutMe,
    this.portfolios = const [],
    this.lat,
    this.lng,
    this.isActive = true,
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

    final pricingUnitIdRaw =
        priceData?['pricing_unit_id'] ?? priceData?['pricingUnitId'];
    final pricingUnitId = pricingUnitIdRaw?.toString();

    final contractTypeIdRaw = priceData?['contract_type_id'];
    final contractTypeId = contractTypeIdRaw?.toString();

    final withMaterial = priceData?['plus_material'] == true;

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

    // ✅ Parse total_reviews secara aman
    int? parsedReviews;
    final reviewsRaw = profileData?['total_reviews'];
    if (reviewsRaw != null) {
      parsedReviews =
          reviewsRaw is num ? reviewsRaw.toInt() : int.tryParse(reviewsRaw.toString());
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

    // ✅ Parse portfolios
    final portfoliosRaw = profileData?['portfolios'] as List<dynamic>?;

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
      totalReviews: parsedReviews,
      basePrice: parsedPrice,
      pricingUnitId: pricingUnitId,
      contractTypeId: contractTypeId,
      withMaterial: withMaterial,
      portfolios: portfoliosRaw?.map((e) => e.toString()).toList() ?? [],
      experience: parsedExperience,
      aboutMe:
          json['description']?.toString() ??
          serviceData?['description']?.toString() ??
          'Deskripsi belum tersedia',
      lat: parsedLat,
      lng: parsedLng,
      isActive: profileData?['is_active'] as bool? ?? true,
    );
  }
}
