import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_document_scanner/google_mlkit_document_scanner.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

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
        mode: ScannerMode.filter,
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

  Future<File> _preprocessImage(File file) async {
    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return file;

    final processed = img.grayscale(image);
    final w = processed.width;
    final h = processed.height;

    num luma(int x, int y) => processed.getPixel(x, y).r;
    void setGray(int x, int y, num v) {
      processed.setPixelRgba(x, y, v, v, v, 255);
    }

    num minP = 255, maxP = 0;
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final l = luma(x, y);
        if (l < minP) minP = l;
        if (l > maxP) maxP = l;
      }
    }

    final range = maxP - minP;
    if (range > 20 && range < 245) {
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          final l = luma(x, y);
          final s = ((l - minP) / range * 255);
          setGray(x, y, s);
        }
      }
    }

    final outPath =
        '${Directory.systemTemp.path}/ktp_ocr_${DateTime.now().millisecondsSinceEpoch}.png';
    final outFile = File(outPath);
    await outFile.writeAsBytes(img.encodePng(processed));
    return outFile;
  }

  Future<void> _processImage(File file) async {
    try {
      final processed = await _preprocessImage(file);
      final inputImage = InputImage.fromFile(processed);
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

  List<String> _getOrderedLines(RecognizedText recognizedText) {
    final textLines = <TextLine>[];
    for (final block in recognizedText.blocks) {
      textLines.addAll(block.lines);
    }

    textLines.sort((a, b) {
      final yDiff = a.boundingBox.top - b.boundingBox.top;
      if (yDiff.abs() > 10) return yDiff.round();
      return (a.boundingBox.left - b.boundingBox.left).round();
    });

    final merged = <String>[];
    String? currentLine;
    double? currentTop;

    for (final line in textLines) {
      final text = line.text.trim();
      if (text.isEmpty) continue;
      if (text.length <= 1) continue;
      if (RegExp(r'^[\s\:\;\-\_\.\,\(\)\[\]\/\\]+$').hasMatch(text)) continue;

      if (currentTop == null || (line.boundingBox.top - currentTop).abs() > 14) {
        if (currentLine != null) merged.add(currentLine);
        currentLine = text;
        currentTop = line.boundingBox.top;
      } else {
        currentLine = '$currentLine $text';
      }
    }
    if (currentLine != null) merged.add(currentLine);

    return merged;
  }

  void _parseKtpText(List<String> lines) {
    final clean = <String>[];
    for (final l in lines) {
      final t = l.trim();
      if (t.isEmpty) continue;
      if (t.length <= 1) continue;
      if (RegExp(r'^[\s\:\;\-\.\,\(\)\[\]\/\\]+$').hasMatch(t)) continue;
      clean.add(t);
    }

    // ===== PASS 1: Label-based extraction =====
    int? nikLineIdx;

    for (int i = 0; i < clean.length; i++) {
      final line = clean[i];
      final lower = line.toLowerCase();

      // --- NIK ---
      if (_nik == null) {
        final nikVal = _extractDigits(line);
        if (nikVal != null) {
          _nik = nikVal;
          nikLineIdx = i;
          continue;
        }

        if (_hasLabel(lower, 'nik|n1k')) {
          final val = _extractValue(line, lower);
          final ext = _extractDigits(val);
          if (ext != null) {
            _nik = ext;
            nikLineIdx = i;
            continue;
          }
          if (i + 1 < clean.length) {
            final ext2 = _extractDigits(clean[i + 1]);
            if (ext2 != null) {
              _nik = ext2;
              nikLineIdx = i + 1;
              continue;
            }
          }
        }
      }

      // --- Nama ---
      if (_fullName == null && _hasLabel(lower, 'nama|nama lengkap|n a m a')) {
        String val = _extractValue(line, lower);
        if (val.isNotEmpty && !_isLabel(val)) { _fullName = val; continue; }
        if (i + 1 < clean.length) {
          final next = clean[i + 1];
          if (!_isLabel(next)) { _fullName = next; continue; }
        }
      }

      // --- Tempat / Tgl Lahir ---
      if (_birthPlace == null && _birthDate == null &&
          _hasLabel(lower, 'tempat/tgl lahir|tempat/tgl|tempat lahir|tanggal lahir|tgl lahir|tempat|lahir')) {
        String full = _extractValue(line, lower);
        if (full.isEmpty && i + 1 < clean.length) full = clean[i + 1];
        if (full.isNotEmpty && !_isLabel(full)) {
          final parts = full.split(',');
          if (parts.isNotEmpty) _birthPlace = parts[0].trim();
          if (parts.length > 1) _birthDate = parts.sublist(1).join(',').trim();
          continue;
        }
      }

      // --- Jenis Kelamin (sometimes combined with Gol. Darah) ---
      if (_gender == null && _hasLabel(lower, 'jenis kelamin|jenis|jk|kelamin')) {
        String val = _extractValue(line, lower);
        if (val.isNotEmpty) {
          // Normalize to handle OCR misreads (e.g. "G0L D4R4H" -> "gol darah")
          final norm = _normalizeOcr(val.toLowerCase().replaceAll(RegExp(r'\s+'), ''));
          final hasBt = RegExp(r'gol[.]?da?rah|gol[.]?|golongan').hasMatch(norm);
          if (hasBt) {
            final btNormMatch = RegExp(r'gol[.]?da?rah|gol[.]?|golongan').firstMatch(norm)!;
            final splitAt = _findSplitPos(val, btNormMatch.start);
            if (splitAt > 0) {
              _bloodType ??= val.substring(splitAt).replaceAll(RegExp(r'^[\s:,\-]+'), '').trim();
              _gender = val.substring(0, splitAt).trim();
            }
          }
          _gender = _extractGender(_gender ?? val);
        }
        if (_gender == null || _gender!.isEmpty) {
          if (i + 1 < clean.length && !_isLabel(clean[i + 1])) {
            _gender = _extractGender(clean[i + 1]);
          }
        }
        continue;
      }

      // --- Gol. Darah (standalone line) ---
      if (_bloodType == null && _hasLabel(lower, 'gol[.]? darah|gol[.]?|golongan darah|gol darah')) {
        String val = _extractValue(line, lower);
        if (val.isEmpty && i + 1 < clean.length) val = clean[i + 1];
        val = val.trim();
        if (val.isNotEmpty && val.length <= 4) { _bloodType = val.toUpperCase(); }
        continue;
      }

      // --- Alamat ---
      if (_address == null && _hasLabel(lower, 'alamat')) {
        String val = _extractValue(line, lower);
        if (val.isEmpty && i + 1 < clean.length) val = clean[i + 1];
        if (val.isNotEmpty && !_isLabel(val)) {
          final addrParts = <String>[val];
          for (int j = i + 1; j < clean.length; j++) {
            final nl = clean[j].toLowerCase();
            if (_hasLabel(nl, 'agama|status|pekerjaan|kewarganegaraan|berlaku')) break;
            if (_hasLabel(nl, 'rt/rw|rt|rw|kel/desa|kelurahan|kecamatan|kabupaten|kota|provinsi|kode pos')) {
              final subVal = _extractValue(clean[j], nl);
              addrParts.add(subVal.isNotEmpty ? subVal : clean[j]);
            } else {
              break;
            }
          }
          _address = addrParts.join(', ');
        }
        continue;
      }

      // --- Agama ---
      if (_religion == null && _hasLabel(lower, 'agama')) {
        String val = _extractValue(line, lower);
        if (val.isNotEmpty && !_isLabel(val)) { _religion = val; continue; }
        if (i + 1 < clean.length) {
          final next = clean[i + 1];
          if (!_isLabel(next)) { _religion = next; continue; }
        }
      }
    }

    // ===== PASS 2: Pattern-based fallbacks =====

    // NIK — scan ALL lines if still not found
    if (_nik == null) {
      for (final line in clean) {
        final nikVal = _extractDigits(line);
        if (nikVal != null) {
          _nik = nikVal;
          nikLineIdx = clean.indexOf(line);
          break;
        }
      }
    }

    // Name — if NIK found, the line right after NIK is usually the name
    if (_fullName == null && nikLineIdx != null && nikLineIdx + 1 < clean.length) {
      final candidate = clean[nikLineIdx + 1];
      if (!_isLabel(candidate) && !RegExp(r'^\d+$').hasMatch(candidate)) {
        _fullName = candidate;
      }
    }

    // Birth place/date — find date patterns in any line
    if (_birthPlace == null || _birthDate == null) {
      for (final line in clean) {
        final dateMatch = RegExp(
          r'(\d{1,2})\s*[-/]\s*(\d{1,2})\s*[-/]\s*(\d{2,4})',
        ).firstMatch(line);
        if (dateMatch != null) {
          final day = dateMatch.group(1)!.trim();
          final month = dateMatch.group(2)!.trim();
          final year = dateMatch.group(3)!.trim();
          _birthDate ??= '$day-$month-$year';

          if (_birthPlace == null) {
            final parts = line.split(RegExp(r'[,;]'));
            final beforeDate = line.substring(0, dateMatch.start).trim();
            final city = beforeDate
                .replaceAll(RegExp(r'(tempat|tgl|lahir|tanggal)[\s:/]*', caseSensitive: false), '')
                .replaceAll(RegExp(r'[,;\-:\s]+$'), '')
                .trim();
            if (city.isNotEmpty && !_isLabel(city)) {
              _birthPlace = city;
            } else if (parts.length > 1) {
              _birthPlace = parts[0].trim();
            }
          }
          break;
        }
      }
    }

    // Gender — search for "LAKI" or "PEREMPUAN" anywhere (with OCR normalization)
    if (_gender == null) {
      for (final line in clean) {
        _gender = _extractGender(line);
        if (_gender != null) break;
        // Try normalized
        final norm = _normalizeOcr(line.toUpperCase());
        _gender = _extractGender(norm);
        if (_gender != null) break;
      }
    }

    // Blood type — search for standalone blood type lines or near "gol" labels
    if (_bloodType == null) {
      for (final line in clean) {
        final trimmed = line.trim().toUpperCase();
        if (RegExp(r'^(A|B|AB|O)[+\-]?$').hasMatch(trimmed)) {
          _bloodType = trimmed;
          break;
        }
        // Check if line contains blood type near "gol" (normalized)
        final norm = _normalizeOcr(line.toLowerCase().replaceAll(RegExp(r'\s+'), ''));
        final btMatch = RegExp(r'gol[.]?da?rah[:\s]*([a-z0-9+\-]+)').firstMatch(norm);
        if (btMatch != null) {
          final bt = btMatch.group(1)!.trim().toUpperCase();
          if (RegExp(r'^(A|B|AB|O)[+\-]?$').hasMatch(bt)) {
            _bloodType = bt;
            break;
          }
        }
      }
    }

    // Religion — search for known religions
    if (_religion == null) {
      const religions = ['ISLAM', 'KRISTEN', 'KATOLIK', 'HINDU', 'BUDDHA', 'KONGHUCU', 'BUDHA'];
      for (final line in clean) {
        final upper = line.toUpperCase();
        for (final r in religions) {
          if (upper.contains(r) && upper.length < 20) {
            _religion = r;
            break;
          }
        }
        if (_religion != null) break;
      }
    }
  }

  bool _hasLabel(String lower, String pattern) {
    final labels = pattern.split('|');
    for (final label in labels) {
      final lbl = label.trim().toLowerCase();
      if (lower.contains(lbl)) return true;
    }
    // OCR fuzzy pass: common character misreads
    final fuzzy = _normalizeOcr(lower.replaceAll(RegExp(r'\s+'), ''));
    for (final label in labels) {
      final fl = _normalizeOcr(label.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ''));
      if (fuzzy.contains(fl)) return true;
    }
    return false;
  }

  String _normalizeOcr(String s) {
    return s
        .replaceAll('1', 'i')
        .replaceAll('0', 'o')
        .replaceAll('3', 'e')
        .replaceAll('4', 'a')
        .replaceAll('5', 's')
        .replaceAll('6', 'g')
        .replaceAll('8', 'b')
        .replaceAll('l', 'i')
        .replaceAll('|', 'i')
        .replaceAll('!', 'i')
        .replaceAll('@', 'a')
        .replaceAll('#', 'h')
        .replaceAll('\$', 's')
        .replaceAll('2', 'z');
  }

  bool _isLabel(String text) {
    final lower = text.toLowerCase().trim();
    if (lower.length < 3) return false;
    const labels = {
      'nik', 'nama', 'nama lengkap', 'tempat', 'tgl', 'tanggal', 'lahir',
      'tempat/tgl lahir', 'tempat/tgl', 'tempat lahir', 'tanggal lahir',
      'jenis kelamin', 'jenis', 'jk',
      'gol. darah', 'gol darah', 'gol.', 'golongan darah',
      'alamat', 'rt/rw', 'rw', 'rt', 'kel/desa', 'kelurahan',
      'kecamatan', 'kabupaten', 'kota', 'provinsi', 'kode pos',
      'agama', 'status perkawinan', 'status', 'perkawinan',
      'pekerjaan', 'kewarganegaraan', 'berlaku hingga', 'berlaku',
    };
    if (labels.contains(lower)) return true;
    for (final l in labels) {
      if (lower.startsWith('$l ') || lower.startsWith('$l:') || lower.startsWith('$l/')) return true;
    }
    return false;
  }

  String _extractValue(String line, String lineLower) {
    const labels = [
      'nama lengkap', 'nama',
      'tempat/tgl lahir', 'tempat/tgl', 'tempat lahir', 'tanggal lahir', 'tgl lahir',
      'jenis kelamin', 'jenis', 'jk',
      'gol. darah', 'gol darah', 'golongan darah', 'gol.',
      'kel/desa', 'kelurahan', 'kecamatan', 'kabupaten', 'kota', 'provinsi', 'kode pos',
      'rt/rw', 'rw', 'rt',
      'nik', 'alamat', 'agama',
    ];

    // Try exact match first
    int bestIdx = lineLower.length;
    String? bestLabel;
    for (final label in labels) {
      int idx = lineLower.indexOf(label);
      if (idx >= 0) {
        if (idx < bestIdx || (idx == bestIdx && label.length > (bestLabel?.length ?? 0))) {
          bestIdx = idx;
          bestLabel = label;
        }
      }
    }

    // Fallback: normalized match for OCR misreads
    if (bestLabel == null) {
      final norm = _normalizeOcr(lineLower.replaceAll(RegExp(r'\s+'), ''));
      for (final label in labels) {
        final normLabel = _normalizeOcr(label.toLowerCase().replaceAll(RegExp(r'\s+'), ''));
        int idx = norm.indexOf(normLabel);
        if (idx >= 0) {
          if (idx < bestIdx || (idx == bestIdx && label.length > (bestLabel?.length ?? 0))) {
            bestIdx = idx;
            bestLabel = label;
          }
        }
      }
      // If matched via normalized, we can't map back to position, so return whole line
      if (bestLabel != null) {
        String after = line.trimLeft();
        if (after.startsWith(':')) after = after.substring(1).trimLeft();
        if (after.startsWith('-')) after = after.substring(1).trimLeft();
        return after.trim();
      }
      return '';
    }

    String after = line.substring(bestIdx + bestLabel.length).trimLeft();
    if (after.startsWith(':')) after = after.substring(1).trimLeft();
    if (after.startsWith('-')) after = after.substring(1).trimLeft();
    return after.trim();
  }

  String? _extractDigits(String text) {
    final m = RegExp(r'(\d{16})').firstMatch(text);
    if (m != null) return m.group(1);
    final ms = RegExp(r'(\d{4})\s*[\.\-\s]?\s*(\d{4})\s*[\.\-\s]?\s*(\d{4})\s*[\.\-\s]?\s*(\d{4})').firstMatch(text);
    if (ms != null) return '${ms.group(1)}${ms.group(2)}${ms.group(3)}${ms.group(4)}';
    return null;
  }

  int _findSplitPos(String original, int normIndex) {
    // Map a position in the normalized string back to the original string
    int count = 0;
    for (int i = 0; i < original.length; i++) {
      if (original[i].trim().isNotEmpty) count++;
      if (count > normIndex) return i;
    }
    return original.length ~/ 2;
  }

  String? _extractGender(String val) {
    if (val.isEmpty) return null;
    final upper = val.toUpperCase();
    // Direct match first
    if (upper.contains('LAKI-LAKI')) return 'LAKI-LAKI';
    if (upper.contains('LAKI')) return 'LAKI-LAKI';
    if (upper.contains('PEREMPUAN')) return 'PEREMPUAN';
    // Normalized match for OCR errors (e.g. "LAKHLAKI" from misread)
    final norm = _normalizeOcr(upper.replaceAll(RegExp(r'\s+'), ''));
    if (norm.contains('LAKILAKI') || norm.contains('LAK1LAK1') || norm.contains('LAKIL4K1')) return 'LAKI-LAKI';
    if (norm.contains('PEREMPUAN') || norm.contains('PER3MPUAN') || norm.contains('P3R3MPUAN')) return 'PEREMPUAN';
    return null;
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
