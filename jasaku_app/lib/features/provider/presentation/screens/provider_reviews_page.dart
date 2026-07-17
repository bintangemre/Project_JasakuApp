import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/image_url.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/utils/date_utils.dart';

class ProviderReviewsPage extends ConsumerStatefulWidget {
  const ProviderReviewsPage({super.key});

  @override
  ConsumerState<ProviderReviewsPage> createState() =>
      _ProviderReviewsPageState();
}

class _ProviderReviewsPageState extends ConsumerState<ProviderReviewsPage> {
  List<Map<String, dynamic>>? _reviews;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final res = await ApiClient().dio.get(
        '${ApiEndpoints.getProviderReviews}${user.id}',
      );
      final data = res.data['data'] as List<dynamic>? ?? [];
      setState(() {
        _reviews = data.map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ulasan Saya'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_off_rounded,
                      size: 48,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Gagal memuat ulasan',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchReviews,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              )
              : _reviews == null || _reviews!.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      size: 56,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Belum ada ulasan',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              )
              : RefreshIndicator(
                onRefresh: _fetchReviews,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  itemCount: _reviews!.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = _reviews![i];
                    final customer =
                        r['users_reviews_customer_idTousers']
                            as Map<String, dynamic>?;
                    final profile =
                        customer?['profiles_customer'] as Map<String, dynamic>?;
                    final name =
                        profile?['full_name']?.toString() ?? 'Pelanggan';
                    final avatar = profile?['avatar_url']?.toString();
                    final rating = r['rating'] as int? ?? 0;
                    final review = r['review'] as String?;
                    final createdAt = r['created_at'] as String?;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundImage:
                                avatar != null ? NetworkImage(imageUrl(avatar)) : null,
                            child:
                                avatar == null
                                    ? Icon(
                                      Icons.person,
                                      color: Colors.grey.shade400,
                                    )
                                    : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: List.generate(
                                    5,
                                    (j) => Icon(
                                      j < rating
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      size: 18,
                                      color: const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ),
                                if (review != null && review.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    review,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                                if (createdAt != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    AppDateUtils.formatShort(createdAt),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
    );
  }

}
