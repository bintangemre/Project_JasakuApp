import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../data/custom_tasks_repository.dart';
import '../../data/models/custom_task_model.dart';
import '../../../../core/constants/api_endpoints.dart';

class CustomerPaymentPage extends ConsumerStatefulWidget {
  final String taskId;
  const CustomerPaymentPage({super.key, required this.taskId});

  @override
  ConsumerState<CustomerPaymentPage> createState() => _CustomerPaymentPageState();
}

class _CustomerPaymentPageState extends ConsumerState<CustomerPaymentPage> {
  final _repo = CustomTasksRepository();
  PaymentDetailModel? _payment;
  bool _loading = true;
  String? _error;
  File? _proofFile;
  bool _uploading = false;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _payment = await _repo.getPaymentDetail(widget.taskId);
    } catch (e) {
      if (e is DioException && e.response?.data is Map) {
        _error = (e.response!.data as Map)['message']?.toString() ?? e.toString();
      } else {
        _error = e.toString();
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickProof() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200);
    if (picked != null) {
      setState(() => _proofFile = File(picked.path));
    }
  }

  Future<void> _submitProof() async {
    if (_proofFile == null) return;
    setState(() => _uploading = true);
    try {
      await _repo.uploadPaymentProof(widget.taskId, _proofFile!);
      setState(() => _success = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bukti pembayaran berhasil dikirim!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat('#,###', 'id_ID');
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Pembayaran Task'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _success
                  ? _buildSuccess()
                  : _buildContent(f),
    );
  }

  Widget _buildContent(NumberFormat f) {
    final p = _payment!;
    final isPaid = p.paymentStatus == 'paid';
    final isProofUploaded = p.paymentStatus == 'proof_uploaded';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status banner
          if (isPaid)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF10B981), size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Pembayaran sudah dikonfirmasi admin',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF065F46))),
                  ),
                ],
              ),
            )
          else if (isProofUploaded)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hourglass_top, color: Color(0xFFF59E0B), size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Bukti sudah dikirim. Menunggu konfirmasi admin.',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF92400E))),
                  ),
                ],
              ),
            ),

          if (!isPaid) ...[
            const SizedBox(height: 16),
            ...[
              _buildSection('Ringkasan Task', [
                _row('Judul', p.title),
                _row('Provider', '${p.acceptedCount} dari ${p.requiredPeople} orang'),
              ]),
              const SizedBox(height: 12),
              _buildSection('Rincian Biaya', [
                _row('Budget per orang', 'Rp ${f.format(p.budgetPerPerson.toInt())}'),
                _row('Fee aplikasi per orang', 'Rp ${f.format(p.feePerPerson.toInt())}'),
                _row('Jumlah provider', '${p.acceptedCount} orang'),
                const Divider(height: 16),
                _row('Total dibayar', 'Rp ${f.format(p.totalAmount.toInt())}', bold: true),
              ]),
              const SizedBox(height: 12),
              _buildSection('Admin Rekber', [
                const Text('Transfer ke salah satu rekening admin di bawah ini:',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 12),
                ...p.adminAccounts.map((a) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: a.type == 'bank'
                                  ? const Color(0xFFEFF6FF)
                                  : a.type == 'qris'
                                      ? const Color(0xFFF0FDF4)
                                      : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(a.type.toUpperCase(),
                                style: TextStyle(fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: a.type == 'bank'
                                        ? const Color(0xFF2563EB)
                                        : a.type == 'qris'
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFEF4444))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.providerName,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                Text('${a.accountNumber} — ${a.accountName}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (a.type == 'qris' && a.qrisImageUrl != null) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            a.qrisImageUrl!.startsWith('/')
                                ? '${ApiEndpoints.baseUrl}${a.qrisImageUrl}'
                                : a.qrisImageUrl!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Container(
                              height: 100,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Text('Gambar QRIS tidak tersedia',
                                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                )),
              ]),
              const SizedBox(height: 12),
              _buildSection('Upload Bukti Transfer', [
                if (_proofFile != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_proofFile!, height: 200, fit: BoxFit.cover),
                  ),
                  const SizedBox(height: 8),
                ],
                if (!isProofUploaded) ...[
                  OutlinedButton.icon(
                    onPressed: _pickProof,
                    icon: const Icon(Icons.camera_alt_outlined, size: 18),
                    label: Text(_proofFile != null ? 'Ganti Bukti' : 'Pilih Foto'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                      side: const BorderSide(color: Color(0xFF2563EB)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _proofFile == null || _uploading ? null : _submitProof,
                      icon: _uploading
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(_uploading ? 'Mengirim...' : 'Kirim Bukti Pembayaran'),
                    ),
                  ),
                ],
              ]),
            ],
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFD1FAE5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline, size: 48, color: Color(0xFF10B981)),
            ),
            const SizedBox(height: 24),
            const Text('Bukti Terkirim!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            const SizedBox(height: 8),
            Text('Admin akan memverifikasi pembayaran Anda.\nPantau status di detail task.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Kembali'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 20),
            const Text('Gagal memuat pembayaran',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
