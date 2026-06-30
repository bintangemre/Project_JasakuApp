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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  '${_selectedServices.length} layanan dipilih',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
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
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _next,
                  child: const Text(
                    'Lanjut',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: const Color(0xFFF8FAFC),
      child: ExpansionTile(
        title: Text(
          categoryName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          '${services.length} layanan',
          style: const TextStyle(fontSize: 12),
        ),
        children: services.map((svc) {
          final id = svc['id'] as String;
          final name = svc['name'] as String? ?? '';
          final isSelected = selectedIds.contains(id);
          return CheckboxListTile(
            title: Text(name, style: const TextStyle(fontSize: 14)),
            value: isSelected,
            onChanged: (_) => onToggle(svc),
            activeColor: const Color(0xFF0F766E),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            dense: true,
          );
        }).toList(),
      ),
    );
  }
}
