import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';

class AdminPricingTypesPage extends StatefulWidget {
  const AdminPricingTypesPage({super.key});

  @override
  State<AdminPricingTypesPage> createState() => _AdminPricingTypesPageState();
}

class _AdminPricingTypesPageState extends State<AdminPricingTypesPage> {
  final Dio _dio = ApiClient().dio;
  List<Map<String, dynamic>> _categories = [];
  final Map<String, List<Map<String, dynamic>>> _pricingTypesByCategory = {};
  bool _isLoading = true;
  String? _error;
  String? _expandedCategoryId;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    try {
      final res = await _dio.get(ApiEndpoints.adminCategories);
      final data = res.data['data'] as List? ?? [];
      _categories = data.cast<Map<String, dynamic>>();
      for (final cat in _categories) {
        final catId = cat['id'] as String;
        await _fetchPricingTypes(catId);
      }
      setState(() {
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _fetchPricingTypes(String categoryId) async {
    try {
      final res = await _dio.get(ApiEndpoints.adminPricingTypes(categoryId));
      final data = res.data['data'] as List? ?? [];
      _pricingTypesByCategory[categoryId] = data.cast<Map<String, dynamic>>();
    } catch (e) {
      _pricingTypesByCategory[categoryId] = [];
    }
  }

  Future<void> _showCreateDialog(String categoryId, String categoryName) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _PricingTypeFormDialog(
        title: 'Tambah Tipe Harga',
        categoryHint: categoryName,
      ),
    );
    if (result == null) return;

    try {
      await _dio.post(ApiEndpoints.adminCreatePricingType, data: {
        'categoryId': categoryId,
        'name': result['name'],
        if (result['defaultUnit'] != null && result['defaultUnit']!.isNotEmpty)
          'defaultUnit': result['defaultUnit'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tipe harga berhasil dibuat'), backgroundColor: Colors.green),
        );
        await _fetchPricingTypes(categoryId);
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> pricingType, String categoryName) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _PricingTypeFormDialog(
        title: 'Edit Tipe Harga',
        categoryHint: categoryName,
        initialName: pricingType['name'] as String? ?? '',
        initialUnit: pricingType['default_unit'] as String? ?? '',
      ),
    );
    if (result == null) return;

    final id = pricingType['id'] as String;
    try {
      await _dio.put(ApiEndpoints.adminUpdatePricingType(id), data: {
        'name': result['name'],
        if (result['defaultUnit'] != null && result['defaultUnit']!.isNotEmpty)
          'defaultUnit': result['defaultUnit']
        else
          'defaultUnit': null,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tipe harga berhasil diupdate'), backgroundColor: Colors.green),
        );
        final catId = pricingType['category_id'] as String? ?? '';
        if (catId.isNotEmpty) {
          await _fetchPricingTypes(catId);
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deletePricingType(Map<String, dynamic> pricingType) async {
    final name = pricingType['name'] as String? ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Tipe Harga'),
        content: Text('Yakin ingin menghapus "$name"? Tipe harga yang masih digunakan tidak dapat dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final id = pricingType['id'] as String;
    final catId = pricingType['category_id'] as String? ?? '';
    try {
      await _dio.delete(ApiEndpoints.adminDeletePricingType(id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tipe harga berhasil dihapus'), backgroundColor: Colors.green),
        );
        if (catId.isNotEmpty) {
          await _fetchPricingTypes(catId);
          setState(() {});
        }
      }
    } catch (e) {
      final msg = e.toString();
      final errorMsg = msg.contains('masih digunakan') ? 'Tipe harga masih digunakan oleh layanan/order' : 'Gagal: $msg';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Tipe Harga'),
        backgroundColor: const Color(0xFF00A651),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchAll),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchAll, child: const Text('Coba Lagi')),
          ],
        ),
      );
    }
    if (_categories.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Tidak ada kategori', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _categories.length,
        itemBuilder: (_, i) => _buildCategoryCard(_categories[i]),
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    final catId = category['id'] as String;
    final catName = category['name'] as String? ?? '-';
    final types = _pricingTypesByCategory[catId] ?? [];
    final isExpanded = _expandedCategoryId == catId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expandedCategoryId = isExpanded ? null : catId),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.category, color: Color(0xFF00A651), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(catName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text('${types.length} tipe harga',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00A651)),
                    tooltip: 'Tambah Tipe Harga',
                    onPressed: () => _showCreateDialog(catId, catName),
                  ),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            if (types.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Belum ada tipe harga', style: TextStyle(color: Colors.grey)),
              )
            else
              ...types.map((pt) => _buildPricingTypeTile(pt, catName)),
          ],
        ],
      ),
    );
  }

  Widget _buildPricingTypeTile(Map<String, dynamic> pt, String categoryName) {
    final name = pt['name'] as String? ?? '-';
    final unit = pt['default_unit'] as String? ?? '-';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: const Icon(Icons.attach_money, size: 20, color: Color(0xFFF59E0B)),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text('Unit: $unit', style: const TextStyle(fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Edit',
            onPressed: () => _showEditDialog(pt, categoryName),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
            tooltip: 'Hapus',
            onPressed: () => _deletePricingType(pt),
          ),
        ],
      ),
    );
  }
}

class _PricingTypeFormDialog extends StatefulWidget {
  final String title;
  final String categoryHint;
  final String? initialName;
  final String? initialUnit;

  const _PricingTypeFormDialog({
    required this.title,
    required this.categoryHint,
    this.initialName,
    this.initialUnit,
  });

  @override
  State<_PricingTypeFormDialog> createState() => _PricingTypeFormDialogState();
}

class _PricingTypeFormDialogState extends State<_PricingTypeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _unitCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName ?? '');
    _unitCtrl = TextEditingController(text: widget.initialUnit ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kategori: ${widget.categoryHint}',
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Tipe Harga *',
                hintText: 'Contoh: Harian, Per Meter',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _unitCtrl,
              decoration: const InputDecoration(
                labelText: 'Unit Default',
                hintText: 'Contoh: hari, meter, kg',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A651)),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'name': _nameCtrl.text.trim(),
                'defaultUnit': _unitCtrl.text.trim(),
              });
            }
          },
          child: const Text('Simpan', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
