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

  // Payout
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lengkapi Profil'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
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
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Atur harga layanan dan metode penerimaan sebelum mulai.',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Profile Photo
                    _buildPhotoSection(),
                    const SizedBox(height: 24),

                    // Service Prices
                    Text('Atur Harga Layanan',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    if (_services.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Tidak ada layanan terdaftar.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ..._services.map((svc) => _buildServiceCard(svc)),

                    const SizedBox(height: 32),

                    // Payout Section
                    _buildPayoutSection(),
                    const SizedBox(height: 32),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
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

  Widget _buildPhotoSection() {
    final hasPhoto = _profilePhotoPath != null;
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasPhoto ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasPhoto ? const Color(0xFF00A651) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasPhoto ? Icons.check_circle : Icons.cloud_upload_outlined,
              color: hasPhoto ? const Color(0xFF00A651) : const Color(0xFF7A7A7A),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasPhoto
                    ? 'Foto Profil: ${_profilePhotoPath!.split('/').last}'
                    : 'Upload Foto Profil (Opsional)',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF7A7A7A)),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> svc) {
    final svcId = svc['id'] as String;
    final serviceName = svc['services']?['name'] as String? ?? 'Layanan';
    final pricing = _getPricingForService(svc);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(serviceName,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descControllers[svcId],
              decoration: const InputDecoration(
                labelText: 'Deskripsi',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            ...pricing.map((pt) {
              final ptId = pt['id'] as String;
              final key = '${svcId}_$ptId';
              final unit = pt['default_unit'] as String? ?? '';
              final label = (pt['name'] as String? ?? '').replaceAll('_', ' ');
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextFormField(
                  controller: _priceControllers[key],
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: label,
                    hintText: 'Rp',
                    suffixText: '/$unit',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPayoutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Metode Penerimaan (Opsional)',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
            ),
            Switch(
              value: _usePayout,
              activeColor: const Color(0xFF0F766E),
              onChanged: (v) => setState(() => _usePayout = v),
            ),
          ],
        ),
        if (_usePayout) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _payoutType,
            decoration: const InputDecoration(
              labelText: 'Tipe',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'bank', child: Text('Bank')),
              DropdownMenuItem(value: 'ewallet', child: Text('E-Wallet')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _payoutType = v);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _payoutProviderCtrl,
            decoration: InputDecoration(
              labelText:
                  _payoutType == 'bank' ? 'Nama Bank' : 'Nama E-Wallet',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _payoutAccountCtrl,
            decoration: InputDecoration(
              labelText: 'Nomor Rekening / Akun',
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _payoutNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nama Pemilik',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ],
    );
  }
}
