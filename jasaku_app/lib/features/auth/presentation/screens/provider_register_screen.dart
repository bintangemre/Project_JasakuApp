import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../provider/data/provider_services_repository.dart';
import '../providers/auth_provider.dart';
import 'provider_location_permission_screen.dart';
import 'provider_login_screen.dart';

class ProviderRegisterScreen extends ConsumerStatefulWidget {
  const ProviderRegisterScreen({super.key});

  @override
  ConsumerState<ProviderRegisterScreen> createState() => _ProviderRegisterScreenState();
}

class _ProviderRegisterScreenState extends ConsumerState<ProviderRegisterScreen> {
  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _genderCtrl = TextEditingController();
  final _domicileCtrl = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  // 1. FILE DOKUMEN WAJIB (STEP 1)
  String? _profilePhotoPath;
  String? _ktpPhotoPath;
  String? _selfiePhotoPath;

  // 2. FILE PORTOFOLIO OPSIONAL (TAMBAHAN BARU)
  final List<File> _portfolioFiles = [];

  int _currentStep = 0;
  static const _stepTitles = ['Dokumen', 'Keahlian', 'Tarif', 'Data Diri'];

  // 3. STATE KEAHLIAN & TARIF LOKAL (STEP 2 & 3)
  final List<Map<String, dynamic>> _selectedServices = [];
  String? _selectedServiceId;
  String? _selectedServiceLabel;
  String? _serviceDescription;
  String? _servicePrice;
  String? _pricingTypeId;
  String? _selectedPricingTypeLabel;

  bool _isLoadingServiceMetadata = false;
  String? _serviceMetadataError;
  List<Map<String, dynamic>> _availableServices = [];
  List<Map<String, dynamic>> _availablePricingTypes = [];

  @override
  void initState() {
    super.initState();
    _loadProviderServiceMetadata();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _birthDateCtrl.dispose();
    _addressCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _nicknameCtrl.dispose();
    _genderCtrl.dispose();
    _domicileCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProviderServiceMetadata() async {
    setState(() {
      _isLoadingServiceMetadata = true;
      _serviceMetadataError = null;
    });
    try {
      final repository = ProviderServicesRepository();
      final services = await repository.getAvailableServices();
      final pricingTypes = await repository.getAvailablePricingTypes();

      if (!mounted) return;
      setState(() {
        _availableServices = services;
        _availablePricingTypes = pricingTypes;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _serviceMetadataError = 'Gagal memuat data layanan. Pastikan koneksi internet stabil.';
      });
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingServiceMetadata = false);
    }
  }

  Future<void> _selectBirthDate() async {
    final initialDate = DateTime.now().subtract(const Duration(days: 365 * 18));
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _birthDateCtrl.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _pickDocument(String title, void Function(String) onSelect) async {
    final selectedSource = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('Ambil Foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (selectedSource == null) return;
    final pickedFile = await _imagePicker.pickImage(source: selectedSource, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => onSelect(pickedFile.path));
    }
  }

  Future<void> _pickPortfolio() async {
    if (_portfolioFiles.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Maksimal 5 foto portofolio')));
      return;
    }
    final pickedFile = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _portfolioFiles.add(File(pickedFile.path));
      });
    }
  }

  void _addService() {
    if (_selectedServiceId == null || _serviceDescription == null || _servicePrice == null || _pricingTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lengkapi semua field layanan')));
      return;
    }
    setState(() {
      _selectedServices.add({
        'serviceId': _selectedServiceId,
        'description': _serviceDescription,
        'prices': [
          {
            'pricingTypeId': _pricingTypeId,
            'price': double.parse(_servicePrice!),
          },
        ],
      });
      _selectedServiceId = null;
      _selectedServiceLabel = null;
      _serviceDescription = null;
      _servicePrice = null;
      _pricingTypeId = null;
      _selectedPricingTypeLabel = null;
    });
  }

  bool _validateStep() {
    switch (_currentStep) {
      case 0:
        if (_profilePhotoPath == null || _ktpPhotoPath == null || _selfiePhotoPath == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lengkapi semua dokumen wajib di Step 1 terlebih dahulu')),
          );
          return false;
        }
        return true;
        
      case 1:
        if (_selectedServices.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tambahkan minimal satu keahlian ke dalam list jasa')),
          );
          return false;
        }
        return true;
        
      case 2:
        return true; // Ringkasan tarif konfirmasi visual saja
        
      case 3:
        // 🟢 PERBAIKAN TOTAL: Validasi seluruh field data diri tanpa ada yang terlewat
        if (_fullNameCtrl.text.trim().isEmpty) {
          _showWarningSnackBar('Nama Lengkap wajib diisi');
          return false;
        }
        if (_emailCtrl.text.trim().isEmpty) {
          _showWarningSnackBar('Alamat Email wajib diisi');
          return false;
        }
        if (_phoneCtrl.text.trim().isEmpty) {
          _showWarningSnackBar('Nomor WhatsApp wajib diisi');
          return false;
        }
        if (_birthDateCtrl.text.trim().isEmpty) {
          _showWarningSnackBar('Tanggal Lahir wajib diisi');
          return false;
        }
        if (_genderCtrl.text.trim().isEmpty) {
          _showWarningSnackBar('Gender wajib diisi (pria/wanita)');
          return false;
        }
        if (_domicileCtrl.text.trim().isEmpty) {
          _showWarningSnackBar('Kota Domisili wajib diisi');
          return false;
        }
        if (_addressCtrl.text.trim().isEmpty) {
          _showWarningSnackBar('Alamat Rumah Lengkap wajib diisi');
          return false;
        }
        if (_passwordCtrl.text.trim().isEmpty) {
          _showWarningSnackBar('Kata Sandi Akun wajib diisi');
          return false;
        }
        
        // Cek kecocokan password
        if (_passwordCtrl.text.trim() != _confirmPasswordCtrl.text.trim()) {
          _showWarningSnackBar('Konfirmasi kata sandi tidak cocok');
          return false;
        }
        return true;
        
      default:
        return false;
    }
  }

  // Helper fungsi untuk memunculkan pesan warning agar ringkas
  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange.shade800,
      ),
    );
  }

  Future<void> _onContinue() async {
    if (!_validateStep()) return;
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      return;
    }
    await _registerAllInOne();
  }

  // 🟢 AKSI UTAMA DAFTAR: SEKIRIMAN MULTIPART DATA UTUH BERSAMAAN
