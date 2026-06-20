import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_button.dart';

class RegisterFaceScreen extends StatefulWidget {
  const RegisterFaceScreen({super.key});

  @override
  State<RegisterFaceScreen> createState() => _RegisterFaceScreenState();
}

class _RegisterFaceScreenState extends State<RegisterFaceScreen> {
  CameraController? _cameraController;
  XFile? _capturedImage;
  bool _isCameraReady = false;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No cameras found on this device.');
        return;
      }
      // Prefer front camera for selfie/face capture
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to open camera: $e');
      }
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_isCameraReady) return;
    try {
      final file = await _cameraController!.takePicture();
      setState(() => _capturedImage = file);
    } catch (e) {
      setState(() => _error = 'Failed to capture image: $e');
    }
  }

  Future<void> _submitPhoto() async {
    if (_capturedImage == null) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final error = await context.read<AppState>().updateStudentFaceImage(_capturedImage!);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _error = error;
    });

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Face registered successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Register Face Biometrics'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              Text(
                'Align your face in the guide below and capture a photo. This will be used to automatically mark your attendance during classes.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Camera or Preview Frame
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  child: _capturedImage != null
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              color: Colors.black,
                              child: const Center(
                                child: Icon(Icons.check_circle_rounded,
                                    color: AppColors.success, size: 72),
                              ),
                            ),
                            const Positioned(
                              bottom: 24,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Text(
                                  'Face Captured successfully ✓',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : _isCameraReady && _cameraController != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                CameraPreview(_cameraController!),
                                CustomPaint(painter: _FaceGuideOverlayPainter()),
                                const Positioned(
                                  top: 24,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Text(
                                      'Position face within the oval',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : _buildCameraPlaceholder(),
                ),
              ),
              const SizedBox(height: 24),

              // Error banner if any
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Actions
              if (_capturedImage != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Retake',
                        isPrimary: false,
                        onPressed: () {
                          setState(() => _capturedImage = null);
                          _initCamera();
                        },
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        label: 'Submit',
                        onPressed: _submitPhoto,
                        isLoading: _isLoading,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                AppButtonFull(
                  label: _isCameraReady ? 'Capture Face' : 'Enable Camera',
                  icon: Icons.camera_alt_outlined,
                  onPressed: _isCameraReady ? _capturePhoto : _initCamera,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraPlaceholder() {
    return Container(
      color: AppColors.textPrimary,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 52),
          const SizedBox(height: 16),
          const Text(
            'Camera not started',
            style: TextStyle(color: Colors.white70, fontSize: 15),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _initCamera,
            child: const Text(
              'Start Camera',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Face guide overlay ───────────────────────────────
class _FaceGuideOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.65,
      height: size.height * 0.55,
    );

    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    canvas.drawOval(
      ovalRect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
