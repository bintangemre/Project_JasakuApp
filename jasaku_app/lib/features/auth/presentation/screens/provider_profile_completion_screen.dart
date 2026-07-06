import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../provider/presentation/screens/provider_shell.dart';

class ProviderProfileCompletionScreen extends ConsumerStatefulWidget {
  const ProviderProfileCompletionScreen({super.key});

  @override
  ConsumerState<ProviderProfileCompletionScreen> createState() =>
      _ProviderProfileCompletionScreenState();
}

class _ProviderProfileCompletionScreenState
    extends ConsumerState<ProviderProfileCompletionScreen> {
  final _dio = ApiClient().dio;
  final _picker = ImagePicker();
  bool _loading = true;
  bool _submitting = false;

  String? _profilePhotoPath;

  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _pricingTypes = [];
  final Map<String, TextEditingController> _priceControllers = {};
  final Map<String, TextEditingController> _descControllers = {};

  bool _usePayout = false;
  String _payoutType = 'bank';
  final _payoutProviderCtrl = TextEditingController();
  final _payoutAccountCtrl = TextEditingController();
  final _payoutNameCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final [servicesRes, pricingRes] = await Future.wait([
        _dio.get(ApiEndpoints.providerServices),
        _dio.get(ApiEndpoints.providerAvailablePricingTypes),
      ]);

      final services = (servicesRes.data['data'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      final pricingTypes = (pricingRes.data['data'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];

      for (final svc in services) {
        final svcId = svc['id'] as String;
        _descControllers[svcId] =
            TextEditingController(text: svc['description'] as String? ?? '');

        final existingPrices = svc['provider_service_prices'] as List? ?? [];
        final allPricingTypesForCategory = pricingTypes
            .where((pt) =>
                (pt['categories']?['id'] as String?) ==
                (svc['services']?['category_id'] as String?))
            .toList();

        for (final pt in allPricingTypesForCategory) {
          final ptId = pt['id'] as String;
          final key = '${svcId}_$ptId';
          Map<String, dynamic>? existing;
          for (final ep in existingPrices) {
            if ((ep as Map)['pricing_type_id'] == ptId) {
              existing = ep as Map<String, dynamic>;
              break;
            }
          }
          _priceControllers[key] = TextEditingController(
            text: existing?['price']?.toString() ?? '',
          );
        }
      }

      if (mounted) {
        setState(() {
          _services = services;
          _pricingTypes = pricingTypes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: $e')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _getPricingForService(Map<String, dynamic> svc) {
    final catId = svc['services']?['category_id'] as String?;
    return _pricingTypes
        .where((pt) => (pt['categories']?['id'] as String?) == catId)
        .toList();
  }

  Future<void> _pickPhoto() async {
    final x = await _picker.pickImage(source: ImageSource.gallery);
    if (x != null) setState(() => _profilePhotoPath = x.path);
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);

    try {
      final servicesPayload = _services.map((svc) {
        final svcId = svc['id'] as String;
        final pricingForSvc = _getPricingForService(svc);
        final prices = pricingForSvc
            .where((pt) {
              final key = '${svcId}_${pt['id']}';
              final ctrl = _priceControllers[key];
              return ctrl != null && ctrl.text.trim().isNotEmpty;
            })
            .map((pt) {
              final key = '${svcId}_${pt['id']}';
              return {
                'pricingTypeId': pt['id'],
                'price': int.tryParse(_priceControllers[key]!.text.trim()) ?? 0,
              };
            })
            .toList();

        return {
          'serviceId': svc['service_id'],
          'description': _descControllers[svcId]?.text.trim() ?? '',
          'prices': prices,
        };
      }).toList();

      final formDataMap = <String, dynamic>{
        'services': jsonEncode(servicesPayload),
      };

      if (_profilePhotoPath != null) {
        formDataMap['profile_photo'] = await MultipartFile.fromFile(
          _profilePhotoPath!,
          filename: _profilePhotoPath!.split('/').last,
        );
      }

      if (_usePayout) {
        formDataMap['payoutMethod'] = jsonEncode({
          'type': _payoutType,
          'provider_name': _payoutProviderCtrl.text.trim(),
          'account_number': _payoutAccountCtrl.text.trim(),
          'account_name': _payoutNameCtrl.text.trim(),
        });
      }

      final formData = FormData.fromMap(formDataMap);

      await _dio.patch(
        ApiEndpoints.providerCompleteOnboarding,
        data: formData,
        options: Options(headers: {'Content-Type': 'multipart/form-data'}),
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ProviderShell()),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is DioException
                ? (e.response?.data['message'] as String? ?? 'Gagal menyimpan')
                : e.toString()),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    for (final c in _priceControllers.values) {
      c.dispose();
    }
    for (final c in _descControllers.values) {
      c.dispose();
    }
    _payoutProviderCtrl.dispose();
    _payoutAccountCtrl.dispose();
    _payoutNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lengkapi Profil'),
        centerTitle: true,
        backgroundColor: cs.surface,
        elevation: 0,
        foregroundColor: cs.onSurface,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Satu langkah lagi!',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Atur harga layanan dan metode penerimaan sebelum mulai.',
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 28),

                    _buildSectionHeader(
                        Icons.photo_camera_outlined, 'Foto Profil', cs),
                    const SizedBox(height: 12),
                    _buildPhotoSection(cs),
                    const SizedBox(height: 28),

                    _buildSectionHeader(
                        Icons.price_change_outlined, 'Atur Harga Layanan', cs),
                    const SizedBox(height: 12),
                    if (_services.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text('Tidak ada layanan terdaftar.',
                              style: TextStyle(color: cs.onSurfaceVariant)),
                        ),
                      )
                    else
                      ..._services.map((svc) => _buildServiceCard(svc, cs)),

                    const SizedBox(height: 28),

                    _buildSectionHeader(Icons.account_balance_wallet_outlined,
                        'Metode Penerimaan', cs),
                    const SizedBox(height: 12),
                    _buildPayoutSection(cs),
                    const SizedBox(height: 36),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text('Simpan & Lanjutkan',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title, ColorScheme cs) {
    return Row(
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 8),
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPhotoSection(ColorScheme cs) {
    final hasPhoto = _profilePhotoPath != null;
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasPhoto
              ? cs.primaryContainer.withValues(alpha: 0.3)
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasPhoto ? cs.primary : cs.outlineVariant,
            width: hasPhoto ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: hasPhoto
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                hasPhoto ? Icons.check_circle : Icons.cloud_upload_outlined,
                color: hasPhoto ? cs.primary : cs.onSurfaceVariant,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasPhoto
                        ? 'Foto Profil'
                        : 'Upload Foto Profil (Opsional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: hasPhoto ? cs.primary : cs.onSurface,
                    ),
                  ),
                  if (hasPhoto)
                    Text(
                      _profilePhotoPath!.split('/').last,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (!hasPhoto)
                    Text(
                      'Tambahkan foto agar profil lebih menarik',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: hasPhoto ? cs.primary : cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> svc, ColorScheme cs) {
    final svcId = svc['id'] as String;
    final serviceName = svc['services']?['name'] as String? ?? 'Layanan';
    final pricing = _getPricingForService(svc);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.miscellaneous_services_outlined,
                    size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Text(serviceName,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descControllers[svcId],
              decoration: InputDecoration(
                labelText: 'Deskripsi',
                labelStyle: TextStyle(color: cs.onSurfaceVariant),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: cs.primary, width: 1.5),
                ),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            ...pricing.map((pt) {
              final ptId = pt['id'] as String;
              final key = '${svcId}_$ptId';
              final unit = pt['default_unit'] as String? ?? '';
              final label =
                  (pt['name'] as String? ?? '').replaceAll('_', ' ');
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextFormField(
                  controller: _priceControllers[key],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: label,
                    hintText: 'Masukkan harga',
                    hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
                    suffixText: '/$unit',
                    suffixStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                    prefixText: 'Rp ',
                    prefixStyle:
                        TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: cs.primary, width: 1.5),
                    ),
                    isDense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutSection(ColorScheme cs) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Aktifkan metode penerimaan',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface)),
                ),
                Switch(
                  value: _usePayout,
                  activeColor: cs.primary,
                  onChanged: (v) => setState(() => _usePayout = v),
                ),
              ],
            ),
            if (!_usePayout)
              Text('Atur rekening bank atau e-wallet untuk menerima pembayaran',
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurfaceVariant)),
            if (_usePayout) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _payoutType,
                decoration: InputDecoration(
                  labelText: 'Tipe',
                  labelStyle: TextStyle(color: cs.onSurfaceVariant),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: cs.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: cs.primary, width: 1.5),
                  ),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: const [
                  DropdownMenuItem(value: 'bank', child: Text('Bank')),
                  DropdownMenuItem(
                      value: 'ewallet', child: Text('E-Wallet')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _payoutType = v);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _payoutProviderCtrl,
                decoration: _inputDecor(
                    _payoutType == 'bank' ? 'Nama Bank' : 'Nama E-Wallet',
                    cs),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _payoutAccountCtrl,
                decoration: _inputDecor('Nomor Rekening / Akun', cs),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _payoutNameCtrl,
                decoration: _inputDecor('Nama Pemilik', cs),
              ),
            ],
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecor(String label, ColorScheme cs) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: cs.onSurfaceVariant),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
