import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/payment_repository.dart';
import '../../domain/models/payment_method_model.dart';

final payoutMethodsProvider = FutureProvider.autoDispose<List<PayoutMethod>>((ref) {
  return PaymentRepository().getMyPayoutMethods();
});

class ProviderPayoutScreen extends ConsumerStatefulWidget {
  const ProviderPayoutScreen({super.key});

  @override
  ConsumerState<ProviderPayoutScreen> createState() => _ProviderPayoutScreenState();
}

class _ProviderPayoutScreenState extends ConsumerState<ProviderPayoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _providerNameCtrl = TextEditingController();
  String _type = 'bank';
  bool _isEditing = false;
  String? _editId;

  @override
  void dispose() {
    _accountNameCtrl.dispose();
    _accountNumberCtrl.dispose();
    _providerNameCtrl.dispose();
    super.dispose();
  }

  void _showForm([PayoutMethod? existing]) {
    if (existing != null) {
      _type = existing.type;
      _providerNameCtrl.text = existing.providerName;
      _accountNumberCtrl.text = existing.accountNumber;
      _accountNameCtrl.text = existing.accountName;
      _isEditing = true;
      _editId = existing.id;
    } else {
      _type = 'bank';
      _providerNameCtrl.clear();
      _accountNumberCtrl.clear();
      _accountNameCtrl.clear();
      _isEditing = false;
      _editId = null;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isEditing ? 'Edit Metode Penerimaan' : 'Tambah Metode Penerimaan',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _type,
                decoration: InputDecoration(
                  labelText: 'Tipe',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                items: const [
                  DropdownMenuItem(value: 'bank', child: Text('Rekening Bank')),
                  DropdownMenuItem(value: 'ewallet', child: Text('E-Wallet')),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'bank'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _providerNameCtrl,
                decoration: InputDecoration(
                  labelText: _type == 'bank' ? 'Nama Bank' : 'Nama E-Wallet',
                  hintText: _type == 'bank' ? 'BCA / Mandiri / BSI' : 'GoPay / OVO / Dana',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _accountNumberCtrl,
                decoration: InputDecoration(
                  labelText: _type == 'bank' ? 'Nomor Rekening' : 'Nomor HP E-Wallet',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _accountNameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nama Pemilik',
                  hintText: 'Nama sesuai rekening/ewallet',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _submit,
                  child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final method = PayoutMethod(
        id: '',
        type: _type,
        providerName: _providerNameCtrl.text,
        accountNumber: _accountNumberCtrl.text,
        accountName: _accountNameCtrl.text,
      );
      if (_isEditing && _editId != null) {
        await PaymentRepository().updatePayoutMethod(_editId!, method);
      } else {
        await PaymentRepository().createPayoutMethod(method);
      }
      ref.invalidate(payoutMethodsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'Berhasil diupdate' : 'Berhasil ditambahkan')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus?'),
        content: const Text('Metode penerimaan ini akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await PaymentRepository().deletePayoutMethod(id);
      ref.invalidate(payoutMethodsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil dihapus')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final methodsAsync = ref.watch(payoutMethodsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text('Metode Penerimaan', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2563EB),
        onPressed: () => _showForm(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: methodsAsync.when(
        data: (methods) {
          if (methods.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Belum ada metode penerimaan', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  SizedBox(height: 8),
                  Text('Tambahkan rekening bank atau e-wallet', style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: methods.length,
            itemBuilder: (_, i) {
              final m = methods[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: m.type == 'bank' ? const Color(0xFFE0E7FF) : const Color(0xFFDCFCE7),
                    child: Icon(m.type == 'bank' ? Icons.account_balance : Icons.wallet, color: m.type == 'bank' ? const Color(0xFF2563EB) : const Color(0xFF16A34A)),
                  ),
                  title: Text(m.accountName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${m.providerName} - ${m.accountNumber}', style: const TextStyle(fontSize: 13)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _showForm(m)),
                      IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red), onPressed: () => _delete(m.id)),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Gagal memuat: $err')),
      ),
    );
  }
}
