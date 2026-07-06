import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class KtpScannerScreen extends StatefulWidget {
  const KtpScannerScreen({super.key});

  @override
  State<KtpScannerScreen> createState() => _KtpScannerScreenState();
}

class _KtpScannerScreenState extends State<KtpScannerScreen> {
  final _picker = ImagePicker();
  File? _image;
  bool _processing = false;
  String? _error;

  String? _nik;
  String? _fullName;
  String? _birthPlace;
  String? _birthDate;
  String? _address;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickImage());
  }

  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Foto KTP',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Ambil Foto'),
                subtitle: const Text('Arahkan ke KTP Anda'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Galeri'),
                subtitle: const Text('Pilih dari galeri'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    final x = await _picker.pickImage(source: source, imageQuality: 90);
    if (x == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() {
      _image = File(x.path);
      _processing = true;
      _error = null;
    });
    await _processImage(_image!);
  }

  Future<void> _processImage(File file) async {
    try {
      final inputImage = InputImage.fromFile(file);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognizedText = await recognizer.processImage(inputImage);

      final text = recognizedText.text;
      _parseKtpText(text);

      await recognizer.close();
    } catch (e) {
      _error = 'Gagal membaca KTP: ${e.toString()}';
    }
    if (mounted) {
      setState(() => _processing = false);
    }
  }

  void _parseKtpText(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (_nik == null) {
        final nikMatch = RegExp(r'\b(\d{16})\b').firstMatch(line);
        if (nikMatch != null) {
          _nik = nikMatch.group(1);
        }
      }

      if (line.contains('NIK') && i + 1 < lines.length) {
        if (_nik == null) {
          final nikMatch = RegExp(r'\b(\d{16})\b').firstMatch(lines[i + 1]);
          if (nikMatch != null) _nik = nikMatch.group(1);
        }
      }

      if (line.contains('Nama') && i + 1 < lines.length) {
        final next = lines[i + 1];
        if (!next.contains(':') && !RegExp(r'\d{16}').hasMatch(next)) {
          _fullName ??= next;
        }
      }

      if (line.contains('Tempat') || line.contains('Lahir')) {
        if (i + 1 < lines.length) {
          final next = lines[i + 1];
          final parts = next.split(',');
          if (parts.length == 2) {
            _birthPlace = parts[0].trim();
            _birthDate = parts[1].trim();
          }
        }
      }

      final alamatIdx = lines.indexWhere((l) => l.contains('Alamat'));
      if (alamatIdx >= 0 && alamatIdx + 1 < lines.length) {
        final addrParts = <String>[];
        for (int j = alamatIdx + 1; j < lines.length; j++) {
          if (lines[j].contains('NIK') || lines[j].contains('Nama') || lines[j].contains('Tempat') || lines[j].contains('Pekerjaan') || lines[j].contains('Kewarganegaraan')) break;
          addrParts.add(lines[j]);
        }
        if (addrParts.isNotEmpty) {
          _address ??= addrParts.join(', ');
        }
      }
    }
  }

  void _confirm() {
    Navigator.pop(context, {
      'ktpPath': _image?.path,
      'nik': _nik,
      'fullName': _fullName,
      'birthPlace': _birthPlace,
      'birthDate': _birthDate,
      'address': _address,
    });
  }

  void _retake() {
    setState(() {
      _image = null;
      _nik = null;
      _fullName = null;
      _birthPlace = null;
      _birthDate = null;
      _address = null;
      _error = null;
    });
    _pickImage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text('Scan KTP',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: _image == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(_image!,
                          width: double.infinity,
                          height: 220,
                          fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 16),
                    if (_processing)
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Memproses KTP...',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.error_outline,
                                color: Colors.red.shade600, size: 40),
                            const SizedBox(height: 8),
                            Text(_error!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red.shade700)),
                          ],
                        ),
                      ),
                    if (!_processing && _error == null)
                      _buildResultCard(),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _retake,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Ulangi'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orange,
                              side: const BorderSide(color: Colors.orange),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (_processing || _error != null) ? null : _confirm,
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: const Text('Konfirmasi'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00A651),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF00A651), size: 20),
              const SizedBox(width: 8),
              const Text('Data Terbaca',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF00A651))),
            ],
          ),
          const SizedBox(height: 12),
          _dataRow('NIK', _nik ?? '-'),
          _dataRow('Nama', _fullName ?? '-'),
          _dataRow('Tempat Lahir', _birthPlace ?? '-'),
          _dataRow('Tanggal Lahir', _birthDate ?? '-'),
          _dataRow('Alamat', _address ?? '-'),
        ],
      ),
    );
  }

  Widget _dataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
