import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/customer_profile_provider.dart';

class CustomerEditInfoPage extends ConsumerStatefulWidget {
  const CustomerEditInfoPage({super.key});

  @override
  ConsumerState<CustomerEditInfoPage> createState() =>
      _CustomerEditInfoPageState();
}

class _CustomerEditInfoPageState extends ConsumerState<CustomerEditInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _nicknameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  String _gender = '';
  DateTime? _birthDate;
  bool _saving = false;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final state = ref.read(customerProfileProvider);
    final profileData = state.data?.profile;
    _nicknameCtrl.text = profileData?.nickname ?? '';
    _phoneCtrl.text = state.data?.phone ?? '';
    _addressCtrl.text = profileData?.address ?? '';
    final rawGender = profileData?.gender ?? '';
    if (rawGender.isNotEmpty) {
      const validGenders = ['Laki-laki', 'Perempuan'];
      _gender = validGenders.firstWhere(
        (g) => g.toLowerCase() == rawGender.toLowerCase(),
        orElse: () => '',
      );
    }

    if (profileData?.birthDate != null && profileData!.birthDate!.isNotEmpty) {
      try {
        _birthDate = DateTime.parse(profileData.birthDate!);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _birthDate ?? DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _hasChanges = true;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final err = await ref
        .read(customerProfileProvider.notifier)
        .updateProfile(
          nickname:
              _nicknameCtrl.text.trim().isEmpty
                  ? null
                  : _nicknameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
          address:
              _addressCtrl.text.trim().isEmpty
                  ? null
                  : _addressCtrl.text.trim(),
          gender: _gender.isEmpty ? null : _gender,
          birthDate:
              _birthDate != null
                  ? DateFormat('yyyy-MM-dd').format(_birthDate!)
                  : null,
        );
    if (mounted) {
      setState(() => _saving = false);
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.error),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil berhasil diperbarui'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Info Akun'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0.5,
        actions: [
          TextButton(
            onPressed: _hasChanges ? _save : null,
            child:
                _saving
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text(
                      'Simpan',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildField(
                'Nama Panggilan',
                _nicknameCtrl,
                hint: 'Contoh: Budi',
              ),
              const SizedBox(height: 20),
              _buildField(
                'Nomor Telepon',
                _phoneCtrl,
                hint: 'Contoh: 08123456789',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
              Text(
                'Jenis Kelamin',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _gender.isEmpty ? null : _gender,
                items: const [
                  DropdownMenuItem(
                    value: 'Laki-laki',
                    child: Text('Laki-laki'),
                  ),
                  DropdownMenuItem(
                    value: 'Perempuan',
                    child: Text('Perempuan'),
                  ),
                ],
                onChanged: (v) {
                  setState(() {
                    _gender = v ?? '';
                    _hasChanges = true;
                  });
                },
                decoration: _inputDecoration(),
              ),
              const SizedBox(height: 20),
              Text(
                'Tanggal Lahir',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _birthDate != null
                            ? DateFormat(
                              'dd MMMM yyyy',
                              'id',
                            ).format(_birthDate!)
                            : 'Pilih tanggal lahir',
                        style: TextStyle(
                          color:
                              _birthDate != null
                                  ? AppColors.textPrimary
                                  : AppColors.textHint,
                          fontSize: 15,
                        ),
                      ),
                      const Icon(
                        Icons.calendar_today,
                        color: AppColors.textHint,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              _buildField(
                'Alamat',
                _addressCtrl,
                hint: 'Contoh: Jl. Merdeka No. 123, Jakarta',
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl, {
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: (_) => setState(() => _hasChanges = true),
          decoration: _inputDecoration().copyWith(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
