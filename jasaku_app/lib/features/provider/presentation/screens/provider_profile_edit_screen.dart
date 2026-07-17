import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/utils/image_url.dart';
import '../providers/provider_profile_provider.dart';

class ProviderProfileEditScreen extends ConsumerStatefulWidget {
  const ProviderProfileEditScreen({super.key});

  @override
  ConsumerState<ProviderProfileEditScreen> createState() => _ProviderProfileEditScreenState();
}

class _ProviderProfileEditScreenState extends ConsumerState<ProviderProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late TextEditingController _fullNameCtrl;
  late TextEditingController _nicknameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _birthDateCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _domicileCtrl;
  String _gender = '';
  bool _submitting = false;
  String? _profilePhotoPath;
  List<String> _existingPortfolios = [];
  final List<File> _newPortfolioFiles = [];
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final s = ref.read(profileProvider);
    _fullNameCtrl = TextEditingController(text: s.fullName ?? '');
    _nicknameCtrl = TextEditingController(text: s.nickname ?? '');
    _phoneCtrl = TextEditingController(text: s.phone ?? '');
    _birthDateCtrl = TextEditingController(text: s.birthDate ?? '');
    _addressCtrl = TextEditingController(text: s.address ?? '');
    _domicileCtrl = TextEditingController(text: s.domicile ?? '');
    final rawGender = s.gender ?? '';
    if (rawGender.isNotEmpty) {
      const validGenders = ['Laki-laki', 'Perempuan'];
      _gender = validGenders.firstWhere(
        (g) => g.toLowerCase() == rawGender.toLowerCase(),
        orElse: () => '',
      );
    }
    _existingPortfolios = List<String>.from(s.portfolios);
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _nicknameCtrl.dispose();
    _phoneCtrl.dispose();
    _birthDateCtrl.dispose();
    _addressCtrl.dispose();
    _domicileCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 6570)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _birthDateCtrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      _hasChanges = true;
    }
  }

  Future<void> _pickPhoto() async {
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
        _profilePhotoPath = x.path;
        _hasChanges = true;
      });
    }
  }

  Future<void> _pickPortfolio() async {
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
              const Text('Pilih Sumber', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
        _newPortfolioFiles.add(File(x.path));
        _hasChanges = true;
      });
    }
  }

  void _removeExistingPortfolio(int index) {
    setState(() {
      _existingPortfolios.removeAt(index);
      _hasChanges = true;
    });
  }

  void _removeNewPortfolio(int index) {
    setState(() {
      _newPortfolioFiles.removeAt(index);
      _hasChanges = true;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasChanges && _profilePhotoPath == null && _newPortfolioFiles.isEmpty) {
      Navigator.pop(context, false);
      return;
    }

    setState(() => _submitting = true);

    final ok = await ref.read(profileProvider.notifier).updateProfile(
      fullName: _fullNameCtrl.text.trim(),
      nickname: _nicknameCtrl.text.trim(),
      gender: _gender,
      birthDate: _birthDateCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      domicile: _domicileCtrl.text.trim(),
      profilePhotoPath: _profilePhotoPath,
      portfolios: _existingPortfolios,
      newPortfolioFiles: _newPortfolioFiles,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      Navigator.pop(context, true);
    } else {
      final err = ref.read(profileProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Gagal menyimpan')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profil'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          TextButton(
            onPressed: _submitting ? null : _save,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Simpan',
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: _profilePhotoPath != null
                              ? FileImage(File(_profilePhotoPath!))
                              : ref.read(profileProvider).profilePhoto != null
                                  ? NetworkImage(imageUrl(ref.read(profileProvider).profilePhoto))
                                  : null,
                          backgroundColor: const Color(0xFFE8F5E9),
                          child: _profilePhotoPath == null && ref.read(profileProvider).profilePhoto == null
                              ? const Icon(Icons.person,
                                  size: 50, color: Color(0xFF00A651))
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFF00A651),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 18, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                _buildField('Nama Lengkap', _fullNameCtrl, true),
                _buildField('Nama Panggilan', _nicknameCtrl, true),
                _buildField('Nomor HP', _phoneCtrl, true,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 16),
                Text('Jenis Kelamin',
                    style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _gender.isEmpty ? null : _gender,
                  items: const [
                    DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki')),
                    DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
                  ],
                  onChanged: (v) {
                    setState(() {
                      _gender = v ?? '';
                      _hasChanges = true;
                    });
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Tanggal Lahir',
                    style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _birthDateCtrl,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: InputDecoration(
                    hintText: 'Pilih tanggal lahir',
                    suffixIcon: const Icon(Icons.calendar_today, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                ),
                _buildField('Alamat', _addressCtrl, true, maxLines: 2),
                _buildField('Domisili', _domicileCtrl, true),
                const SizedBox(height: 24),
                _buildPortfolioSection(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortfolioSection() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Portofolio',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface)),
            TextButton.icon(
              onPressed: _existingPortfolios.length + _newPortfolioFiles.length >= 5
                  ? null
                  : _pickPortfolio,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
              label: const Text('Tambah'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_existingPortfolios.isEmpty && _newPortfolioFiles.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Icon(Icons.photo_library_outlined, size: 40, color: Colors.grey.shade300),
                const SizedBox(height: 8),
                Text('Belum ada portofolio', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
              ],
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._existingPortfolios.asMap().entries.map((e) => _buildPortfolioThumb(
                url: e.value,
                isNetwork: true,
                onDelete: () => _removeExistingPortfolio(e.key),
              )),
              ..._newPortfolioFiles.asMap().entries.map((e) => _buildPortfolioThumb(
                file: e.value,
                isNetwork: false,
                onDelete: () => _removeNewPortfolio(e.key),
              )),
            ],
          ),
        const SizedBox(height: 4),
        Text('Maksimal 5 foto', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
      ],
    );
  }

  Widget _buildPortfolioThumb({
    String? url,
    File? file,
    required bool isNetwork,
    required VoidCallback onDelete,
  }) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 90,
            height: 90,
            child: isNetwork
                ? Image.network(
                    imageUrl(url),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFFF1F5F9),
                      child: const Icon(Icons.broken_image, color: Color(0xFF94A3B8)),
                    ),
                  )
                : Image.file(file!, fit: BoxFit.cover),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, bool required,
      {TextInputType? keyboardType, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: ctrl,
            keyboardType: keyboardType,
            maxLines: maxLines,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
            ),
            validator: required
                ? (v) => v == null || v.trim().isEmpty ? '$label wajib diisi' : null
                : null,
            onChanged: (_) => _hasChanges = true,
          ),
        ],
      ),
    );
  }
}
