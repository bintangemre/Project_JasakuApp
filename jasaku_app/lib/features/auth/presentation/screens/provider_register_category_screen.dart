import 'package:flutter/material.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../providers/register_state.dart';
import 'provider_register_personal_screen.dart';

class ProviderRegisterCategoryScreen extends StatefulWidget {
  final RegisterState state;

  const ProviderRegisterCategoryScreen({super.key, required this.state});

  @override
  State<ProviderRegisterCategoryScreen> createState() =>
      _ProviderRegisterCategoryScreenState();
}

class _ProviderRegisterCategoryScreenState
    extends State<ProviderRegisterCategoryScreen> {
  final _dio = ApiClient().dio;
  bool _loading = true;
  List<Map<String, dynamic>> _allServices = [];
  List<Map<String, dynamic>> _selectedServices = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedServices = List.from(widget.state.selectedServices);
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      final response = await _dio.get(
        ApiEndpoints.providerAvailableServices,
      );
      final data = response.data['data'] as List<dynamic>?;
      if (data != null) {
        setState(() {
          _allServices = data
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Gagal memuat data layanan';
        _loading = false;
      });
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupByCategory() {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final svc in _allServices) {
      final cat = svc['categories'] as Map<String, dynamic>?;
      final catName = cat?['name'] as String? ?? 'Lainnya';
      map.putIfAbsent(catName, () => []);
      map[catName]!.add(svc);
    }
    return map;
  }

  bool _isSelected(String serviceId) {
    return _selectedServices.any((s) => s['serviceId'] == serviceId);
  }

  void _toggleService(Map<String, dynamic> svc) {
    final id = svc['id'] as String;
    setState(() {
      if (_isSelected(id)) {
        _selectedServices.removeWhere((s) => s['serviceId'] == id);
      } else {
        _selectedServices.add({
          'serviceId': id,
          'description': '',
          'prices': [],
        });
      }
    });
  }

  void _next() {
    if (_selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih minimal satu layanan'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    widget.state.selectedServices = List.from(_selectedServices);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderRegisterPersonalScreen(
          state: widget.state,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _error = null;
                  });
                  _loadServices();
                },
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final grouped = _groupByCategory();

    return Scaffold(
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                'Pilih Layanan',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Pilih kategori dan layanan yang ingin Anda daftarkan.',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: grouped.entries.map((entry) {
                  return _CategorySection(
                    categoryName: entry.key,
                    services: entry.value,
                    selectedIds: _selectedServices
                        .map((s) => s['serviceId'] as String)
                        .toSet(),
                    onToggle: _toggleService,
                  );
                }).toList(),
              ),
            ),
            if (_selectedServices.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      '${_selectedServices.length} layanan dipilih',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00A651),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _next,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Lanjut',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.black,
      title: const Text('Pendaftaran Mitra',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final String categoryName;
  final List<Map<String, dynamic>> services;
  final Set<String> selectedIds;
  final void Function(Map<String, dynamic>) onToggle;

  const _CategorySection({
    required this.categoryName,
    required this.services,
    required this.selectedIds,
    required this.onToggle,
  });

  ({IconData icon, Color color, Color bg}) _catIcon(String name) {
    final n = name.trim();
    if (n.contains('Listrik') || n.contains('listrik')) {
      return (icon: Icons.electric_bolt, color: const Color(0xFFFFB300), bg: const Color(0xFFFEF3C7));
    } else if (n.contains('Bangunan') || n.contains('bangunan')) {
      return (icon: Icons.home_repair_service, color: const Color(0xFFFF6B00), bg: const Color(0xFFFFEDD5));
    } else if (n.contains('Kebersihan') || n.contains('kebersihan')) {
      return (icon: Icons.cleaning_services, color: const Color(0xFF059669), bg: const Color(0xFFD1FAE5));
    } else if (n.contains('Pindahan') || n.contains('pindahan')) {
      return (icon: Icons.local_shipping, color: const Color(0xFF2563EB), bg: const Color(0xFFDBEAFE));
    } else if (n.contains('Kayu') || n.contains('kayu')) {
      return (icon: Icons.handyman, color: const Color(0xFF7C3AED), bg: const Color(0xFFEDE9FE));
    } else if (n.contains('AC') || n.contains('Elektronik') || n.contains('elektronik')) {
      return (icon: Icons.ac_unit, color: const Color(0xFF0891B2), bg: const Color(0xFFCFFAFE));
    }
    return (icon: Icons.build_circle, color: const Color(0xFF6B7280), bg: const Color(0xFFF3F4F6));
  }

  ({IconData icon, Color color, Color bg}) _serviceIcon(String name) {
    final n = name.trim();
    if (n.contains('Listrik') || n.contains('listrik')) {
      return (icon: Icons.electric_bolt, color: const Color(0xFFFFB300), bg: const Color(0xFFFFF8E1));
    } else if (n.contains('Bangunan') || n.contains('bangunan') || n.contains('bangun')) {
      return (icon: Icons.home_repair_service, color: const Color(0xFFFF6B00), bg: const Color(0xFFFFF0E0));
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
    }
    return (icon: Icons.build_circle, color: const Color(0xFF6B7280), bg: const Color(0xFFF3F4F6));
  }

  @override
  Widget build(BuildContext context) {
    final cat = _catIcon(categoryName);
    final selectedCount = services.where((s) => selectedIds.contains(s['id'] as String)).length;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cat.bg,
              shape: BoxShape.circle,
            ),
            child: Icon(cat.icon, color: cat.color, size: 22),
          ),
          title: Text(
            categoryName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: selectedCount > 0
              ? Text(
                  '$selectedCount dipilih',
                  style: TextStyle(fontSize: 12, color: cat.color, fontWeight: FontWeight.w500),
                )
              : Text(
                  '${services.length} layanan',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
          children: services.map((svc) {
            final id = svc['id'] as String;
            final name = svc['name'] as String? ?? '';
            final isSelected = selectedIds.contains(id);
            final svcIcon = _serviceIcon(name);
            return GestureDetector(
              onTap: () => onToggle(svc),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected ? svcIcon.bg : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? svcIcon.color : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isSelected ? svcIcon.color : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          svcIcon.icon,
                          color: isSelected ? Colors.white : svcIcon.color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? svcIcon.color : Colors.black87,
                          ),
                        ),
                      ),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? svcIcon.color : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? svcIcon.color : const Color(0xFFCBD5E1),
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
