import 'dart:io'; // Untuk mengelola file gambar fisik di HP
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart'; 
import 'package:latlong2/latlong.dart'; 
import 'package:image_picker/image_picker.dart'; // Impor Pengelola Kamera & Galeri

import '../../../orders/presentation/providers/orders_provider.dart';
import '../../../orders/domain/models/order_payload_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';
import '../../../payments/presentation/widgets/payment_method_picker.dart';
import '../../../payments/presentation/screens/payment_instruction_screen.dart';

class CustomerOrdersPage extends ConsumerStatefulWidget {
  final String providerId;
  final String providerName;
  final String serviceId;
  final String pricingTypeId;
  final double basePrice;

  const CustomerOrdersPage({
    super.key,
    required this.providerId,
    required this.providerName,
    required this.serviceId,
    required this.pricingTypeId,
    required this.basePrice,
  });

  @override
  ConsumerState<CustomerOrdersPage> createState() => _CustomerOrdersPageState();
}

class _CustomerOrdersPageState extends ConsumerState<CustomerOrdersPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descController = TextEditingController();

  LatLng _selectedLocation = const LatLng(-3.4423, 114.8321);
  final MapController _mapController = MapController();

  int _quantity = 1;
  final double _platformFee = 2000;
  bool _isFetchingGPS = false;

  // 🟢 STATE UNTUK MENAMPUNG FILE FOTO YANG DIPILIH
  final List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  // 🟢 STATE METODE PEMBAYARAN — selalu rekber
  String _selectedPaymentMethod = '';

  @override
  void initState() {
    super.initState();
    _getCurrentCustomerLocation();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _addressController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentCustomerLocation() async {
    setState(() => _isFetchingGPS = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        
        setState(() {
          _selectedLocation = LatLng(position.latitude, position.longitude);
          _isFetchingGPS = false;
        });

        _mapController.move(_selectedLocation, 15.0);
      } else {
        setState(() => _isFetchingGPS = false);
      }
    } catch (e) {
      setState(() => _isFetchingGPS = false);
      debugPrint("Gagal mengambil GPS: $e");
    }
  }

  // 🟢 FUNGSI MENAMPILKAN PILIHAN KAMERA / GALERI (BOTTOM SHEET)
  void _showImagePickerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: Colors.blue),
                title: const Text('Ambil Lewat Kamera HP'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Colors.blue),
                title: const Text('Pilih dari Galeri Foto'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 🟢 LOGIKA PROSES PENGAMBILAN GAMBAR
  Future<void> _pickImage(ImageSource source) async {
    if (_selectedImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Maksimal unggahan adalah 5 foto")),
      );
      return;
    }

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70, // Kompres gambar ke 70% agar hemat bandwidth kuota / Supabase storage
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImages.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      debugPrint("Error mengambil gambar: $e");
    }
  }

  // 🟢 FUNGSI MENGHAPUS FOTO JIKA USER SALAH PILIH
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalServicePrice = widget.basePrice * _quantity;
    double grandTotal = totalServicePrice + _platformFee;

    ref.listen<OrderFormState>(orderFormProvider, (previous, next) {
      if (next.isSuccess) {
        ref.read(unreadNotifProvider.notifier).state++;
        if (next.orderId != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => PaymentInstructionScreen(
                orderId: next.orderId!,
                paymentMethodId: next.paymentMethod ?? '',
                totalAmount: grandTotal,
              ),
            ),
          );
        }
      } else if (next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${next.errorMessage}")),
        );
      }
    });

    final orderState = ref.watch(orderFormProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        title: const Text(
          "Pesan Layanan",
          style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: orderState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // KARTU 1: DETAIL LAYANAN
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("LAYANAN YANG DIPESAN",
                              style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(color: Color(0xFFEFF6FF), shape: BoxShape.circle),
                                child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF2563EB), size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(widget.providerName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text("Rp ${NumberFormat('#,###', 'id_ID').format(widget.basePrice)} / per hari",
                                        style: const TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              )
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Durasi Kerja (Hari)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                                    icon: const Icon(Icons.remove_circle_outline),
                                  ),
                                  Text("$_quantity", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                  IconButton(
                                    onPressed: () => setState(() => _quantity++),
                                    icon: const Icon(Icons.add_circle_outline, color: Colors.blue),
                                  ),
                                ],
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // KARTU 2: INPUT TANGGAL
                    const Text("Tanggal Pelaksanaan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _dateController,
                      readOnly: true,
                      onTap: () => _selectDate(context),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                        hintText: "Pilih Tanggal Mulai",
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      validator: (v) => v!.isEmpty ? "Tanggal wajib ditentukan" : null,
                    ),
                    const SizedBox(height: 16),

                    // KARTU 3: LOKASI & PETA MINI
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Lokasi Pengerjaan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        if (_isFetchingGPS)
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue))
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 170,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _selectedLocation,
                            initialZoom: 15.0,
                            onTap: (tapPosition, point) {
                              setState(() {
                                _selectedLocation = point;
                              });
                            },
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.jasaku.app',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _selectedLocation,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(Icons.person_pin_circle, color: Colors.red, size: 36),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        hintText: "Ketik Alamat Lengkap Detail Rumah/Gedung",
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (v) => v!.isEmpty ? "Alamat detail wajib diisi" : null,
                    ),
                    const SizedBox(height: 16),

                    // KARTU 4: DESKRIPSI TUGAS
                    const Text("Deskripsi Pekerjaan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: "Contoh: Tolong perbaiki dinding retak kamar mandi belakang ukuran 2x3 meter...",
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // KARTU 5: UNGGAH FOTO PENDUKUNG (SUDAH AKTIF AKTUAL)
                    const Text("Foto Pendukung (Opsional)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    
                    // Tombol Trigger Ambil Foto
                    InkWell(
                      onTap: () => _showImagePickerOptions(context),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1, style: BorderStyle.solid),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.image_outlined, size: 36, color: Color(0xFF94A3B8)),
                            SizedBox(height: 8),
                            Text(
                              "Ambil Foto atau Pilih Gambar Galeri",
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF475569)),
                            ),
                            SizedBox(height: 4),
                            Text(
                              "Maksimal 5 foto pendukung kerusakkan",
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // 🟢 PREVIEW HORIZONTAL DARI LIST FOTO YANG BERHASIL DIAMBIL
                    if (_selectedImages.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedImages.length,
                          itemBuilder: (context, index) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      _selectedImages[index],
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return const SizedBox(
                                          width: 80,
                                          height: 80,
                                          child: Icon(Icons.broken_image, color: Colors.red),
                                        );
                                      },
                                    ),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(index),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    // KARTU 6: METODE PEMBAYARAN
                    const Text("Metode Pembayaran", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 8),
                    PaymentMethodPicker(
                      selectedId: _selectedPaymentMethod,
                      onChanged: (id) => setState(() => _selectedPaymentMethod = id),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
       
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Harga Jasa", style: TextStyle(color: Colors.grey)),
                  Text("Rp ${NumberFormat('#,###', 'id_ID').format(totalServicePrice)}")
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Biaya Aplikasi", style: TextStyle(color: Colors.grey)),
                  Text("Rp ${NumberFormat('#,###', 'id_ID').format(_platformFee)}")
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total Pembayaran", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text("Rp ${NumberFormat('#,###', 'id_ID').format(grandTotal)}",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue))
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final payload = OrderPayloadModel(
                        customerId: ref.read(authProvider).user?.id ?? '', 
                        providerId: widget.providerId,
                        serviceId: widget.serviceId,
                        pricingTypeId: widget.pricingTypeId,
                        quantity: _quantity,
                        description: _descController.text,
                        workDate: _dateController.text,
                        address: _addressController.text,
                        lat: _selectedLocation.latitude,
                        lng: _selectedLocation.longitude,
                        // Kirim path list foto lokal ke model kirim payload
                        attachments: _selectedImages.map((e) => e.path).toList(),
                      );

                      ref.read(orderFormProvider.notifier).submitNewOrder(
                        payload: payload,
                        paymentMethod: _selectedPaymentMethod,
                        paymentAmount: grandTotal,
                      );
                    }
                  },
                  child: const Text("Konfirmasi Pesanan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}