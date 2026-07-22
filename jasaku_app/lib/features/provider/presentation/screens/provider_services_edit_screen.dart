import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../providers/provider_profile_provider.dart';

class ProviderServicesEditScreen extends ConsumerStatefulWidget {
  const ProviderServicesEditScreen({super.key});

  @override
  ConsumerState<ProviderServicesEditScreen> createState() =>
      _ProviderServicesEditScreenState();
}

class _ProviderServicesEditScreenState
    extends ConsumerState<ProviderServicesEditScreen> {
  final _dio = ApiClient().dio;
  bool _loading = true;
  bool _saving = false;

  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _pricingUnits = [];

  final Map<String, TextEditingController> _descControllers = {};
  final Map<String, TextEditingController> _priceControllers = {};
  final Map<String, TextEditingController> _priceWithMaterialControllers = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final c in _descControllers.values) {
      c.dispose();
    }
    for (final c in _priceControllers.values) {
      c.dispose();
    }
    for (final c in _priceWithMaterialControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final [servicesRes, pricingRes] = await Future.wait([
        _dio.get(ApiEndpoints.providerServices),
        _dio.get(ApiEndpoints.providerAvailablePricingUnits),
      ]);

      final services = (servicesRes.data['data'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      final pricingUnits = (pricingRes.data['data'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      for (final svc in services) {
        final svcId = svc['id'] as String;
        _descControllers[svcId] =
            TextEditingController(text: svc['description'] as String? ?? '');

        final existingPrices = svc['provider_service_prices'] as List? ?? [];
        final catId = svc['services']?['category_id'] as String?;

        final pricingForCategory = pricingUnits
            .where((pu) => (pu['category_id'] as String?) == catId)
            .toList();

        for (final pu in pricingForCategory) {
          final puId = pu['id'] as String;
          final key = '${svcId}_$puId';
          Map<String, dynamic>? existing;
          for (final ep in existingPrices) {
            if ((ep as Map)['pricing_unit_id'] == puId) {
              existing = ep as Map<String, dynamic>;
              break;
            }
          }
          _priceControllers[key] = TextEditingController(
            text: existing?['price']?.toString() ?? '',
          );
          _priceWithMaterialControllers[key] = TextEditingController(
            text: existing?['price_with_material']?.toString() ?? '',
          );
        }
      }

      if (mounted) {
        setState(() {
          _services = services;
          _pricingUnits = pricingUnits;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: ${ApiClient.errorMessage(e)}')),
        );
      }
    }
  }

  List<Map<String, dynamic>> _getPricingForService(Map<String, dynamic> svc) {
    final catId = svc['services']?['category_id'] as String?;
    return _pricingUnits
        .where((pu) => (pu['category_id'] as String?) == catId)
        .toList();
  }

  String? _getExistingContractTypeId(Map<String, dynamic> svc, String pricingUnitId) {
    final existingPrices = svc['provider_service_prices'] as List? ?? [];
    for (final ep in existingPrices) {
      if ((ep as Map)['pricing_unit_id'] == pricingUnitId) {
        return ep['contract_type_id'] as String?;
      }
    }
    return null;
  }

  bool _getExistingPlusMaterial(Map<String, dynamic> svc, String pricingUnitId) {
    final existingPrices = svc['provider_service_prices'] as List? ?? [];
    for (final ep in existingPrices) {
      if ((ep as Map)['pricing_unit_id'] == pricingUnitId) {
        return ep['plus_material'] == true;
      }
    }
    return false;
  }

  Future<void> _saveAll() async {
    setState(() => _saving = true);

    final futures = <Future>[];
    for (final svc in _services) {
      final svcId = svc['id'] as String;
      final serviceId = svc['service_id'] as String;
      final pricingForSvc = _getPricingForService(svc);

      final prices = pricingForSvc
          .where((pu) {
            final key = '${svcId}_${pu['id']}';
            final ctrl = _priceControllers[key];
            return ctrl != null && ctrl.text.trim().isNotEmpty;
          })
          .map((pu) {
            final puId = pu['id'] as String;
            final key = '${svcId}_$puId';
            final existingContractTypeId = _getExistingContractTypeId(svc, puId);
            final existingPlusMaterial = _getExistingPlusMaterial(svc, puId);

            final price = int.tryParse(_priceControllers[key]!.text.trim()) ?? 0;
            final priceWithMaterialStr = _priceWithMaterialControllers[key]?.text.trim();
            final priceWithMaterial = priceWithMaterialStr != null && priceWithMaterialStr.isNotEmpty
                ? int.tryParse(priceWithMaterialStr)
                : null;

            return {
              'pricingUnitId': puId,
              'contractTypeId': existingContractTypeId,
              'price': price,
              'priceWithMaterial': priceWithMaterial,
              'plusMaterial': existingPlusMaterial,
            };
          })
          .toList();

      futures.add(_dio.put(
        ApiEndpoints.updateProviderService,
        data: {
          'serviceId': serviceId,
          'description': _descControllers[svcId]?.text.trim() ?? '',
          'prices': prices,
        },
      ).then((_) => true).catchError((_) => false));
    }

    final results = await Future.wait(futures);
    final updated = results.where((r) => r == true).length;
    final failed = results.where((r) => r == false).length;

    if (!mounted) return;

    setState(() => _saving = false);

    if (failed == 0) {
      ref.invalidate(profileProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua layanan berhasil diperbarui')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$updated berhasil, $failed gagal diperbarui'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Layanan'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _services.isEmpty
              ? const Center(child: Text('Belum ada layanan'))
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        children: _services.map((svc) {
                          return _buildServiceCard(svc, cs);
                        }).toList(),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _saving ? null : _saveAll,
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Simpan Perubahan',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
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
            ...pricing.map((pu) {
              final puId = pu['id'] as String;
              final key = '${svcId}_$puId';
              final unit = pu['unit'] as String? ?? '';
              final label = (pu['name'] as String? ?? '').replaceAll('_', ' ');
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _priceControllers[key],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Harga $label',
                        hintText: 'Masukkan harga',
                        hintStyle:
                            TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
                        suffixText: '/$unit',
                        suffixStyle:
                            TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _priceWithMaterialControllers[key],
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Harga $label + Material',
                        hintText: 'Harga jika include material',
                        hintStyle:
                            TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
                        suffixText: '/$unit',
                        suffixStyle:
                            TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
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
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
