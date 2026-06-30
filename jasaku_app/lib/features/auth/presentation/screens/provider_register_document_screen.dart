import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/register_state.dart';
import '../providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'provider_register_terms_screen.dart';
import 'provider_register_success_screen.dart';

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
  List<File> _portfolioFiles = [];

  @override
  void initState() {
    super.initState();
    final s = widget.state;
    _profilePhotoPath = s.profilePhotoPath;
    _ktpPhotoPath = s.ktpPhotoPath;
    _selfiePhotoPath = s.selfiePhotoPath;
    _portfolioFiles = List.from(s.portfolioFiles);
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
      });
    }
  }

  Future<void> _pickPortfolio() async {
    final xs = await _picker.pickMultiImage();
    setState(() {
      for (final x in xs) {
        if (_portfolioFiles.length < 5) {
          _portfolioFiles.add(File(x.path));
        }
      }
    });
  }

  Future<void> _goToTerms() async {
    if (_profilePhotoPath == null) {
      _showError('Upload foto profil');
      return;
    }
    if (_ktpPhotoPath == null) {
      _showError('Upload foto KTP');
      return;
    }
    if (_selfiePhotoPath == null) {
      _showError('Upload foto selfie');
      return;
    }

    final s = widget.state;
    s.profilePhotoPath = _profilePhotoPath;
    s.ktpPhotoPath = _ktpPhotoPath;
    s.selfiePhotoPath = _selfiePhotoPath;
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
            portfolioFiles: s.portfolioFiles.isNotEmpty ? s.portfolioFiles : null,
            services: s.selectedServices,
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
              _buildUploadCard(
                label: 'Foto KTP',
                required: true,
                path: _ktpPhotoPath,
                onPick: () => _pickImage('ktp'),
              ),
              const SizedBox(height: 12),
              _buildUploadCard(
                label: 'Foto Selfie Pegang KTP',
                required: true,
                path: _selfiePhotoPath,
                onPick: () => _pickImage('selfie'),
              ),
              const SizedBox(height: 12),
              _buildUploadCard(
                label: 'Portofolio (Opsional)',
                required: false,
                path: _portfolioFiles.isNotEmpty
                    ? '${_portfolioFiles.length} file'
                    : null,
                onPick: _pickPortfolio,
              ),
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
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            Icon(
              hasFile ? Icons.check_circle : Icons.cloud_upload_outlined,
              color: hasFile
                  ? const Color(0xFF00A651)
                  : const Color(0xFF7A7A7A),
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
                  if (hasFile)
                    Text(
                      path.length > 30
                          ? '${path.substring(0, 27)}...'
                          : path,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF00A651)),
                      overflow: TextOverflow.ellipsis,
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
