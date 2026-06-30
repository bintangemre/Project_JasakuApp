import 'package:flutter/material.dart';
import '../providers/register_state.dart';
import 'provider_register_document_screen.dart';

class ProviderRegisterPersonalScreen extends StatefulWidget {
  final RegisterState state;

  const ProviderRegisterPersonalScreen({super.key, required this.state});

  @override
  State<ProviderRegisterPersonalScreen> createState() =>
      _ProviderRegisterPersonalScreenState();
}

class _ProviderRegisterPersonalScreenState
    extends State<ProviderRegisterPersonalScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameCtrl;
  late TextEditingController _nicknameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _passwordCtrl;
  late TextEditingController _confirmPasswordCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _birthDateCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _domicileCtrl;
  String _gender = 'Laki-laki';

  @override
  void initState() {
    super.initState();
    final s = widget.state;
    _fullNameCtrl = TextEditingController(text: s.fullName);
    _nicknameCtrl = TextEditingController(text: s.nickname);
    _emailCtrl = TextEditingController(text: s.email);
    _passwordCtrl = TextEditingController(text: s.password);
    _confirmPasswordCtrl = TextEditingController();
    _phoneCtrl = TextEditingController(text: s.phone);
    _birthDateCtrl = TextEditingController(text: s.birthDate);
    _addressCtrl = TextEditingController(text: s.address);
    _domicileCtrl = TextEditingController(text: s.domicile);
    if (s.gender.isNotEmpty) _gender = s.gender;
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _nicknameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
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
      lastDate: DateTime.now().subtract(const Duration(days: 6570)),
    );
    if (picked != null) {
      _birthDateCtrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  void _next() {
    if (!_formKey.currentState!.validate()) return;

    widget.state.fullName = _fullNameCtrl.text.trim();
    widget.state.nickname = _nicknameCtrl.text.trim();
    widget.state.email = _emailCtrl.text.trim();
    widget.state.password = _passwordCtrl.text;
    widget.state.phone = _phoneCtrl.text.trim();
    widget.state.birthDate = _birthDateCtrl.text.trim();
    widget.state.gender = _gender;
    widget.state.address = _addressCtrl.text.trim();
    widget.state.domicile = _domicileCtrl.text.trim();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderRegisterDocumentScreen(
          state: widget.state,
        ),
      ),
    );
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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data Diri',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Lengkapi data diri Anda.',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 24),
                _buildField('Nama Lengkap', _fullNameCtrl, true),
                _buildField('Nama Panggilan', _nicknameCtrl, true),
                _buildField('Email', _emailCtrl, true,
                    keyboardType: TextInputType.emailAddress),
                _buildField('Password', _passwordCtrl, true,
                    obscure: true, validator: (v) {
                  if (v == null || v.length < 6) return 'Minimal 6 karakter';
                  return null;
                }),
                _buildField('Konfirmasi Password', _confirmPasswordCtrl, true,
                    obscure: true, validator: (v) {
                  if (v != _passwordCtrl.text) return 'Password tidak cocok';
                  return null;
                }),
                _buildField('Nomor HP', _phoneCtrl, true,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 16),
                Text('Tanggal Lahir',
                    style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.7))),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _birthDateCtrl,
                  readOnly: true,
                  onTap: _pickDate,
                  decoration: _inputDecoration(
                    hint: 'Pilih tanggal lahir',
                    suffixIcon: Icons.calendar_today,
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Pilih tanggal lahir' : null,
                ),
                const SizedBox(height: 16),
                Text('Jenis Kelamin',
                    style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.7))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _gender,
                  items: const [
                    DropdownMenuItem(value: 'Laki-laki', child: Text('Laki-laki')),
                    DropdownMenuItem(value: 'Perempuan', child: Text('Perempuan')),
                  ],
                  onChanged: (v) => setState(() => _gender = v ?? 'Laki-laki'),
                  decoration: _inputDecoration(),
                ),
                _buildField('Alamat', _addressCtrl, true),
                _buildField('Domisili', _domicileCtrl, true),
                const SizedBox(height: 24),
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
                    onPressed: _next,
                    child: const Text(
                      'Lanjut',
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
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, bool required,
      {TextInputType? keyboardType,
      bool obscure = false,
      String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
                fontSize: 13,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: ctrl,
            keyboardType: keyboardType,
            obscureText: obscure,
            decoration: _inputDecoration(),
            validator: validator ??
                (required
                    ? (v) =>
                        v == null || v.trim().isEmpty ? '$label wajib diisi' : null
                    : null),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint, IconData? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      suffixIcon: suffixIcon != null ? Icon(suffixIcon, size: 18) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFF0F766E), width: 2),
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
