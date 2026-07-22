import 'package:flutter/material.dart';
import '../../data/address_service.dart';
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

  List<AddressItem> _provinces = [];
  List<AddressItem> _cities = [];
  List<AddressItem> _districts = [];
  List<AddressItem> _villages = [];
  AddressItem? _selectedProvince;
  AddressItem? _selectedCity;
  AddressItem? _selectedDistrict;
  AddressItem? _selectedVillage;
  bool _loadingProvinces = true;
  bool _loadingCities = false;
  bool _loadingDistricts = false;
  bool _loadingVillages = false;

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
    _loadProvinces();
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

  Future<void> _loadProvinces() async {
    try {
      _provinces = await AddressService.getProvinces();
      final saved = widget.state.province;
      if (saved.isNotEmpty) {
        _selectedProvince = _provinces.where((p) => p.name == saved).firstOrNull;
        if (_selectedProvince != null) _loadCities(_selectedProvince!.code);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingProvinces = false);
  }

  Future<void> _loadCities(String provinceCode) async {
    if (mounted) setState(() { _loadingCities = true; _cities = []; _districts = []; _villages = []; _selectedCity = null; _selectedDistrict = null; _selectedVillage = null; });
    try {
      _cities = await AddressService.getCities(provinceCode);
      final saved = widget.state.city;
      if (saved.isNotEmpty) {
        _selectedCity = _cities.where((c) => c.name == saved).firstOrNull;
        if (_selectedCity != null) _loadDistricts(_selectedCity!.code);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingCities = false);
  }

  Future<void> _loadDistricts(String regencyCode) async {
    if (mounted) setState(() { _loadingDistricts = true; _districts = []; _villages = []; _selectedDistrict = null; _selectedVillage = null; });
    try {
      _districts = await AddressService.getDistricts(regencyCode);
      final saved = widget.state.district;
      if (saved.isNotEmpty) {
        _selectedDistrict = _districts.where((d) => d.name == saved).firstOrNull;
        if (_selectedDistrict != null) _loadVillages(_selectedDistrict!.code);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingDistricts = false);
  }

  Future<void> _loadVillages(String districtCode) async {
    if (mounted) setState(() { _loadingVillages = true; _villages = []; _selectedVillage = null; });
    try {
      _villages = await AddressService.getVillages(districtCode);
      final saved = widget.state.village;
      if (saved.isNotEmpty) {
        _selectedVillage = _villages.where((v) => v.name == saved).firstOrNull;
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingVillages = false);
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
    widget.state.province = _selectedProvince?.name ?? '';
    widget.state.city = _selectedCity?.name ?? '';
    widget.state.district = _selectedDistrict?.name ?? '';
    widget.state.village = _selectedVillage?.name ?? '';

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
                _buildField('Domisili (Kota/Kabupaten)', _domicileCtrl, true),
                const SizedBox(height: 8),
                Text('Provinsi',
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                const SizedBox(height: 6),
                _loadingProvinces
                    ? const LinearProgressIndicator(minHeight: 2)
                    : DropdownButtonFormField<AddressItem>(
                        value: _selectedProvince,
                        isExpanded: true,
                        decoration: _inputDecoration(hint: 'Pilih provinsi'),
                        items: _provinces.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                        onChanged: (v) {
                          setState(() => _selectedProvince = v);
                          if (v != null) _loadCities(v.code);
                        },
                        validator: (v) => v == null ? 'Provinsi wajib dipilih' : null,
                      ),
                const SizedBox(height: 16),
                Text('Kota / Kabupaten',
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                const SizedBox(height: 6),
                _loadingCities
                    ? const LinearProgressIndicator(minHeight: 2)
                    : DropdownButtonFormField<AddressItem>(
                        value: _selectedCity,
                        isExpanded: true,
                        decoration: _inputDecoration(hint: _selectedProvince == null ? 'Pilih provinsi terlebih dahulu' : 'Pilih kota/kabupaten'),
                        items: _cities.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                        onChanged: _selectedProvince == null ? null : (v) {
                          setState(() => _selectedCity = v);
                          if (v != null) _loadDistricts(v.code);
                        },
                      ),
                const SizedBox(height: 16),
                Text('Kecamatan',
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                const SizedBox(height: 6),
                _loadingDistricts
                    ? const LinearProgressIndicator(minHeight: 2)
                    : DropdownButtonFormField<AddressItem>(
                        value: _selectedDistrict,
                        isExpanded: true,
                        decoration: _inputDecoration(hint: _selectedCity == null ? 'Pilih kota/kabupaten terlebih dahulu' : 'Pilih kecamatan'),
                        items: _districts.map((d) => DropdownMenuItem(value: d, child: Text(d.name))).toList(),
                        onChanged: _selectedCity == null ? null : (v) {
                          setState(() => _selectedDistrict = v);
                          if (v != null) _loadVillages(v.code);
                        },
                      ),
                const SizedBox(height: 16),
                Text('Kelurahan / Desa',
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                const SizedBox(height: 6),
                _loadingVillages
                    ? const LinearProgressIndicator(minHeight: 2)
                    : DropdownButtonFormField<AddressItem>(
                        value: _selectedVillage,
                        isExpanded: true,
                        decoration: _inputDecoration(hint: _selectedDistrict == null ? 'Pilih kecamatan terlebih dahulu' : 'Pilih kelurahan/desa'),
                        items: _villages.map((v) => DropdownMenuItem(value: v, child: Text(v.name))).toList(),
                        onChanged: _selectedDistrict == null ? null : (v) => setState(() => _selectedVillage = v),
                      ),
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
