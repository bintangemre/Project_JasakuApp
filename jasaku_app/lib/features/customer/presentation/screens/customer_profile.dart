import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/constants/api_endpoints.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/models/customer_profile_model.dart';
import '../providers/customer_profile_provider.dart';
import '../../../orders/domain/models/order_model.dart';

class CustomerProfile extends ConsumerStatefulWidget {
  const CustomerProfile({super.key});

  @override
  ConsumerState<CustomerProfile> createState() => _CustomerProfileState();
}

class _CustomerProfileState extends ConsumerState<CustomerProfile> {
  List<OrderModel> _completedOrders = [];
  bool _loadingOrders = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(customerProfileProvider.notifier).fetchProfile();
      _fetchCompletedOrders();
    });
  }

  Future<void> _fetchCompletedOrders() async {
    setState(() => _loadingOrders = true);
    try {
      final res = await ApiClient().dio.get(ApiEndpoints.getCustomerOrders);
      final list = res.data['data'] as List? ?? [];
      final orders = list.map((e) => OrderModel.fromCustomerJson(e as Map<String, dynamic>)).toList();
      setState(() => _completedOrders = orders.where((o) => o.status == 'completed').toList());
    } catch (_) {}
    setState(() => _loadingOrders = false);
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (file == null) return;
    final err = await ref.read(customerProfileProvider.notifier).uploadAvatar(file.path);
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  void _showEditDialog(String title, String current, {bool multiline = false, required ValueChanged<String> onSave}) {
    final controller = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: multiline
            ? TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(border: OutlineInputBorder()))
            : TextField(controller: controller, decoration: const InputDecoration(border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onSave(controller.text);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveName(String newName) async {
    final err = await ref.read(customerProfileProvider.notifier).updateProfile(fullName: newName);
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(customerProfileProvider);
    final authState = ref.watch(authProvider);
    final profile = profileState.data;
    final profileData = profile?.profile;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Profil Saya'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: profileState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : profileState.error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('Gagal memuat profil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(profileState.error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => ref.read(customerProfileProvider.notifier).fetchProfile(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildAvatarSection(profileData, profileState.isSaving, authState.user?.displayName ?? 'Customer'),
                  const SizedBox(height: 16),
                  _buildInfoAkun(profile),
                  const SizedBox(height: 16),
                  _buildDataDiri(profileData),
                  const SizedBox(height: 16),
                  _buildRiwayatPesanan(),
                  const SizedBox(height: 16),
                  _buildLogout(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildAvatarSection(CustomerProfileData? data, bool isSaving, String displayName) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: data?.avatarUrl != null
                      ? NetworkImage('${ApiEndpoints.baseUrl}${data!.avatarUrl}')
                      : null,
                  child: data?.avatarUrl == null
                      ? const Icon(Icons.person, size: 50, color: Colors.grey)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickAndUploadAvatar,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                      child: isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(data?.fullName ?? displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoAkun(CustomerProfileModel? profile) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Info Akun', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            _infoRow(Icons.email_outlined, 'Email', profile?.email ?? '-'),
            const SizedBox(height: 8),
            _infoRow(Icons.phone_outlined, 'No. HP', profile?.phone ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _buildDataDiri(CustomerProfileData? data) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informasi Data Diri', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(),
            _editableRow(Icons.person_outline, 'Nama Lengkap', data?.fullName ?? '-', () {
              _showEditDialog('Ubah Nama Lengkap', data?.fullName ?? '', onSave: _saveName);
            }),
            const SizedBox(height: 8),
            _infoRow(Icons.face_outlined, 'Nama Panggilan', data?.nickname ?? '-'),
            const SizedBox(height: 8),
            _infoRow(Icons.cake_outlined, 'Tanggal Lahir', data?.birthDate ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _buildRiwayatPesanan() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Riwayat Pemesanan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('${_completedOrders.length} pesanan', style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
            const Divider(),
            if (_loadingOrders)
              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
            else if (_completedOrders.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Text('Belum ada pesanan selesai', style: TextStyle(color: Colors.grey)))
            else
              ...(_completedOrders.take(5).map((o) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.providerName ?? 'Provider', style: const TextStyle(fontWeight: FontWeight.w500)),
                              Text(o.formattedDate, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                        Text('Rp ${o.formattedPrice}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                      ],
                    ),
                  ))),
          ],
        ),
      ),
    );
  }

  Widget _buildLogout() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          ref.read(authProvider.notifier).logout();
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        },
        icon: const Icon(Icons.logout, color: Colors.red),
        label: const Text('Logout', style: TextStyle(color: Colors.red)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.grey))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
      ],
    );
  }

  Widget _editableRow(IconData icon, String label, String value, VoidCallback onEdit) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(width: 12),
        SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.grey))),
        Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        GestureDetector(onTap: onEdit, child: const Icon(Icons.edit, size: 18, color: Color(0xFF2563EB))),
      ],
    );
  }
}