// 🟢 ALUR: Registrasi Sukses -> Minta Izin Lokasi -> Lempar ke Login Screen
  Future<void> _registerAllInOne() async {
    final email = _emailCtrl.text.trim();

    // 1. Jalankan fungsi register ke backend via Riverpod AuthNotifier
    final success = await ref.read(authProvider.notifier).registerProvider(
          fullName: _fullNameCtrl.text.trim(),
          nickname: _nicknameCtrl.text.trim(),
          email: email,
          password: _passwordCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          birthDate: _birthDateCtrl.text.trim(),
          gender: _genderCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          domicile: _domicileCtrl.text.trim(),
          profilePhotoPath: _profilePhotoPath,
          ktpPhotoPath: _ktpPhotoPath,
          selfiePhotoPath: _selfiePhotoPath,
          portfolioFiles: _portfolioFiles, 
          services: _selectedServices,     
        );

    if (!mounted) return;

    if (!success) {
  final errorMsg = ref.read(authProvider).error ?? 'Registrasi gagal. Silakan coba lagi.';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
  );
}

    if (success) {
      // 2. WAJIB: Arahkan ke Halaman Izin Lokasi terlebih dahulu
      // Menunggu apakah mitra memberikan izin lokasi atau tidak
      final locationPermissionGranted = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const ProviderLocationPermissionScreen()),
      );

      if (!mounted) return;

      // 3. FINISH: Apa pun hasil izin lokasinya, kunci akhir tetap diarahkan ke Login Screen
      if (locationPermissionGranted == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registrasi & Izin Lokasi Berhasil! Silakan masuk.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registrasi selesai. Jangan lupa aktifkan GPS nanti di pengaturan.'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Bergeser ke halaman login dan bersihkan tumpukan backstack form register
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ProviderLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFE7F9EE),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Pendaftaran Mitra', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            children: [
              _buildStepIndicator(),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStepContent(),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (_currentStep > 0) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: authState.isLoading ? null : () => setState(() => _currentStep--),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Kembali', style: TextStyle(color: Colors.black)),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00A651),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: authState.isLoading ? null : _onContinue,
                              child: authState.isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : Text(
                                      _currentStep < 3 ? 'Lanjut ke ${_stepTitles[_currentStep + 1]}' : 'Daftar Sekarang',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildDocumentStep();
      case 1:
        return _buildSkillStep();
      case 2:
        return _buildTariffStep();
      case 3:
      default:
        return _buildPersonalStep();
    }
  }

  // 🟢 STEP 1: DOKUMEN PREMIUM (FIXED VISUAL PATH)
  Widget _buildDocumentStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Dokumen Verifikasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Unggah berkas untuk kebutuhan verifikasi keaslian tim admin.', style: TextStyle(color: Colors.grey, fontSize: 13)),
        const SizedBox(height: 20),
        _buildUploadField(label: 'Foto Profil Resmi', value: _profilePhotoPath, onTap: () => _pickDocument('Profil', (p) => _profilePhotoPath = p)),
        const SizedBox(height: 12),
        _buildUploadField(label: 'Foto KTP / Identitas', value: _ktpPhotoPath, onTap: () => _pickDocument('KTP', (p) => _ktpPhotoPath = p)),
        const SizedBox(height: 12),
        _buildUploadField(label: 'Foto Selfie Pegang KTP', value: _selfiePhotoPath, onTap: () => _pickDocument('Selfie', (p) => _selfiePhotoPath = p)),
        const Divider(height: 32),
        
        // AREA PORTOFOLIO OPSIONAL
        const Text('Portofolio Pengalaman Kerja (Opsional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        InkWell(
          onTap: _pickPortfolio,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12), color: Colors.grey.shade50),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate_outlined, color: Colors.grey), SizedBox(width: 8), Text('Tambah Foto Pengalaman')]),
          ),
        ),
        if (_portfolioFiles.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _portfolioFiles.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_portfolioFiles[i], width: 60, height: 60, fit: BoxFit.cover)),
              ),
            ),
          )
        ]
      ],
    );
  }

  // 🟢 STEP 2: KEAHLIAN
