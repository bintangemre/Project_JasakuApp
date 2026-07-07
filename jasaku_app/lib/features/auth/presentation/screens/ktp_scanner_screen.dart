import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class KtpScannerScreen extends StatefulWidget {
  const KtpScannerScreen({super.key});

  @override
  State<KtpScannerScreen> createState() => _KtpScannerScreenState();
}

class _KtpScannerScreenState extends State<KtpScannerScreen> {
  final _picker = ImagePicker();
  bool _launching = false;

  File? _image;
  bool _processing = false;
  String? _error;

  String? _nik;
  String? _fullName;
  String? _birthPlace;
  String? _birthDate;
  String? _address;
  String? _gender;
  String? _bloodType;
  String? _religion;

  late TextEditingController _nikController;
  late TextEditingController _fullNameController;
  late TextEditingController _birthPlaceController;
  late TextEditingController _birthDateController;
  late TextEditingController _addressController;
  late TextEditingController _genderController;
  late TextEditingController _bloodTypeController;
  late TextEditingController _religionController;

  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    _initControllers();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScanning());
  }

  void _initControllers() {
    _nikController = TextEditingController();
    _fullNameController = TextEditingController();
    _birthPlaceController = TextEditingController();
    _birthDateController = TextEditingController();
    _addressController = TextEditingController();
    _genderController = TextEditingController();
    _bloodTypeController = TextEditingController();
    _religionController = TextEditingController();
  }

  @override
  void dispose() {
    _nikController.dispose();
    _fullNameController.dispose();
    _birthPlaceController.dispose();
    _birthDateController.dispose();
    _addressController.dispose();
    _genderController.dispose();
    _bloodTypeController.dispose();
    _religionController.dispose();
    super.dispose();
  }

  Future<void> _startScanning() async {
    if (_launching) return;
    setState(() => _launching = true);

    try {
      final options = DocumentScannerOptions(
        documentFormat: DocumentFormat.jpeg,
        mode: ScannerMode.base,
        pageLimit: 1,
        isGalleryImport: true,
      );

      final scanner = DocumentScanner(options: options);
      final result = await scanner.scanDocument();
      scanner.close();

      if (result.images.isEmpty) {
        if (mounted) Navigator.pop(context, null);
        return;
      }

      final file = File(result.images.first);
      if (!mounted) return;

      setState(() {
        _image = file;
        _showResult = true;
        _processing = true;
        _launching = false;
      });
      await _processImage(file);
    } catch (e) {
      if (mounted) {
        setState(() => _launching = false);
        _showError('Gagal memindai: $e');
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
    Navigator.pop(context, null);
  }

  Future<void> _pickFromGallery() async {
    try {
      final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
      if (x == null) return;
      if (!mounted) return;
      setState(() {
        _image = File(x.path);
        _showResult = true;
        _processing = true;
      });
      await _processImage(_image!);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Gagal memuat gambar: $e';
          _processing = false;
        });
      }
    }
  }

  Future<void> _processImage(File file) async {
    try {
      final inputImage = InputImage.fromFile(file);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final recognizedText = await recognizer.processImage(inputImage);

      final orderedLines = _getOrderedLines(recognizedText);
      _parseKtpText(orderedLines);

      await recognizer.close();
    } catch (e) {
      _error = 'Gagal membaca KTP: ${e.toString()}';
    }
    if (mounted) {
      setState(() {
        _processing = false;
        _syncControllers();
      });
    }
  }

  void _syncControllers() {
    _nikController.text = _nik ?? '';
    _fullNameController.text = _fullName ?? '';
    _birthPlaceController.text = _birthPlace ?? '';
    _birthDateController.text = _birthDate ?? '';
    _addressController.text = _address ?? '';
    _genderController.text = _gender ?? '';
    _bloodTypeController.text = _bloodType ?? '';
    _religionController.text = _religion ?? '';
  }

  /// Sort text lines by their bounding box position (Y then X)
  /// to get correct visual reading order from KTP layout.
  List<String> _getOrderedLines(RecognizedText recognizedText) {
    final textLines = <TextLine>[];
    for (final block in recognizedText.blocks) {
      textLines.addAll(block.lines);
    }

    textLines.sort((a, b) {
      final yDiff = a.boundingBox.top - b.boundingBox.top;
      if (yDiff.abs() > 8) return yDiff.round();
      return (a.boundingBox.left - b.boundingBox.left).round();
    });

    final merged = <String>[];
    String? currentLine;
    double? currentTop;

    for (final line in textLines) {
      if (currentTop == null || (line.boundingBox.top - currentTop).abs() > 8) {
        if (currentLine != null) merged.add(currentLine);
        currentLine = line.text;
        currentTop = line.boundingBox.top;
      } else {
        currentLine = '$currentLine ${line.text}';
      }
    }
    if (currentLine != null) merged.add(currentLine);

    return merged;
  }

  void _parseKtpText(List<String> lines) {
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineLower = line.toLowerCase();

      if (_nik == null) {
        final nikMatch = RegExp(r'\b(\d{16})\b').firstMatch(line);
        if (nikMatch != null) {
          _nik = nikMatch.group(1);
          continue;
        }
        if (lineLower.startsWith('nik') || lineLower.startsWith('nik ')) {
          final val = _extractValue(line, 'nik');
          final m = RegExp(r'\b(\d{16})\b').firstMatch(val);
          if (m != null) _nik = m.group(1);
          if (_nik == null && i + 1 < lines.length) {
            final next = lines[i + 1];
            final m2 = RegExp(r'\b(\d{16})\b').firstMatch(next);
            if (m2 != null && !_isLineLabel(next.toLowerCase())) _nik = m2.group(1);
          }
          continue;
        }
      }

      if (_fullName == null && _hasLabel(lineLower, 'nama')) {
        String val = _extractValue(line, 'nama');
        if (val.isNotEmpty && !_isLineLabel(val)) _fullName = val;
        if (_fullName == null && i + 1 < lines.length) {
          final next = lines[i + 1];
          if (next.isNotEmpty && !_isLineLabel(next)) _fullName = next;
        }
        continue;
      }

      if (_birthPlace == null && _birthDate == null &&
          (lineLower.contains('tempat') || lineLower.contains('tgl lahir') || lineLower.contains('tanggal lahir'))) {
        if (_hasLabel(lineLower, 'tempat/tgl lahir') || _hasLabel(lineLower, 'tempat/tgl') ||
            (_hasLabel(lineLower, 'tempat') && _hasLabel(lineLower, 'lahir'))) {
          String val;
          if (lineLower.contains('tempat/tgl')) {
            val = _extractValue(line, 'tempat/tgl lahir');
          } else {
            val = _extractValue(line, 'tempat');
          }
          if (val.isEmpty && i + 1 < lines.length) {
            val = lines[i + 1];
          }
          if (val.isNotEmpty && !_isLineLabel(val)) {
            final parts = val.split(',');
            _birthPlace = parts[0].trim();
            if (parts.length > 1) {
              _birthDate = parts.sublist(1).join(',').trim();
            }
          }
          continue;
        }
      }

      if (_gender == null && _hasLabel(lineLower, 'jenis kelamin')) {
        final afterLabel = _extractValue(line, 'jenis kelamin');
        final trimmed = afterLabel.trim();

        _gender = trimmed;

        if (trimmed.isNotEmpty) {
          final bloodMatch = RegExp(r'gol\.?\s*darah\s*[:\s]*\s*([a-zA-Z0-9+\\-]+)',
              caseSensitive: false).firstMatch(trimmed);
          if (bloodMatch != null) {
            _bloodType ??= bloodMatch.group(1)!.trim();
            _gender = trimmed.substring(0, bloodMatch.start).trim();
          }
        }
        continue;
      }

      if (_bloodType == null &&
          (_hasLabel(lineLower, 'gol. darah') || _hasLabel(lineLower, 'gol darah') || _hasLabel(lineLower, 'gol.'))) {
        String val;
        if (lineLower.contains('gol. darah')) {
          val = _extractValue(line, 'gol. darah');
        } else if (lineLower.contains('gol darah')) {
          val = _extractValue(line, 'gol darah');
        } else {
          val = _extractValue(line, 'gol.');
        }
        val = val.trim();
        if (val.isNotEmpty && !_isLineLabel(val)) _bloodType = val;
        if (_bloodType == null && i + 1 < lines.length) {
          final next = lines[i + 1].trim();
          if (next.isNotEmpty && !_isLineLabel(next) && next.length <= 3) _bloodType = next;
        }
        continue;
      }

      if (_address == null && _hasLabel(lineLower, 'alamat')) {
        String val = _extractValue(line, 'alamat');
        if (val.isEmpty) {
          if (i + 1 < lines.length) val = lines[i + 1];
        }
        if (val.isNotEmpty && !_isLineLabel(val)) _address = val;

        if (_address != null) {
          final addrParts = <String>[_address!];
          for (int j = i + 1; j < lines.length; j++) {
            final l = lines[j].toLowerCase();
            if (l.startsWith('agama') || l.startsWith('status') || l.startsWith('pekerjaan') ||
                l.startsWith('kewarganegaraan') || l.startsWith('berlaku')) {
              break;
            }
            if (l.startsWith('rt/rw') || l.startsWith('kel/desa') || l.startsWith('kecamatan')) {
              final subVal = _extractValue(lines[j], l.split(RegExp(r'[\s:]'))[0]);
              addrParts.add(subVal.isNotEmpty ? subVal : lines[j]);
            } else {
              break;
            }
          }
          _address = addrParts.join(', ');
        }
        continue;
      }

      if (_religion == null && _hasLabel(lineLower, 'agama')) {
        String val = _extractValue(line, 'agama');
        if (val.isNotEmpty && !_isLineLabel(val)) _religion = val;
        if (_religion == null && i + 1 < lines.length) {
          final next = lines[i + 1];
          if (next.isNotEmpty && !_isLineLabel(next)) _religion = next;
        }
        break;
      }
    }
  }

  bool _hasLabel(String lineLower, String label) {
    if (lineLower.startsWith(label)) return true;
    if (lineLower.startsWith('$label ')) return true;
    if (lineLower.startsWith('$label:')) return true;
    if (lineLower.startsWith('$label/')) return true;
    if (lineLower.replaceAll(RegExp(r'\s+'), '').startsWith(label.replaceAll(' ', ''))) return true;
    return false;
  }

  static const _labelSet = {
    'nik', 'nama', 'tempat', 'lahir', 'tempat/tgl lahir',
    'jenis kelamin', 'jenis',
    'gol. darah', 'gol darah', 'gol.',
    'alamat', 'rt/rw', 'kel/desa', 'kecamatan',
    'agama',
    'status perkawinan', 'pekerjaan',
    'kewarganegaraan', 'berlaku hingga',
  };

  bool _isLineLabel(String s) {
    final lower = s.toLowerCase().trim();
    if (lower.isEmpty) return false;
    if (_labelSet.contains(lower)) return true;
    for (final label in _labelSet) {
      if (lower.startsWith('$label ') || lower.startsWith('$label:')) return true;
    }
    return false;
  }

  String _extractValue(String line, String label) {
    final lineLower = line.toLowerCase();
    int labelIdx = lineLower.indexOf(label.toLowerCase());
    if (labelIdx < 0) return '';
    String afterLabel = line.substring(labelIdx + label.length).trim();
    if (afterLabel.startsWith(':')) {
      afterLabel = afterLabel.substring(1).trim();
    }
    return afterLabel;
  }

  void _confirm() {
    Navigator.pop(context, {
      'ktpPath': _image?.path,
      'nik': _nikController.text,
      'fullName': _fullNameController.text,
      'birthPlace': _birthPlaceController.text,
      'birthDate': _birthDateController.text,
      'address': _addressController.text,
      'gender': _genderController.text,
      'bloodType': _bloodTypeController.text,
      'religion': _religionController.text,
    });
  }

  void _retake() {
    setState(() {
      _image = null;
      _showResult = false;
      _processing = false;
      _error = null;
      _nik = null;
      _fullName = null;
      _birthPlace = null;
      _birthDate = null;
      _address = null;
      _gender = null;
      _bloodType = null;
      _religion = null;
    });
    _nikController.clear();
    _fullNameController.clear();
    _birthPlaceController.clear();
    _birthDateController.clear();
    _addressController.clear();
    _genderController.clear();
    _bloodTypeController.clear();
    _religionController.clear();
    _startScanning();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _showResult
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: Colors.black,
              title: const Text('Scan KTP',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            )
          : null,
      backgroundColor: Colors.white,
      body: _launching
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Membuka pemindai...',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : !_showResult
              ? _buildInitialView()
              : _buildResultView(),
    );
  }

  Widget _buildInitialView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.document_scanner, size: 72, color: Color(0xFF2563EB)),
          const SizedBox(height: 16),
          const Text('Scan KTP',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Posisikan KTP dalam bingkai',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _startScanning,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Buka Pemindai'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: _pickFromGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Pilih dari Galeri'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView() {
    return SafeArea(
      child: SingleChildScrollView(
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
              const Text('Periksa Data Anda',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF00A651))),
            ],
          ),
          const SizedBox(height: 4),
          Text('Lengkapi data anda sesuai KTP jika ada yang belum terisi',
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          const SizedBox(height: 12),
          _editableField('NIK', _nikController, maxLength: 16),
          _editableField('Nama', _fullNameController),
          _editableField('Tempat Lahir', _birthPlaceController),
          _editableField('Tanggal Lahir', _birthDateController),
          _editableField('Jenis Kelamin', _genderController),
          _editableField('Gol. Darah', _bloodTypeController, maxLength: 3),
          _editableField('Alamat', _addressController, maxLines: 3),
          _editableField('Agama', _religionController),
        ],
      ),
    );
  }

  Widget _editableField(String label, TextEditingController controller,
      {int? maxLength, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: controller,
                maxLength: maxLength,
                maxLines: maxLines,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  counterText: '',
                  contentPadding: EdgeInsets.symmetric(vertical: 6),
                ),
                onChanged: (value) {
                  if (value != value.toUpperCase()) {
                    controller.value = TextEditingValue(
                      text: value.toUpperCase(),
                      selection: controller.selection,
                    );
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
