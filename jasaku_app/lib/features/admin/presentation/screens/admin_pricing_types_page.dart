import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';

class AdminPricingTypesPage extends StatefulWidget {
  const AdminPricingTypesPage({super.key});

  @override
  State<AdminPricingTypesPage> createState() => _AdminPricingTypesPageState();
}

class _AdminPricingTypesPageState extends State<AdminPricingTypesPage>
    with SingleTickerProviderStateMixin {
  final Dio _dio = ApiClient().dio;
  late TabController _tabController;

  List<Map<String, dynamic>> _categories = [];
  final Map<String, List<Map<String, dynamic>>> _pricingUnitsByCategory = {};
  List<Map<String, dynamic>> _contractTypes = [];
  bool _isLoading = true;
  String? _error;
  String? _expandedCategoryId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    setState(() => _isLoading = true);
    try {
      final [catRes, contractRes] = await Future.wait([
        _dio.get(ApiEndpoints.adminCategories),
        _dio.get(ApiEndpoints.adminContractTypes),
      ]);

      final catData = catRes.data['data'] as List? ?? [];
      _categories = catData.cast<Map<String, dynamic>>();
      for (final cat in _categories) {
        final catId = cat['id'] as String;
        await _fetchPricingUnits(catId);
      }

      final contractData = contractRes.data['data'] as List? ?? [];
      _contractTypes = contractData.cast<Map<String, dynamic>>();

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

  Future<void> _fetchPricingUnits(String categoryId) async {
    try {
      final res =
          await _dio.get(ApiEndpoints.adminPricingUnits(categoryId));
      final data = res.data['data'] as List? ?? [];
      _pricingUnitsByCategory[categoryId] = data.cast<Map<String, dynamic>>();
    } catch (e) {
      _pricingUnitsByCategory[categoryId] = [];
    }
  }

  // ─── Pricing Units CRUD ───

  Future<void> _showCreatePricingUnitDialog(
      String categoryId, String categoryName) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _PricingUnitFormDialog(
        title: 'Tambah Satuan Harga',
        categoryHint: categoryName,
      ),
    );
    if (result == null) return;

    try {
      await _dio.post(ApiEndpoints.adminCreatePricingUnit, data: {
        'categoryId': categoryId,
        'name': result['name'],
        'unit': result['unit'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Satuan harga berhasil dibuat'),
              backgroundColor: Colors.green),
        );
        await _fetchPricingUnits(categoryId);
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

  Future<void> _showEditPricingUnitDialog(
      Map<String, dynamic> pricingUnit, String categoryName) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _PricingUnitFormDialog(
        title: 'Edit Satuan Harga',
        categoryHint: categoryName,
        initialName: pricingUnit['name'] as String? ?? '',
        initialUnit: pricingUnit['unit'] as String? ?? '',
      ),
    );
    if (result == null) return;

    final id = pricingUnit['id'] as String;
    try {
      await _dio.put(ApiEndpoints.adminUpdatePricingUnit(id), data: {
        'name': result['name'],
        'unit': result['unit'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Satuan harga berhasil diupdate'),
              backgroundColor: Colors.green),
        );
        final catId = pricingUnit['category_id'] as String? ?? '';
        if (catId.isNotEmpty) {
          await _fetchPricingUnits(catId);
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

  Future<void> _deletePricingUnit(Map<String, dynamic> pricingUnit) async {
    final name = pricingUnit['name'] as String? ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Satuan Harga'),
        content: Text(
            'Yakin ingin menghapus "$name"? Satuan harga yang masih digunakan tidak dapat dihapus.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final id = pricingUnit['id'] as String;
    final catId = pricingUnit['category_id'] as String? ?? '';
    try {
      await _dio.delete(ApiEndpoints.adminDeletePricingUnit(id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Satuan harga berhasil dihapus'),
              backgroundColor: Colors.green),
        );
        if (catId.isNotEmpty) {
          await _fetchPricingUnits(catId);
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

  // ─── Contract Types CRUD ───

  Future<void> _showCreateContractTypeDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => const _ContractTypeFormDialog(
        title: 'Tambah Tipe Kontrak',
      ),
    );
    if (result == null) return;

    try {
      await _dio.post(ApiEndpoints.adminCreateContractType, data: {
        'name': result['name'],
        'unit': result['unit'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Tipe kontrak berhasil dibuat'),
              backgroundColor: Colors.green),
        );
        await _fetchAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showEditContractTypeDialog(
      Map<String, dynamic> contractType) async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _ContractTypeFormDialog(
        title: 'Edit Tipe Kontrak',
        initialName: contractType['name'] as String? ?? '',
        initialUnit: contractType['unit'] as String? ?? '',
      ),
    );
    if (result == null) return;

    final id = contractType['id'] as String;
    try {
      await _dio.put(ApiEndpoints.adminUpdateContractType(id), data: {
        'name': result['name'],
        'unit': result['unit'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Tipe kontrak berhasil diupdate'),
              backgroundColor: Colors.green),
        );
        await _fetchAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteContractType(Map<String, dynamic> contractType) async {
    final name = contractType['name'] as String? ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Tipe Kontrak'),
        content: Text(
            'Yakin ingin menghapus "$name"? Tipe kontrak yang masih digunakan tidak dapat dihapus.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final id = contractType['id'] as String;
    try {
      await _dio.delete(ApiEndpoints.adminDeleteContractType(id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Tipe kontrak berhasil dihapus'),
              backgroundColor: Colors.green),
        );
        await _fetchAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Kelola Harga'),
        backgroundColor: const Color(0xFF00A651),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Satuan Harga'),
            Tab(text: 'Tipe Kontrak'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchAll),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [_buildPricingUnitsTab(), _buildContractTypesTab()],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: _fetchAll, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }

  // ─── Pricing Units Tab ───

  Widget _buildPricingUnitsTab() {
    if (_categories.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Tidak ada kategori',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
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
    final units = _pricingUnitsByCategory[catId] ?? [];
    final isExpanded = _expandedCategoryId == catId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1,
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(
                () => _expandedCategoryId = isExpanded ? null : catId),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.category,
                      color: Color(0xFF00A651), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(catName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 2),
                        Text('${units.length} satuan harga',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        color: Color(0xFF00A651)),
                    tooltip: 'Tambah Satuan Harga',
                    onPressed: () =>
                        _showCreatePricingUnitDialog(catId, catName),
                  ),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Colors.grey),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            if (units.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Belum ada satuan harga',
                    style: TextStyle(color: Colors.grey)),
              )
            else
              ...units.map((pu) => _buildPricingUnitTile(pu, catName)),
          ],
        ],
      ),
    );
  }

  Widget _buildPricingUnitTile(
      Map<String, dynamic> pu, String categoryName) {
    final name = pu['name'] as String? ?? '-';
    final unit = pu['unit'] as String? ?? '-';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: const Icon(Icons.straighten,
          size: 20, color: Color(0xFFF59E0B)),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text('Unit: $unit', style: const TextStyle(fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Edit',
            onPressed: () => _showEditPricingUnitDialog(pu, categoryName),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
            tooltip: 'Hapus',
            onPressed: () => _deletePricingUnit(pu),
          ),
        ],
      ),
    );
  }

  // ─── Contract Types Tab ───

  Widget _buildContractTypesTab() {
    return RefreshIndicator(
      onRefresh: _fetchAll,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Harian & Borongan (Perbaikan Bangunan)',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline,
                      color: Color(0xFF00A651)),
                  tooltip: 'Tambah Tipe Kontrak',
                  onPressed: _showCreateContractTypeDialog,
                ),
              ],
            ),
          ),
          if (_contractTypes.isEmpty)
            const Expanded(
              child: Center(
                child: Text('Belum ada tipe kontrak',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _contractTypes.length,
                itemBuilder: (_, i) => _buildContractTypeTile(_contractTypes[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContractTypeTile(Map<String, dynamic> ct) {
    final name = ct['name'] as String? ?? '-';
    final unit = ct['unit'] as String? ?? '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: const Icon(Icons.calendar_today,
            size: 20, color: Color(0xFF2563EB)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text('Unit: $unit', style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              tooltip: 'Edit',
              onPressed: () => _showEditContractTypeDialog(ct),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: Colors.red),
              tooltip: 'Hapus',
              onPressed: () => _deleteContractType(ct),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Pricing Unit Form Dialog ───

class _PricingUnitFormDialog extends StatefulWidget {
  final String title;
  final String categoryHint;
  final String? initialName;
  final String? initialUnit;

  const _PricingUnitFormDialog({
    required this.title,
    required this.categoryHint,
    this.initialName,
    this.initialUnit,
  });

  @override
  State<_PricingUnitFormDialog> createState() => _PricingUnitFormDialogState();
}

class _PricingUnitFormDialogState extends State<_PricingUnitFormDialog> {
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
                labelText: 'Nama Satuan Harga *',
                hintText: 'Contoh: per_titik, per_kunjungan',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _unitCtrl,
              decoration: const InputDecoration(
                labelText: 'Unit *',
                hintText: 'Contoh: titik, kunjungan',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A651)),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'name': _nameCtrl.text.trim(),
                'unit': _unitCtrl.text.trim(),
              });
            }
          },
          child: const Text('Simpan', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ─── Contract Type Form Dialog ───

class _ContractTypeFormDialog extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialUnit;

  const _ContractTypeFormDialog({
    required this.title,
    this.initialName,
    this.initialUnit,
  });

  @override
  State<_ContractTypeFormDialog> createState() =>
      _ContractTypeFormDialogState();
}

class _ContractTypeFormDialogState extends State<_ContractTypeFormDialog> {
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
            const Text('Tipe kontrak hanya untuk kategori Perbaikan Bangunan',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Tipe Kontrak *',
                hintText: 'Contoh: Harian, Borongan',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _unitCtrl,
              decoration: const InputDecoration(
                labelText: 'Unit *',
                hintText: 'Contoh: hari, paket',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A651)),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'name': _nameCtrl.text.trim(),
                'unit': _unitCtrl.text.trim(),
              });
            }
          },
          child: const Text('Simpan', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