Widget _buildSkillStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Keahlian Jasa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        
        // 1. Pilih Jenis Keahlian
        _buildTextField(
          label: 'Pilih Jenis Keahlian', 
          hintText: _selectedServiceLabel ?? 'Ketuk untuk memilih layanan', // 🟢 Ubah ke hintText jika valuenya null
          onTap: () => _showServicePicker()
        ),
        const SizedBox(height: 12),
        
        // 2. Deskripsi Keahlian
        _buildTextField(
          label: 'Deskripsi Keahlian', 
          hintText: 'Contoh: Ahli bongkar pasang AC bocor...', 
          onChanged: (v) => _serviceDescription = v
        ),
        const SizedBox(height: 12),
        
        // 3. Patokan Harga
        _buildTextField(
          label: 'Patokan Harga (Rp)', 
          hintText: 'Masukkan nominal angka', 
          keyboardType: TextInputType.number, 
          onChanged: (v) => _servicePrice = v
        ),
        const SizedBox(height: 12),
        
        // 4. Tipe Hitungan Tarif
        _buildTextField(
          label: 'Tipe Hitungan Tarif', 
          hintText: _selectedPricingTypeLabel ?? 'Pilih satuan hitung', // 🟢 Ubah ke hintText jika valuenya null
          onTap: () => _showPricingTypePicker()
        ),
        const SizedBox(height: 16),
        
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            onPressed: () => setState(() => _addService()),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Tambahkan Jasa Ke List', style: TextStyle(color: Colors.white)),
          ),
        ),
      ],
    );
  }

  // 🟢 STEP 3: TARIF SUMMARY
  Widget _buildTariffStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ringkasan Layanan Anda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_selectedServices.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('Belum ada keahlian ditambahkan', style: TextStyle(color: Colors.grey))))
        else
          ..._selectedServices.asMap().entries.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('ID Jasa: ${e.value['serviceId']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${e.value['description']}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                        Text('Rp ${e.value['prices'][0]['price']}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                      ]),
                    ),
                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => setState(() => _selectedServices.removeAt(e.key)))
                  ],
                ),
              ))
      ],
    );
  }

  // 🟢 STEP 4: DATA DIRI
  Widget _buildPersonalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Informasi Data Diri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildTextField(controller: _fullNameCtrl, label: 'Nama Lengkap Sesuai KTP', icon: Icons.person),
        const SizedBox(height: 12),
        _buildTextField(controller: _nicknameCtrl, label: 'Nama Panggilan Lapangan', icon: Icons.badge),
        const SizedBox(height: 12),
        _buildTextField(controller: _emailCtrl, label: 'Alamat Email', icon: Icons.email, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 12),
        _buildTextField(controller: _phoneCtrl, label: 'Nomor WhatsApp Aktif', icon: Icons.phone, keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        GestureDetector(onTap: _selectBirthDate, child: AbsorbPointer(child: _buildTextField(controller: _birthDateCtrl, label: 'Tanggal Lahir', icon: Icons.calendar_today))),
        const SizedBox(height: 12),
        _buildTextField(controller: _genderCtrl, label: 'Gender (pria / wanita)', icon: Icons.transgender),
        const SizedBox(height: 12),
        _buildTextField(controller: _domicileCtrl, label: 'Kota Domisili Sekarang', icon: Icons.location_city),
        const SizedBox(height: 12),
        _buildTextField(controller: _addressCtrl, label: 'Alamat Rumah Lengkap', icon: Icons.home, maxLines: 2),
        const SizedBox(height: 12),
        _buildTextField(controller: _passwordCtrl, label: 'Kata Sandi Akun', icon: Icons.lock, obscureText: true),
        const SizedBox(height: 12),
        _buildTextField(controller: _confirmPasswordCtrl, label: 'Ulangi Kata Sandi', icon: Icons.lock, obscureText: true),
      ],
    );
  }

  // 🟢 WIDGET HELPER: FIX TAMPILAN FILE PATH PANJANG (Premium Look)
  Widget _buildUploadField({required String label, String? value, required VoidCallback onTap}) {
    final bool hasFile = value != null;
    final String fileName = hasFile ? value.split('/').last : 'Belum ada file dipilih';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hasFile ? const Color(0xFF00A651) : const Color(0xFFE2E8F0), width: hasFile ? 1.5 : 1),
          color: hasFile ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
        ),
        child: Row(
          children: [
            Icon(hasFile ? Icons.check_circle : Icons.cloud_upload_outlined, color: hasFile ? const Color(0xFF00A651) : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: hasFile ? Colors.green.shade700 : Colors.grey)),
              ]),
            ),
            const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey)
          ],
        ),
      ),
    );
  }

