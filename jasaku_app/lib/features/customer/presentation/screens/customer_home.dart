// Screen customer home yang menampilkan greeting dan summary sederhana.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class CustomerHome extends ConsumerWidget {
  const CustomerHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final userName = authState.user?.displayName ?? 'Customer';
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: const BoxDecoration(
              color: Color(0xFF2563EB),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
            ),

            child: Column(
              children: [
                // TOP ROW
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Halo, $userName!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          'Apa yang bisa kami bantu hari ini?',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                      ],
                    ),

                    GestureDetector(
                      onTap: () {
                        // tombol profile tetap nanti kamu isi sendiri
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
                

                const SizedBox(height: 28),

                // MENU BUTTONS
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),

                        child: const Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Color(0xFFE0E7FF),
                              child: Icon(
                                Icons.search,
                                color: Color(0xFF2563EB),
                              ),
                            ),

                            SizedBox(width: 12),

                            Expanded(
                              child: Text(
                                'Cari\nJasa',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 18,
                          horizontal: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),

                        child: const Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: Color(0xFFDCFCE7),
                              child: Icon(Icons.add, color: Color(0xFF16A34A)),
                            ),

                            SizedBox(width: 12),

                            Expanded(
                              child: Text(
                                'Custom\nTask',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
           Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              const SizedBox(height: 28),
                
          // KATEGORI HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Kategori Jasa',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),

              Text(
                'Lihat Semua',
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // KATEGORI LIST
          Row(
            children: [
              Expanded(
                child: _buildCategoryCard(
                  icon: Icons.home_repair_service,
                  iconColor: Color(0xFFFF6B00),
                  bgColor: Color(0xFFFFEDD5),
                  title: 'Perbaikan\nBangunan',
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: _buildCategoryCard(
                  icon: Icons.bolt,
                  iconColor: Color(0xFFD4A100),
                  bgColor: Color(0xFFFEF3C7),
                  title: 'Perbaikan\nKelistrikan',
                ),
              ),
            ],
          ),

          const SizedBox(height: 36),

          // PESANAN HEADER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Pesanan Terbaru',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),

              Text(
                'Lihat Semua',
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ORDER CARD 1
          _buildOrderCard(
            title: 'Perbaikan AC',
            customer: 'Ahmad Rizki',
            date: '20/2/2026',
            status: 'Selesai',
            statusColor: Color(0xFF16A34A),
            statusBg: Color(0xFFDCFCE7),
          ),

          const SizedBox(height: 16),

          // ORDER CARD 2
          _buildOrderCard(
            title: 'Angkut Barang',
            customer: 'Siti Nur',
            date: '24/2/2026',
            status: 'Dalam Proses',
            statusColor: Color(0xFFD97706),
            statusBg: Color(0xFFFEF3C7),
          ),

          const SizedBox(height: 20),
            ],
          ),
        ),
      ]
    ),
  );
}

  // CATEGORY CARD
  Widget _buildCategoryCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),

      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: iconColor, size: 30),
          ),

          const SizedBox(height: 16),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ORDER CARD
  Widget _buildOrderCard({
    required String title,
    required String customer,
    required String date,
    required String status,
    required Color statusColor,
    required Color statusBg,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Text(
            customer,
            style: const TextStyle(color: Colors.black54, fontSize: 16),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              const Icon(Icons.access_time, size: 18, color: Colors.grey),

              const SizedBox(width: 6),

              Text(date, style: const TextStyle(color: Colors.grey)),

              const Spacer(),

              const Text(
                'Beri Rating☆',
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
