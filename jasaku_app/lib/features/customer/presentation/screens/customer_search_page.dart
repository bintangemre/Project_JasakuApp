import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/customer_search_provider.dart';
import 'customer_providers_by_category.dart';

class CustomerSearchPage extends ConsumerStatefulWidget {
  const CustomerSearchPage({super.key});

  @override
  ConsumerState<CustomerSearchPage> createState() => _CustomerSearchPageState();
}

class _CustomerSearchPageState extends ConsumerState<CustomerSearchPage> {
  final _searchC = TextEditingController();

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerSearchProvider);
    final notifier = ref.read(customerSearchProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: TextField(
          controller: _searchC,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Cari kategori atau layanan...',
            border: InputBorder.none,
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            suffixIcon: state.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : null,
          ),
          onChanged: (q) => notifier.search(q),
        ),
      ),
      body: _buildBody(state, notifier),
    );
  }

  Widget _buildBody(SearchState state, CustomerSearchNotifier notifier) {
    if (state.query.isEmpty || state.query.length < 2) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Ketik minimal 2 karakter untuk mencari',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.categories.isEmpty && state.services.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Tidak ditemukan untuk "${state.query}"',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (state.categories.isNotEmpty) ...[
          _sectionHeader('Kategori'),
          const SizedBox(height: 8),
          ...state.categories.map(_categoryTile),
          const SizedBox(height: 16),
        ],
        if (state.services.isNotEmpty) ...[
          _sectionHeader('Layanan'),
          const SizedBox(height: 8),
          ...state.services.map(_serviceTile),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
    );
  }

  Widget _categoryTile(SearchResultCategory cat) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.category, color: const Color(0xFF2563EB)),
        title: Text(cat.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerProvidersByCategory(categoryId: cat.id, categoryName: cat.name),
            ),
          );
        },
      ),
    );
  }

  Widget _serviceTile(SearchResultService svc) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.build, color: const Color(0xFF059669)),
        title: Text(svc.name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: svc.categoryName.isNotEmpty ? Text(svc.categoryName, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)) : null,
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CustomerProvidersByCategory(categoryId: svc.categoryId, categoryName: svc.categoryName),
            ),
          );
        },
      ),
    );
  }
}
