import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum LivenessChallenge { blink, smile, tilt }

class LivenessScreen extends StatefulWidget {
  const LivenessScreen({super.key});

  @override
  State<LivenessScreen> createState() => _LivenessScreenState();
}

class _LivenessScreenState extends State<LivenessScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _initialized = false;
  String _statusText = 'Persiapkan wajah Anda...';
  int _completedChallenges = 0;
  final List<Map<String, dynamic>> _challengeResults = [];

  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableContours: true,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  final _challengeOrder = [
    LivenessChallenge.blink,
    LivenessChallenge.smile,
    LivenessChallenge.tilt,
  ];

  int _currentChallengeIndex = 0;
  bool _blinkStarted = false;
  bool _blinkCompleted = false;
  bool _smileCompleted = false;
  bool _tiltStarted = false;
  bool _tiltCompleted = false;
  bool _done = false;
  bool _isFinishing = false;
  String? _lastSelfiePath;
  Timer? _detectionTimer;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      final front = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras!.first,
      );
      _controller = CameraController(front, ResolutionPreset.medium);
      await _controller!.initialize();
      if (mounted) {
        setState(() => _initialized = true);
        _startDetection();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context, null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka kamera: $e')),
        );
      }
    }
  }

  void _startDetection() {
    _detectionTimer = Timer.periodic(const Duration(milliseconds: 300), (timer) async {
      if (_done || _isFinishing || !mounted || !_initialized) {
        timer.cancel();
        return;
      }
      try {
        final xfile = await _controller!.takePicture();
        _lastSelfiePath = xfile.path;
        final image = File(xfile.path);
        final inputImage = InputImage.fromFile(image);
        final faces = await _faceDetector.processImage(inputImage);

        if (faces.isNotEmpty) {
          final face = faces.first;
          _checkChallenges(face);
        }
      } catch (_) {}
    });
  }

  void _checkChallenges(Face face) {
    if (_currentChallengeIndex >= _challengeOrder.length) return;

    final challenge = _challengeOrder[_currentChallengeIndex];

    switch (challenge) {
      case LivenessChallenge.blink:
        final leftEye = face.leftEyeOpenProbability ?? 0;
        final rightEye = face.rightEyeOpenProbability ?? 0;
        if (!_blinkStarted && leftEye < 0.3 && rightEye < 0.3) {
          _blinkStarted = true;
          setState(() => _statusText = 'Sekarang buka mata...');
        } else if (_blinkStarted && !_blinkCompleted && leftEye > 0.5 && rightEye > 0.5) {
          _blinkCompleted = true;
          _challengeResults.add({'challenge': 'blink', 'passed': true});
          setState(() {
            _completedChallenges++;
            _statusText = '✅ Kedip mata berhasil!';
            _currentChallengeIndex = 1;
          });
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) setState(() => _statusText = 'Sekarang tersenyum...');
          });
        }
        break;

      case LivenessChallenge.smile:
        final smile = face.smilingProbability ?? 0;
        if (!_smileCompleted && smile > 0.7) {
          _smileCompleted = true;
          _challengeResults.add({'challenge': 'smile', 'passed': true});
          setState(() {
            _completedChallenges++;
            _statusText = '✅ Senyuman terdeteksi!';
            _currentChallengeIndex = 2;
          });
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) setState(() => _statusText = 'Sekarang miringkan kepala...');
          });
        }
        break;

      case LivenessChallenge.tilt:
        final eulerY = face.headEulerAngleY ?? 0;
        if (!_tiltStarted && eulerY.abs() > 15) {
          _tiltStarted = true;
          setState(() => _statusText = 'Kembali ke tengah...');
        } else if (_tiltStarted && !_tiltCompleted && eulerY.abs() < 8) {
          _tiltCompleted = true;
          _challengeResults.add({'challenge': 'tilt', 'passed': true});
          setState(() {
            _completedChallenges++;
            _done = true;
            _statusText = '✅ Verifikasi selesai!';
          });
          _finish();
        }
        break;
    }
  }

  Future<void> _finish() async {
    _isFinishing = true;
    _detectionTimer?.cancel();
    await _faceDetector.close();
    await _controller?.dispose();
    if (!mounted) return;
    Navigator.pop(context, {
      'selfiePath': _lastSelfiePath,
      'livenessData': {
        'completed': _completedChallenges,
        'total': _challengeOrder.length,
        'challenges': _challengeResults,
      },
    });
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _faceDetector.close();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Verifikasi Wajah',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: !_initialized || _done
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: CameraPreview(_controller!),
                ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black54, Colors.transparent, Colors.black54],
                    ),
                  ),
                ),
                SafeArea(
                  child: Column(
                    children: [
                      const Spacer(),
                      Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (int i = 0; i < _challengeOrder.length; i++)
                                  _buildStepIndicator(i),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _statusText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _getChallengeHint(),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStepIndicator(int index) {
    final isActive = index == _currentChallengeIndex;
    final isDone = index < _currentChallengeIndex;
    IconData icon;
    String label;
    switch (_challengeOrder[index]) {
      case LivenessChallenge.blink:
        icon = Icons.visibility;
        label = 'Kedip';
        break;
      case LivenessChallenge.smile:
        icon = Icons.emoji_emotions;
        label = 'Senyum';
        break;
      case LivenessChallenge.tilt:
        icon = Icons.flip;
        label = 'Miring';
        break;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? const Color(0xFF00A651)
                  : isActive
                      ? const Color(0xFF2563EB)
                      : Colors.grey[300],
            ),
            child: Icon(
              isDone ? Icons.check : icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: isDone || isActive ? Colors.white : Colors.grey[400],
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _getChallengeHint() {
    if (_currentChallengeIndex >= _challengeOrder.length) return '';
    switch (_challengeOrder[_currentChallengeIndex]) {
      case LivenessChallenge.blink:
        return 'Kedipkan kedua mata Anda';
      case LivenessChallenge.smile:
        return 'Tersenyum lebar';
      case LivenessChallenge.tilt:
        return 'Miringkan kepala ke kiri/kanan lalu kembali';
    }
  }
}
