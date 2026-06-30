import 'package:flutter/material.dart';

class ProviderVerificationPendingScreen extends StatelessWidget {
  final String status; // 'pending' | 'rejected'

  const ProviderVerificationPendingScreen({
    super.key,
    this.status = 'pending',
  });

  @override
  Widget build(BuildContext context) {
    final isRejected = status == 'rejected';
    return Scaffold(
      backgroundColor: isRejected ? const Color(0xFFFEF2F2) : const Color(0xFFFFF7ED),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isRejected ? Icons.cancel_outlined : Icons.access_time_rounded,
                  size: 80,
                  color: isRejected ? const Color(0xFFDC2626) : const Color(0xFFF59E0B),
                ),
                const SizedBox(height: 24),
                Text(
                  isRejected ? 'Akun Ditolak' : 'Akun Belum Diverifikasi',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  isRejected
                      ? 'Maaf, akun Anda ditolak oleh tim admin.\nSilakan hubungi kami untuk informasi lebih lanjut.'
                      : 'Akun Anda masih dalam proses verifikasi oleh tim admin.\n\nKami akan memberi tahu setelah akun Anda diverifikasi.\nSilakan login kembali setelah menerima notifikasi.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Kembali',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
