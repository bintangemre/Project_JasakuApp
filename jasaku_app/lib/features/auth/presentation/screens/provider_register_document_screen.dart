import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/register_state.dart';
import '../providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'provider_register_terms_screen.dart';
import 'provider_register_success_screen.dart';
import 'ktp_scanner_screen.dart';
import 'liveness_screen.dart';

class ProviderRegisterDocumentScreen extends ConsumerStatefulWidget {
  final RegisterState state;

  const ProviderRegisterDocumentScreen({super.key, required this.state});

  @override
  ConsumerState<ProviderRegisterDocumentScreen> createState() =>
      _ProviderRegisterDocumentScreenState();
}

class _ProviderRegisterDocumentScreenState
    extends ConsumerState<ProviderRegisterDocumentScreen> {
  final _picker = ImagePicker();
  bool _submitting = false;

  String? _profilePhotoPath;
  String? _ktpPhotoPath;
  String? _selfiePhotoPath;
  String? _ijazahPath;
  List<File> _portfolioFiles = [];
  List<Map<String, dynamic>> _certificates = [];

  @override
  void initState() {
    super.initState();
    final s = widget.state;
    _profilePhotoPath = s.profilePhotoPath;
    _ktpPhotoPath = s.ktpPhotoPath;
    _selfiePhotoPath = s.selfiePhotoPath;
    _ijazahPath = s.ijazahPhotoPath;
    _portfolioFiles = List.from(s.portfolioFiles);
    _certificates = List.from(s.certificates);
  }

  Future<void> _pickImage(String type) async {
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
    if (x != null) {
      setState(() {
        if (type == 'profile') _profilePhotoPath = x.path;
        if (type == 'ktp') _ktpPhotoPath = x.path;
        if (type == 'selfie') _selfiePhotoPath = x.path;
        if (type == 'ijazah') _ijazahPath = x.path;
      });
    }
  }

  Future<void> _pickPortfolio() async {
    if (_portfolioFiles.length >= 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maksimal 3 foto portofolio')),
        );
      }
      return;
    }
    final xs = await _picker.pickMultiImage();
    setState(() {
      for (final x in xs) {
        if (_portfolioFiles.length < 3) {
          _portfolioFiles.add(File(x.path));
        }
      }
    });
  }

  void _removePortfolio(int index) {
    setState(() {
      _portfolioFiles.removeAt(index);
    });
  }

  Future<void> _goToTerms() async {
    if (_profilePhotoPath == null) {
      _showError('Upload foto profil');
      return;
    }
    if (_ktpPhotoPath == null) {
      _showError('Scan KTP terlebih dahulu');
      return;
    }
    if (widget.state.ocrNik == null) {
      _showError('Data KTP tidak terbaca, silakan scan ulang');
      return;
    }
    if (_selfiePhotoPath == null) {
      _showError('Verifikasi wajah terlebih dahulu');
      return;
    }

    final s = widget.state;
    s.profilePhotoPath = _profilePhotoPath;
    s.ktpPhotoPath = _ktpPhotoPath;
    s.selfiePhotoPath = _selfiePhotoPath;
    s.ijazahPhotoPath = _ijazahPath;
    s.certificates = _certificates.where((c) => c['filePath'] != null).toList();
    s.portfolioFiles = _portfolioFiles;

    final agreed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const ProviderRegisterTermsScreen(),
      ),
    );

    if (agreed == true && mounted) {
      await _submit();
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);

    final s = widget.state;

    try {
      final success = await ref
          .read(authProvider.notifier)
          .registerProvider(
            fullName: s.fullName,
            nickname: s.nickname,
            email: s.email,
            password: s.password,
            phone: s.phone,
            birthDate: s.birthDate,
            gender: s.gender,
            address: s.address,
            domicile: s.domicile,
            profilePhotoPath: s.profilePhotoPath,
            ktpPhotoPath: s.ktpPhotoPath,
            selfiePhotoPath: s.selfiePhotoPath,
            ijazahPhotoPath: s.ijazahPhotoPath,
            certificates: s.certificates.isNotEmpty ? s.certificates : null,
            portfolioFiles: s.portfolioFiles.isNotEmpty ? s.portfolioFiles : null,
            services: s.selectedServices,
            ocrNik: s.ocrNik,
            ocrFullName: s.ocrFullName,
            ocrBirthPlace: s.ocrBirthPlace,
            ocrBirthDate: s.ocrBirthDate,
            ocrAddress: s.ocrAddress,
            ocrGender: s.ocrGender,
            ocrBloodType: s.ocrBloodType,
            ocrReligion: s.ocrReligion,
            livenessData: s.livenessData,
          );

      if (!mounted) return;

      if (success) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const ProviderRegisterSuccessScreen(),
          ),
          (route) => false,
        );
      } else {
        final error = ref.read(authProvider).error;
        _showError(error ?? 'Gagal mendaftar');
        setState(() => _submitting = false);
      }
    } catch (e) {
      _showError(e.toString());
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Pendaftaran Mitra',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upload Dokumen',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Unggah dokumen berikut untuk verifikasi identitas.',
                style: TextStyle(
                  fontSize: 14,
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              _buildUploadCard(
                label: 'Foto Profil',
                required: true,
                path: _profilePhotoPath,
                onPick: () => _pickImage('profile'),
              ),
              const SizedBox(height: 12),
              _buildScanKtpCard(),
              const SizedBox(height: 12),
              _buildLivenessCard(),
              const SizedBox(height: 12),
              _buildPortfolioCard(),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              _buildUploadCard(
                label: 'Foto Ijazah',
                required: false,
                path: _ijazahPath,
                onPick: () => _pickImage('ijazah'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Sertifikat Penunjang (Opsional)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  TextButton.icon(
                    onPressed: _addCertificate,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Tambah'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (_certificates.isEmpty)
                GestureDetector(
                  onTap: () {
                    _addCertificate();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final lastIndex = _certificates.length - 1;
                      if (lastIndex >= 0) _pickCertificateFile(lastIndex);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade50,
                    ),
                    child: const Center(
                      child: Text('Ketuk untuk menambah sertifikat',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ),
                  ),
                )
              else
                ..._certificates.asMap().entries.map(
                    (e) => _buildCertificateItem(e.key, e.value)),
              const SizedBox(height: 32),
              if (_submitting)
                const Center(child: CircularProgressIndicator())
              else
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A651),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _goToTerms,
                    child: const Text(
                      'Daftar Sekarang',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _addCertificate() {
    setState(() {
      _certificates.add({'filePath': null});
    });
  }

  Future<void> _pickCertificateFile(int index) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'pdf', 'doc', 'docx', 'xls', 'xlsx'],
      );
      if (result != null && result.files.single.path != null) {
        setState(() {
          _certificates[index]['filePath'] = result.files.single.path;
        });
      } else if (mounted && result == null) {
        // user cancelled
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e')),
        );
      }
    }
  }

  Widget _buildCertificateItem(int index, Map<String, dynamic> cert) {
    final filePath = cert['filePath'] as String?;
    final isImage = filePath != null && _isImageExtension(filePath);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.only(left: 12, right: 4, top: 12, bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _pickCertificateFile(index),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: filePath != null ? const Color(0xFF00A651) : Colors.grey.shade300),
                color: filePath != null ? const Color(0xFFF0FDF4) : Colors.white,
              ),
              child: filePath != null && isImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.file(
                        File(filePath),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.insert_drive_file, color: Colors.grey.shade400),
                      ),
                    )
                  : Icon(
                      filePath != null ? Icons.insert_drive_file : Icons.add_photo_alternate_outlined,
                      color: Colors.grey,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _pickCertificateFile(index),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      filePath != null ? filePath.split('/').last : 'Pilih file',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: filePath != null ? Colors.green.shade700 : Colors.grey),
                    ),
                    if (filePath == null)
                      Text(
                        'PDF, DOC, JPG, PNG, dll',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                      ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => setState(() => _certificates.removeAt(index)),
          ),
        ],
      ),
    );
  }

  Future<void> _openKtpScanner() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const KtpScannerScreen()),
    );
    if (result != null && mounted) {
      setState(() {
        _ktpPhotoPath = result['ktpPath'] as String?;
        widget.state.ktpPhotoPath = result['ktpPath'] as String?;
        widget.state.ocrNik = result['nik'] as String?;
        widget.state.ocrFullName = result['fullName'] as String?;
        widget.state.ocrBirthPlace = result['birthPlace'] as String?;
        widget.state.ocrBirthDate = result['birthDate'] as String?;
        widget.state.ocrAddress = result['address'] as String?;
        widget.state.ocrGender = result['gender'] as String?;
        widget.state.ocrBloodType = result['bloodType'] as String?;
        widget.state.ocrReligion = result['religion'] as String?;
      });
    }
  }

  Future<void> _openLiveness() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => const LivenessScreen()),
    );
    if (result != null && mounted) {
      setState(() {
        _selfiePhotoPath = result['selfiePath'] as String?;
        widget.state.selfiePhotoPath = result['selfiePath'] as String?;
        widget.state.livenessData = result['livenessData'] as Map<String, dynamic>?;
      });
    }
  }

  Widget _buildScanKtpCard() {
    final hasOcr = widget.state.ocrNik != null;
    final hasFile = _ktpPhotoPath != null;
    return GestureDetector(
      onTap: _openKtpScanner,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasFile ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasFile ? const Color(0xFF00A651) : const Color(0xFFE2E8F0),
            width: hasFile ? 1.5 : 1,
          ),
        ),
        child: hasFile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_ktpPhotoPath!),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 48, height: 48,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('Scan KTP',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                const Text(' *', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                            if (hasOcr)
                              Text('NIK: ${widget.state.ocrNik}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF00A651))),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFF7A7A7A)),
                    ],
                  ),
                  if (hasOcr) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _miniDataRow('NIK', widget.state.ocrNik!),
                          if (widget.state.ocrFullName != null) _miniDataRow('Nama', widget.state.ocrFullName!),
                          if (widget.state.ocrGender != null) _miniDataRow('JK', widget.state.ocrGender!),
                          if (widget.state.ocrBloodType != null) _miniDataRow('Gol.Darah', widget.state.ocrBloodType!),
                          if (widget.state.ocrAddress != null) _miniDataRow('Alamat', widget.state.ocrAddress!),
                          if (widget.state.ocrReligion != null) _miniDataRow('Agama', widget.state.ocrReligion!),
                        ],
                      ),
                    ),
                  ],
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.document_scanner, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Scan KTP',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            const Text(' *', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                        const Text('Deteksi otomatis + baca data',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF7A7A7A)),
                ],
              ),
      ),
    );
  }

  Widget _buildLivenessCard() {
    final hasLiveness = _selfiePhotoPath != null;
    return GestureDetector(
      onTap: _openLiveness,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasLiveness ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasLiveness ? const Color(0xFF00A651) : const Color(0xFFE2E8F0),
            width: hasLiveness ? 1.5 : 1,
          ),
        ),
        child: hasLiveness
            ? Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_selfiePhotoPath!),
                      width: 48, height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 48, height: 48,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Verifikasi Wajah',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            const Text(' *', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                        const Text('Liveness terverifikasi',
                            style: TextStyle(fontSize: 11, color: Color(0xFF00A651))),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF7A7A7A)),
                ],
              )
            : Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.face_retouching_natural, color: Color(0xFFFF6B00), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Verifikasi Wajah',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                            const Text(' *', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                        const Text('Kedip + Senyum + Miringkan kepala',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF7A7A7A)),
                ],
              ),
      ),
    );
  }

  Widget _buildPortfolioCard() {
    final count = _portfolioFiles.length;
    return GestureDetector(
      onTap: count < 3 ? _pickPortfolio : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: count > 0 ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: count > 0 ? const Color(0xFF00A651) : const Color(0xFFE2E8F0),
            width: count > 0 ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Portofolio/Foto Pengalaman Kerja',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const Spacer(),
                if (count > 0)
                  Text('$count/3',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const Icon(Icons.chevron_right,
                    color: Color(0xFF7A7A7A), size: 20),
              ],
            ),
            const SizedBox(height: 8),
            count > 0
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (int i = 0; i < count; i++)
                          _buildPortfolioThumb(i),
                        if (count < 3)
                          _buildPortfolioAddButton(),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      Icon(Icons.cloud_upload_outlined,
                          color: Colors.grey[400], size: 20),
                      const SizedBox(width: 8),
                      const Text('Portofolio/Foto Pengalaman Kerja',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioThumb(int index) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _portfolioFiles[index],
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 64,
                height: 64,
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image,
                    color: Colors.grey, size: 24),
              ),
            ),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: GestureDetector(
              onTap: () => _removePortfolio(index),
              child: Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 12, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioAddButton() {
    return GestureDetector(
      onTap: _pickPortfolio,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300, width: 1.5),
        ),
        child: Icon(Icons.add, color: Colors.grey[400], size: 28),
      ),
    );
  }

  Widget _miniDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  bool _isImageExtension(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  Widget _buildUploadCard({
    required String label,
    required bool required,
    String? path,
    required VoidCallback onPick,
  }) {
    final hasFile = path != null;
    return GestureDetector(
      onTap: onPick,
      child: Container(
        width: double.infinity,
        padding: hasFile ? const EdgeInsets.all(12) : const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasFile ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasFile
                ? const Color(0xFF00A651)
                : const Color(0xFFE2E8F0),
            width: hasFile ? 1.5 : 1,
          ),
        ),
        child: hasFile
            ? Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(path),
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 64,
                        height: 64,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(label,
                                  style: const TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w500)),
                            ),
                            if (required)
                              const Text(' *',
                                  style: TextStyle(color: Colors.red)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          path.split('/').last,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF00A651)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF7A7A7A)),
                ],
              )
            : Row(
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    color: const Color(0xFF7A7A7A),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(label,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w500)),
                            if (required)
                              const Text(' *',
                                  style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF7A7A7A)),
                ],
              ),
      ),
    );
  }
}
