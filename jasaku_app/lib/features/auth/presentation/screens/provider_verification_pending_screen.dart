import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../../provider/presentation/screens/provider_edit_resubmission_screen.dart';

class ProviderVerificationPendingScreen extends ConsumerWidget {
  final String status;

  const ProviderVerificationPendingScreen({
    super.key,
    this.status = 'pending',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRejected = status == 'rejected';
    final authState = ref.watch(authProvider);
    final parsed = _parseChecklist(authState.verificationNotes);

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
            child: SingleChildScrollView(
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
                        ? 'Maaf, akun Anda ditolak oleh tim admin.'
                        : 'Akun Anda masih dalam proses verifikasi oleh tim admin.\n\nKami akan memberi tahu setelah akun Anda diverifikasi.\nSilakan login kembali setelah menerima notifikasi.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (isRejected && parsed != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hasil Verifikasi Admin',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF374151),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...parsed.checklist.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  item.status == 'passed'
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  size: 18,
                                  color: item.status == 'passed'
                                      ? const Color(0xFF059669)
                                      : const Color(0xFFDC2626),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.label,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF374151),
                                        ),
                                      ),
                                      if (item.status == 'failed' && item.note != null && item.note!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            item.note!,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFFDC2626),
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )),
                          if (parsed.notes.isNotEmpty) ...[
                            const Divider(height: 4),
                            const SizedBox(height: 6),
                            Text(
                              'Catatan: ${parsed.notes}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  if (isRejected && parsed == null && authState.verificationNotes != null && authState.verificationNotes!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Alasan: ${authState.verificationNotes}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF991B1B),
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  if (isRejected) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const ProviderEditResubmissionScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit, size: 20),
                        label: const Text(
                          'Perbaiki Data',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFFECACA)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final loading = ref.read(authProvider).isLoading;
                          if (loading) return;
                          final ok = await ref
                              .read(authProvider.notifier)
                              .resubmitVerification();
                          if (!context.mounted) return;
                          if (ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Pengajuan ulang berhasil dikirim. Silakan tunggu verifikasi admin.'),
                              ),
                            );
                            if (!context.mounted) return;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const ProviderVerificationPendingScreen(
                                        status: 'pending'),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    ref.read(authProvider).error ??
                                        'Gagal mengajukan ulang'),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'Ajukan Ulang Langsung',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/login'),
                      child: const Text(
                        'Nanti saja',
                        style: TextStyle(color: Colors.black45),
                      ),
                    ),
                  ] else ...[
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
                        onPressed: () =>
                            Navigator.pushReplacementNamed(context, '/login'),
                        child: const Text(
                          'Kembali',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _ChecklistData? _parseChecklist(String? notes) {
    if (notes == null || notes.isEmpty) return null;
    try {
      final json = jsonDecode(notes) as Map<String, dynamic>;
      final list = (json['checklist'] as List?)?.map((item) {
        final m = item as Map<String, dynamic>;
        return _ChecklistItem(
          label: _labelFor(m['item'] as String? ?? ''),
          status: m['status'] as String? ?? 'passed',
          note: m['note'] as String?,
        );
      }).toList();
      if (list == null || list.isEmpty) return null;
      return _ChecklistData(
        checklist: list,
        notes: json['notes'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  String _labelFor(String itemId) {
    const labels = {
      'full_name': 'Nama lengkap sesuai KTP',
      'profile_photo': 'Foto profil wajar dan sesuai',
      'ktp_photo': 'Foto KTP jelas dan terbaca',
      'selfie': 'Selfie sesuai KTP (face match)',
      'documents': 'Dokumen ijazah/sertifikat jelas',
      'phone': 'Nomor telepon valid',
      'address': 'Alamat domisili valid',
      'services': 'Layanan sesuai keahlian',
    };
    return labels[itemId] ?? itemId;
  }
}

class _ChecklistItem {
  final String label;
  final String status;
  final String? note;
  const _ChecklistItem({
    required this.label,
    required this.status,
    this.note,
  });
}

class _ChecklistData {
  final List<_ChecklistItem> checklist;
  final String notes;
  const _ChecklistData({
    required this.checklist,
    required this.notes,
  });
}