Widget _buildTextField({
    TextEditingController? controller,
    required String label,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    int maxLines = 1,
    String? hintText,
    VoidCallback? onTap,
    Function(String)? onChanged,
  }) {
    // 🟢 JIKA INPUT FIELD BERUPA PICKER (JENIS LAYANAN / TANGGAL / TIPE HARGA)
    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: AbsorbPointer(
          child: TextField(
            // FIX: Jika controller eksternal kosong, buat controller dinamis dari hintText
            // Ini akan memaksa TextField me-render ulang teks baru setiap kali setState dipicu
            controller: controller ?? TextEditingController(text: hintText),
            readOnly: true,
            decoration: InputDecoration(
              labelText: label,
              prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
            ),
          ),
        ),
      );
    }
    
    // JIKA INPUT FIELD BERUPA KETIKAN MANUAL BIASA (NAMA, EMAIL, PASSWORD)
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

void _showServicePicker() {
    showDialog(
      context: context,
      builder: (context) {
        // 🟢 Gunakan StatefulBuilder agar Dialog ikut mendengarkan update State terbaru
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Pilih Layanan'),
              content: SizedBox(
                width: double.maxFinite,
                child: _isLoadingServiceMetadata
                    ? const Center(child: CircularProgressIndicator())
                    : _availableServices.isEmpty
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.info_outline, color: Colors.orange, size: 40),
                              const SizedBox(height: 12),
                              const Text(
                                'Data layanan belum termuat.\nPastikan koneksi internet aktif.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey, fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () async {
                                  // Set loading di tingkat dialog
                                  setDialogState(() {
                                    _isLoadingServiceMetadata = true;
                                  });
                                  // Picu muat ulang data
                                  await _loadProviderServiceMetadata();
                                  // Matikan loading di tingkat dialog setelah selesai
                                  setDialogState(() {});
                                },
                                child: const Text('Muat Ulang'),
                              )
                            ],
                          )
                        : ListView(
                            shrinkWrap: true,
                            children: _availableServices.map((s) {
                              return ListTile(
                                leading: const Icon(Icons.build_circle, color: Color(0xFF00A651)),
                                title: Text('${s['name']}'),
                                onTap: () {
                                  setState(() {
                                    _selectedServiceId = s['id'];
                                    _selectedServiceLabel = s['name'];
                                  });
                                  Navigator.pop(context);
                                },
                              );
                            }).toList(),
                          ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPricingTypePicker() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pilih Satuan Tarif'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: _availablePricingTypes.map((p) => ListTile(
                  title: Text('${p['name']}'),
                  onTap: () {
                    setState(() {
                      _pricingTypeId = p['id'];
                      _selectedPricingTypeLabel = p['name'];
                    });
                    Navigator.pop(context);
                  },
                )).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(_stepTitles.length * 2 - 1, (index) {
          if (index.isEven) {
            final idx = index ~/ 2;
            final bool isDone = idx <= _currentStep;
            return CircleAvatar(
              radius: 14,
              backgroundColor: isDone ? const Color(0xFF00A651) : Colors.grey.shade300,
              child: Text('${idx + 1}', style: TextStyle(color: isDone ? Colors.white : Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
            );
          }
          return const Expanded(child: Divider(indent: 6, endIndent: 6));
        }),
      ),
    );
  }
}