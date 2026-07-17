import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/screens/provider_verification_pending_screen.dart';
import '../../data/provider_profile_repository.dart';
import 'provider_services_edit_screen.dart';

class ProviderEditResubmissionScreen extends ConsumerStatefulWidget {
  const ProviderEditResubmissionScreen({super.key});

  @override
  ConsumerState<ProviderEditResubmissionScreen> createState() =>
      _ProviderEditResubmissionScreenState();
}

class _ProviderEditResubmissionScreenState
    extends ConsumerState<ProviderEditResubmissionScreen> {
  final _repo = ProviderProfileRepository();
  final _picker = ImagePicker();

  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic>? _profile;

  String? _newProfilePhotoPath;
  String? _newKtpPhotoPath;
  String? _newSelfiePath;
  final List<File> _newDocuments = [];

  final Map<String, String> _textEdits = {};
  final Set<String> _fixedItems = {};

  List<_ChecklistItem>? _checklist;
  String? _checklistNotes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final authState = ref.read(authProvider);
    _parseChecklist(authState.verificationNotes);
    try {
      final data = await _repo.getFullProfile();
      if (mounted) {
        setState(() {
          _profile = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _parseChecklist(String? notes) {
    if (notes == null || notes.isEmpty) return;
    try {
      final json = jsonDecode(notes) as Map<String, dynamic>;
      final list = (json['checklist'] as List?)?.map((item) {
        final m = item as Map<String, dynamic>;
        return _ChecklistItem(
          id: m['item'] as String? ?? '',
          status: m['status'] as String? ?? 'passed',
          note: m['note'] as String?,
        );
      }).toList();
      if (list != null && list.isNotEmpty) {
        _checklist = list;
        _checklistNotes = json['notes'] as String? ?? '';
      }
    } catch (_) {}
  }

  String _labelFor(String id) {
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
    return labels[id] ?? id;
  }

  bool get _hasFailedItems =>
      _checklist?.any((i) => i.status == 'failed') ?? false;

  bool get _allFixed => _hasFailedItems
      ? _checklist!
          .where((i) => i.status == 'failed')
          .every((i) => _fixedItems.contains(i.id))
      : false;

  Future<void> _pickPhoto(String itemId) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Pilih Sumber',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Galeri'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Kamera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) return;
    final x = await _picker.pickImage(source: source);
    if (x == null) return;
    setState(() {
      if (itemId == 'profile_photo') _newProfilePhotoPath = x.path;
      if (itemId == 'ktp_photo') _newKtpPhotoPath = x.path;
      if (itemId == 'selfie') _newSelfiePath = x.path;
      _fixedItems.add(itemId);
    });
  }

  Future<void> _pickDocuments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _newDocuments.addAll(result.files.map((f) => File(f.path!)));
      _fixedItems.add('documents');
    });
  }

  void _editText(String itemId, String currentValue) {
    final ctrl = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Perbaiki ${_labelFor(itemId)}'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          maxLines: itemId == 'address' ? 3 : 1,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isNotEmpty) {
                setState(() {
                  _textEdits[itemId] = v;
                  _fixedItems.add(itemId);
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    ).then((_) => ctrl.dispose());
  }

  Future<void> _handleServices() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const ProviderServicesEditScreen(),
      ),
    );
    if (changed == true) setState(() => _fixedItems.add('services'));
  }

  Future<void> _saveAndResubmit() async {
    setState(() => _saving = true);
    try {
      if (_textEdits.isNotEmpty ||
          _newProfilePhotoPath != null ||
          _newKtpPhotoPath != null ||
          _newSelfiePath != null ||
          _newDocuments.isNotEmpty) {
        await _repo.updateProfile(
          fullName: _textEdits['full_name'],
          phone: _textEdits['phone'],
          address: _textEdits['address'],
          profilePhotoPath: _newProfilePhotoPath,
          ktpPhotoPath: _newKtpPhotoPath,
          selfiePhotoPath: _newSelfiePath,
          documentFiles: _newDocuments.isNotEmpty ? _newDocuments : null,
        );
      }

      final ok = await ref.read(authProvider.notifier).resubmitVerification();
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Pengajuan ulang berhasil dikirim. Silakan tunggu verifikasi admin.'),
          ),
        );
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const ProviderVerificationPendingScreen(status: 'pending'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                ref.read(authProvider).error ?? 'Gagal mengajukan ulang'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyimpan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perbaiki Data'),
        foregroundColor: Colors.black,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBody() {
    final failedItems =
        _checklist?.where((i) => i.status == 'failed').toList() ?? [];
    final passedItems =
        _checklist?.where((i) => i.status == 'passed').toList() ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFE0B2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Color(0xFFE65100), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Perbaiki item yang ditandai, lalu ajukan ulang untuk diperiksa admin kembali.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFE65100),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (failedItems.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Perlu Diperbaiki',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF991B1B),
              ),
            ),
            const SizedBox(height: 10),
            ...failedItems.map((item) => _buildFailedItemCard(item)),
          ],
          if (passedItems.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Sudah Sesuai',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF065F46),
              ),
            ),
            const SizedBox(height: 10),
            ...passedItems.map((item) => _buildPassedItemCard(item)),
          ],
          if (_checklistNotes != null && _checklistNotes!.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Catatan Admin: ${_checklistNotes!}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildFailedItemCard(_ChecklistItem item) {
    final fixed = _fixedItems.contains(item.id);
    final isTextItem = ['full_name', 'phone', 'address'].contains(item.id);
    final isPhotoItem = ['profile_photo', 'ktp_photo', 'selfie'].contains(item.id);
    final isServices = item.id == 'services';
    final isDocuments = item.id == 'documents';

    String currentValue = '';
    if (_profile != null) {
      if (item.id == 'full_name') {
        currentValue = _textEdits[item.id] ?? _profile!['full_name'] as String? ?? '';
      } else if (item.id == 'phone') {
        currentValue = _textEdits[item.id] ?? _profile!['phone'] as String? ?? '';
      } else if (item.id == 'address') {
        currentValue = _textEdits[item.id] ?? _profile!['address'] as String? ?? '';
      } else if (item.id == 'services') {
        final svc = _profile!['services'] as List? ?? [];
        currentValue = '${svc.length} layanan';
      }
    }

    Widget actionBtn;
    if (fixed) {
      actionBtn = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFD1FAE5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 14, color: Color(0xFF059669)),
            SizedBox(width: 4),
            Text('Sudah',
                style: TextStyle(fontSize: 12, color: Color(0xFF059669))),
          ],
        ),
      );
    } else if (isTextItem) {
      actionBtn = TextButton.icon(
        onPressed: () => _editText(item.id, currentValue),
        icon: const Icon(Icons.edit, size: 16),
        label: const Text('Perbaiki', style: TextStyle(fontSize: 13)),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFDC2626),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
    } else if (isPhotoItem) {
      actionBtn = TextButton.icon(
        onPressed: () => _pickPhoto(item.id),
        icon: const Icon(Icons.camera_alt, size: 16),
        label: const Text('Ambil Foto', style: TextStyle(fontSize: 13)),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFDC2626),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
    } else if (isServices) {
      actionBtn = TextButton.icon(
        onPressed: _handleServices,
        icon: const Icon(Icons.settings, size: 16),
        label: const Text('Atur', style: TextStyle(fontSize: 13)),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFDC2626),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
    } else if (isDocuments) {
      actionBtn = TextButton.icon(
        onPressed: _pickDocuments,
        icon: const Icon(Icons.upload_file, size: 16),
        label: Text(
          _newDocuments.isNotEmpty
              ? '${_newDocuments.length} file dipilih'
              : 'Upload',
          style: const TextStyle(fontSize: 13),
        ),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFDC2626),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      );
    } else {
      actionBtn = const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fixed ? const Color(0xFFF0FDF4) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: fixed ? const Color(0xFF86EFAC) : const Color(0xFFFECACA),
          width: fixed ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                fixed ? Icons.check_circle : Icons.cancel,
                size: 20,
                color: fixed
                    ? const Color(0xFF059669)
                    : const Color(0xFFDC2626),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _labelFor(item.id),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    if (item.note != null && item.note!.isNotEmpty)
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
                    if (currentValue.isNotEmpty && !fixed)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Saat ini: $currentValue',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    if (fixed && isDocuments && _newDocuments.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${_newDocuments.length} file baru diunggah',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actionBtn,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPassedItemCard(_ChecklistItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 18, color: Color(0xFF059669)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _labelFor(item.id),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF065F46),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildBottomBar() {
    if (_loading || !_hasFailedItems) return null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _allFixed
                  ? const Color(0xFF059669)
                  : const Color(0xFFD1D5DB),
              foregroundColor: _allFixed ? Colors.white : const Color(0xFF9CA3AF),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: _allFixed ? 2 : 0,
            ),
            onPressed: _allFixed && !_saving ? _saveAndResubmit : null,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Simpan & Ajukan Ulang',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }
}

class _ChecklistItem {
  final String id;
  final String status;
  final String? note;
  const _ChecklistItem({
    required this.id,
    required this.status,
    this.note,
  });
}


