import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  bool _loading = true;
  bool _submitting = false;

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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Lengkapi Profil'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        surfaceTintColor: Colors.transparent,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                child: Column(
                  children: [
                    _buildHeader(cs),
                    const SizedBox(height: 24),
                    if (_services.isEmpty)
                      _buildEmptyServices(cs)
                    else ...[
                      _buildSectionLabel(
                          Icons.price_change_outlined, 'Atur Harga Layanan', cs),
                      const SizedBox(height: 12),
                      ..._services.map((svc) => _buildServiceCard(svc, cs)),
                    ],
                    const SizedBox(height: 24),
                    _buildSectionLabel(Icons.account_balance_wallet_outlined,
                        'Metode Penerimaan', cs),
                    const SizedBox(height: 12),
                    _buildPayoutSection(cs),
                    const SizedBox(height: 32),
                    _buildSubmitButton(cs),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primary.withValues(alpha: 0.08),
            cs.primary.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.rocket_launch_outlined,
                color: cs.primary, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yuk, satu langkah lagi nih! ✨',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface)),
                const SizedBox(height: 4),
                Text(
                    'Atur harga layanan dan metode penerimaan sebelum memulai.',
                    style: TextStyle(
                        fontSize: 13, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(IconData icon, String title, ColorScheme cs) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 17, color: cs.primary),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: cs.onSurface)),
      ],
    );
  }

  Widget _buildEmptyServices(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: cs.error.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.info_outline, color: cs.error, size: 26),
          ),
          const SizedBox(height: 16),
          Text('Belum ada layanan terdaftar',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface)),
          const SizedBox(height: 6),
          Text('Hubungi admin jika ini seharusnya sudah ada.',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  ({IconData icon, Color color, Color bg}) _iconForService(String name) {
    final n = name.trim();
    if (n.contains('Bangunan') || n.contains('bangunan') || n.contains('bangun') || n.contains('Keramik') || n.contains('keramik')) {
      return (icon: Icons.home_repair_service, color: const Color(0xFFFF6B00), bg: const Color(0xFFFFF0E0));
    } else if (n.contains('Listrik') || n.contains('listrik')) {
      return (icon: Icons.electric_bolt, color: const Color(0xFFFFB300), bg: const Color(0xFFFFF8E1));
    } else if (n.contains('Bersih') || n.contains('bersih') || n.contains('Cuci') || n.contains('cuci')) {
      return (icon: Icons.cleaning_services, color: const Color(0xFF059669), bg: const Color(0xFFE6F7F0));
    } else if (n.contains('Pindah') || n.contains('pindah') || n.contains('Angkut') || n.contains('angkut')) {
      return (icon: Icons.local_shipping, color: const Color(0xFF2563EB), bg: const Color(0xFFE6EEFF));
    } else if (n.contains('Kayu') || n.contains('kayu') || n.contains('Furnitur') || n.contains('furnitur')) {
      return (icon: Icons.handyman, color: const Color(0xFF7C3AED), bg: const Color(0xFFF0E6FF));
    } else if (n.contains('AC') || n.contains('Elektronik') || n.contains('elektronik')) {
      return (icon: Icons.ac_unit, color: const Color(0xFF0891B2), bg: const Color(0xFFE0F7FA));
    } else if (n.contains('Cat') || n.contains('cat') || n.contains('Pengecatan') || n.contains('pengecatan')) {
      return (icon: Icons.format_paint, color: const Color(0xFFE91E63), bg: const Color(0xFFFCE4EC));
    } else if (n.contains('Taman') || n.contains('taman') || n.contains('Berkebun') || n.contains('berkebun')) {
      return (icon: Icons.yard, color: const Color(0xFF4CAF50), bg: const Color(0xFFE8F5E9));
    } else if (n.contains('Plumbing') || n.contains('plumbing') || n.contains('Pipa') || n.contains('pipa') || n.contains('ledeng')) {
      return (icon: Icons.plumbing, color: const Color(0xFF00BCD4), bg: const Color(0xFFE0F7FA));
    } else if (n.contains('Kaca') || n.contains('kaca')) {
      return (icon: Icons.window, color: const Color(0xFF6366F1), bg: const Color(0xFFEEF2FF));
    }
    return (icon: Icons.miscellaneous_services_outlined, color: const Color(0xFF6B7280), bg: const Color(0xFFF3F4F6));
  }

  Widget _buildServiceCard(Map<String, dynamic> svc, ColorScheme cs) {
    final svcId = svc['id'] as String;
    final serviceName = svc['services']?['name'] as String? ?? 'Layanan';
    final categoryName = svc['services']?['categories']?['name'] as String? ?? '';
    final pricing = _getPricingForService(svc);
    final svcIcon = _iconForService(serviceName);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: svcIcon.bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(svcIcon.icon,
                      size: 18, color: svcIcon.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(serviceName,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      if (categoryName.isNotEmpty)
                        Text(categoryName,
                            style: TextStyle(
                                fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Deskripsi Layanan',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descControllers[svcId],
                  decoration: InputDecoration(
                    hintText: 'Deskripsi layanan Anda',
                    hintStyle:
                        TextStyle(color: cs.onSurface.withValues(alpha: 0.35)),
                    filled: true,
                    fillColor: cs.surfaceContainerLow.withValues(alpha: 0.4),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: cs.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: cs.primary, width: 1.5),
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                Text('Harga',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant)),
                const SizedBox(height: 8),
                ...pricing.map((pt) {
                  final ptId = pt['id'] as String;
                  final key = '${svcId}_$ptId';
                  final unit = pt['default_unit'] as String? ?? '';
                  final label =
                      (pt['name'] as String? ?? '').replaceAll('_', ' ');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextFormField(
                      controller: _priceControllers[key],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: label,
                        hintText: '0',
                        hintStyle: TextStyle(
                            color: cs.onSurface.withValues(alpha: 0.35)),
                        suffixText: '/$unit',
                        suffixStyle: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 13),
                        prefixText: 'Rp ',
                        prefixStyle: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 14),
                        filled: true,
                        fillColor:
                            cs.surfaceContainerLow.withValues(alpha: 0.4),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: cs.outlineVariant),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: cs.primary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  );
                }),
                if (pricing.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text('Tidak ada metode harga untuk layanan ini',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutSection(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.account_balance_wallet_outlined,
                      size: 18, color: cs.secondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Aktifkan Metode Penerimaan',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      Text(
                          'Rekening bank atau e-wallet untuk menerima pembayaran',
                          style: TextStyle(
                              fontSize: 12, color: cs.onSurfaceVariant)),
                    ],
                  ),
                ),
                Switch(
                  value: _usePayout,
                  activeColor: cs.primary,
                  onChanged: (v) => setState(() => _usePayout = v),
                ),
              ],
            ),
          ),
          if (_usePayout)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _payoutType,
                    decoration: _inputDecor('Tipe', cs),
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
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(ColorScheme cs) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: _submitting ? null : _submit,
        child: _submitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('Simpan & Lanjutkan',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
      ),
    );
  }

  InputDecoration _inputDecor(String label, ColorScheme cs) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: cs.onSurfaceVariant),
      filled: true,
      fillColor: cs.surfaceContainerLow.withValues(alpha: 0.4),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: cs.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: cs.primary, width: 1.5),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }
}
