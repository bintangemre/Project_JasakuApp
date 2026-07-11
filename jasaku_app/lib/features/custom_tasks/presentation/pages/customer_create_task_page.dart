import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/custom_tasks_repository.dart';

class CustomerCreateTaskPage extends ConsumerStatefulWidget {
  const CustomerCreateTaskPage({super.key});

  @override
  ConsumerState<CustomerCreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends ConsumerState<CustomerCreateTaskPage> {
  final _titleC = TextEditingController();
  final _descC = TextEditingController();
  final _locationDetailC = TextEditingController();
  final _budgetC = TextEditingController();
  final _peopleC = TextEditingController(text: '1');
  final _searchC = TextEditingController();
  final _repo = CustomTasksRepository();
  final List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  LatLng? _baseLocation;
  final List<_TaskPoint> _points = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _submitting = false;
  bool _searching = false;
  int _publishDays = 1;
  late MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition();
      setState(() => _baseLocation = LatLng(pos.latitude, pos.longitude));
      _mapController.move(_baseLocation!, 14);
    } catch (_) {}
  }

  Future<void> _searchPlace(String q) async {
    if (q.length < 3) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final results = await _repo.searchLocation(q,
        lat: _baseLocation?.latitude, lng: _baseLocation?.longitude);
    setState(() {
      _searchResults = results;
      _searching = false;
    });
  }

  void _addPoint(double lat, double lng, String address, {String? label}) {
    setState(() {
      _points.add(_TaskPoint(
        lat: lat,
        lng: lng,
        address: address,
        label: label ?? 'Titik ${_points.length + 1}',
      ));
      _searchResults = [];
      _searchC.clear();
    });
  }

  void _removePoint(int index) {
    setState(() => _points.removeAt(index));
  }

  Future<void> _submit() async {
    if (_titleC.text.trim().isEmpty) {
      _showError('Judul task wajib diisi');
      return;
    }
    final budget = double.tryParse(_budgetC.text.replaceAll('.', '').replaceAll(',', '.'));
    if (budget == null || budget <= 0) {
      _showError('Budget per orang wajib diisi');
      return;
    }
    final people = int.tryParse(_peopleC.text) ?? 1;
    if (people < 1) {
      _showError('Jumlah orang minimal 1');
      return;
    }
    if (_baseLocation == null) {
      _showError('Pilih lokasi di map');
      return;
    }

    setState(() => _submitting = true);
    try {
      final locs = _points.map((p) => {
        'label': p.label,
        'address': p.address,
        'lat': p.lat,
        'lng': p.lng,
      }).toList();

      final locDetail = _locationDetailC.text.trim();
      await _repo.createTask(
        title: _titleC.text.trim(),
        description: _descC.text.trim().isEmpty ? null : _descC.text.trim(),
        budgetPerPerson: budget,
        requiredPeople: people,
        address: '${_baseLocation!.latitude}, ${_baseLocation!.longitude}',
        lat: _baseLocation!.latitude,
        lng: _baseLocation!.longitude,
        locations: locs,
        locationDetail: locDetail.isEmpty ? null : locDetail,
        publishDays: _publishDays,
        images: _selectedImages,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task berhasil dibuat!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: Colors.blue),
                title: const Text('Ambil Lewat Kamera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Colors.blue),
                title: const Text('Pilih dari Galeri'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_selectedImages.length >= 5) {
      _showError('Maksimal 5 foto');
      return;
    }
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 70);
      if (picked != null) {
        setState(() => _selectedImages.add(File(picked.path)));
      }
    } catch (_) {}
  }

  void _removeImage(int idx) {
    setState(() => _selectedImages.removeAt(idx));
  }

  @override
  void dispose() {
    _titleC.dispose();
    _descC.dispose();
    _budgetC.dispose();
    _peopleC.dispose();
    _searchC.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buat Task Baru')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleC,
              decoration: const InputDecoration(
                labelText: 'Judul Task',
                hintText: 'Cth: Bantu angkut barang',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descC,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Deskripsi (opsional)',
                hintText: 'Jelaskan detail task...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Lokasi & Titik Tujuan',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _baseLocation ?? const LatLng(-6.2, 106.8),
                    initialZoom: 13,
                    onTap: (tapPos, latlng) {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Tambah Titik'),
                          content: Text(
                              'Tambah titik di:\n${latlng.latitude.toStringAsFixed(5)}, ${latlng.longitude.toStringAsFixed(5)}?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx),
                                child: const Text('Batal')),
                            FilledButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _addPoint(latlng.latitude, latlng.longitude,
                                    '${latlng.latitude.toStringAsFixed(5)}, ${latlng.longitude.toStringAsFixed(5)}');
                              },
                              child: const Text('Tambah'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.jasaku.app',
                    ),
                    MarkerLayer(
                      markers: [
                        if (_baseLocation != null)
                          Marker(
                            point: _baseLocation!,
                            width: 40, height: 40,
                            child: const Icon(Icons.my_location,
                                color: Color(0xFF2563EB), size: 32),
                          ),
                        for (int i = 0; i < _points.length; i++)
                          Marker(
                            point: LatLng(_points[i].lat, _points[i].lng),
                            width: 30, height: 30,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Center(
                                child: Text('${i + 1}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchC,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, size: 20),
                hintText: 'Cari tempat...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                suffixIcon: _searching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onChanged: _searchPlace,
            ),
            if (_searchResults.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = _searchResults[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on_outlined, size: 18),
                      title: Text(r['label'] as String? ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      subtitle: Text(r['address'] as String? ?? '',
                          style: const TextStyle(fontSize: 11)),
                      onTap: () => _addPoint(
                        (r['lat'] as num).toDouble(),
                        (r['lng'] as num).toDouble(),
                        r['address'] as String? ?? '',
                        label: r['label'] as String?,
                      ),
                    );
                  },
                ),
              ),
            if (_points.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...List.generate(_points.length, (i) {
                final p = _points[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.red,
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ),
                    title: Text(p.label ?? 'Titik ${i + 1}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text(p.address,
                        style: const TextStyle(fontSize: 11)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _removePoint(i),
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _locationDetailC,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Detail Lokasi (opsional)',
                hintText: 'Cth: Rumah cat hijau, no. 15, gang samping masjid',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.timer_outlined, size: 18, color: Colors.grey),
                SizedBox(width: 8),
                Text('Masa publish:',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: List.generate(3, (i) {
                final days = i + 1;
                final selected = _publishDays == days;
                return ChoiceChip(
                  label: Text('$days hari',
                      style: TextStyle(
                          fontSize: 12,
                          color: selected ? Colors.white : null)),
                  selected: selected,
                  selectedColor: const Color(0xFF2563EB),
                  onSelected: (_) => setState(() => _publishDays = days),
                  visualDensity: VisualDensity.compact,
                );
              }),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _budgetC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Budget /orang',
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _peopleC,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Jumlah Orang',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildPaymentSummary(),
            const SizedBox(height: 16),
            const Text('Foto Pendukung (opsional)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _showImagePickerOptions,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.image_outlined, size: 36, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text('Ambil Foto atau Pilih Gambar',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey[700])),
                    const SizedBox(height: 4),
                    const Text('Maksimal 5 foto', style: TextStyle(color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
            ),
            if (_selectedImages.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedImages[index],
                              width: 80, height: 80, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox(width: 80, height: 80, child: Icon(Icons.broken_image)),
                            ),
                          ),
                          Positioned(
                            top: 2, right: 2,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ));
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(_submitting ? 'Membuat...' : 'Buat Task'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentSummary() {
    final budget = double.tryParse(_budgetC.text.replaceAll('.', '').replaceAll(',', '.'));
    final people = int.tryParse(_peopleC.text) ?? 1;

    if (budget == null || budget <= 0) return const SizedBox.shrink();

    final f = NumberFormat('#,###', 'id_ID');
    final totalBudget = budget * people;
    final fee = totalBudget * 5 / 100;
    final totalPayable = totalBudget + fee;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ringkasan Pembayaran',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const Divider(height: 20),
          _row('Budget per orang',
              'Rp ${f.format(budget)}/orang'),
          _row('Jumlah orang', '$people orang'),
          _row('Total budget',
              'Rp ${f.format(totalBudget)}'),
          _row('Fee aplikasi 5%',
              'Rp ${f.format(fee)}'),
          const Divider(height: 16),
          _row('Total dibayar',
              'Rp ${f.format(totalPayable)}',
              bold: true),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }
}

class _TaskPoint {
  final double lat;
  final double lng;
  final String address;
  final String? label;

  _TaskPoint({
    required this.lat,
    required this.lng,
    required this.address,
    this.label,
  });
}
