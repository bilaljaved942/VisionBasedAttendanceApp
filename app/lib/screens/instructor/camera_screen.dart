import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../models/course_model.dart';
import '../../models/user_model.dart';

class CameraScreen extends StatefulWidget {
  final CourseModel course;
  final String lectureName;
  final DateTime date;

  const CameraScreen({
    super.key,
    required this.course,
    required this.lectureName,
    required this.date,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _cameraError = false;

  // Scanning animation
  late AnimationController _scanAnim;
  late Animation<double> _scanLine;

  // Bounding box pulse
  late AnimationController _pulseAnim;

  // Panel expanded state
  bool _panelExpanded = true;

  // Face recognition API properties
  Timer? _frameTimer;
  bool _isAnalyzing = false;
  String? _apiUrl;
  bool _backendConnected = true;
  bool _simulationFallbackActive = false;

  @override
  void initState() {
    super.initState();

    _apiUrl = dotenv.env['RECOGNITION_API_URL'];
    final hasApi = _apiUrl != null && _apiUrl!.isNotEmpty;

    // Start simulated or live session
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().startAttendanceSession(widget.course, useSimulation: !hasApi);
    });

    if (hasApi) {
      _startFrameCaptureLoop();
    } else {
      _backendConnected = false;
      _simulationFallbackActive = true;
    }

    // Scanning line anim
    _scanAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanLine = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanAnim, curve: Curves.easeInOut),
    );

    // Pulse anim for bounding boxes
    _pulseAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _initCamera();
  }

  void _startFrameCaptureLoop() {
    _frameTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _captureAndAnalyzeFrame();
    });
  }

  Future<void> _captureAndAnalyzeFrame() async {
    if (!_cameraReady || _cameraController == null || _cameraError || _isAnalyzing) return;
    if (_cameraController!.value.isTakingPicture) return;

    if (mounted) setState(() => _isAnalyzing = true);

    try {
      final file = await _cameraController!.takePicture();
      final bytes = await file.readAsBytes();

      final uri = Uri.parse('$_apiUrl/recognize');
      final request = http.MultipartRequest('POST', uri)
        ..fields['course_id'] = widget.course.id
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'frame.jpg',
        ));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 4));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List detected = data['detected'] ?? [];

        if (mounted) {
          final state = context.read<AppState>();
          for (final d in detected) {
            final studentId = d['student_id'];
            final confidence = (d['confidence'] as num?)?.toDouble() ?? 1.0;
            state.markStudentPresent(studentId, confidence);
          }
          if (!_backendConnected || _simulationFallbackActive) {
            setState(() {
              _backendConnected = true;
              _simulationFallbackActive = false;
            });
          }
        }
      } else {
        _handleApiFailure();
      }
    } catch (_) {
      _handleApiFailure();
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  void _handleApiFailure() {
    if (!_simulationFallbackActive) {
      if (mounted) {
        setState(() {
          _backendConnected = false;
          _simulationFallbackActive = true;
        });
        context.read<AppState>().enableFallbackSimulation();
      }
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraError = true);
        return;
      }
      // Prefer back camera for classroom scanning
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } catch (_) {
      if (mounted) setState(() => _cameraError = true);
    }
  }

  @override
  void dispose() {
    _frameTimer?.cancel();
    _cameraController?.dispose();
    _scanAnim.dispose();
    _pulseAnim.dispose();
    super.dispose();
  }

  void _endSession(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('End Session?'),
        content: const Text(
            'Save attendance and end this session? Remaining students will be marked Absent.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              context.read<AppState>().saveAndEndSession(
                lectureName: widget.lectureName,
                date: widget.date,
              );
              Navigator.pop(context); // close dialog
              Navigator.pop(context); // go back to attendance screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill)),
            ),
            child: const Text('Save & End'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final records = state.sessionRecords;
    final presentCount =
        records.where((r) => r.isPresent).length;
    final totalCount = records.length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ─── Camera or placeholder ──────────────────────
          Positioned.fill(
            child: _cameraError
                ? _CameraErrorPlaceholder()
                : !_cameraReady
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: Colors.white),
                      )
                    : CameraPreview(_cameraController!),
          ),

          // ─── Scanning overlay ───────────────────────────
          if (!_cameraError && _cameraReady)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _scanAnim,
                builder: (_, _) => CustomPaint(
                  painter: _ScanOverlayPainter(
                    scanProgress: _scanLine.value,
                    pulseValue: _pulseAnim.value,
                  ),
                ),
              ),
            ),

          // ─── Top bar ────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    // Close button
                    GestureDetector(
                      onTap: () => _endSession(context),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _backendConnected
                            ? AppColors.success.withValues(alpha: 0.25)
                            : AppColors.error.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _backendConnected ? AppColors.success : AppColors.error,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _backendConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                            color: _backendConnected ? AppColors.success : AppColors.error,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _backendConnected
                                ? (_isAnalyzing ? 'Scanning...' : 'Live AI')
                                : 'Offline (Sim)',
                            style: TextStyle(
                              color: _backendConnected ? AppColors.success : AppColors.error,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Course name pill
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.fiber_manual_record,
                                color: AppColors.error, size: 10),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.course.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Counter badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.9),
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '$presentCount / $totalCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Bottom student panel ────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _StudentRollPanel(
              records: records,
              isExpanded: _panelExpanded,
              onToggleExpand: () =>
                  setState(() => _panelExpanded = !_panelExpanded),
              onToggle: (id) =>
                  state.toggleStudentAttendance(id),
              getStudent: state.getStudentById,
              onEndSession: () => _endSession(context),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Camera error placeholder ─────────────────────────
class _CameraErrorPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black87,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 64),
            SizedBox(height: 20),
            Text(
              'Camera unavailable',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Attendance simulation is still running.\nDetection timer is active.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Scan overlay painter ─────────────────────────────
class _ScanOverlayPainter extends CustomPainter {
  final double scanProgress;
  final double pulseValue;

  _ScanOverlayPainter({
    required this.scanProgress,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Scanning line
    final lineY = size.height * 0.15 +
        (size.height * 0.55) * scanProgress;
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          AppColors.success.withValues(alpha: 0.8),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, lineY - 1, size.width, 2))
      ..strokeWidth = 2;
    canvas.drawLine(
        Offset(0, lineY), Offset(size.width, lineY), linePaint);

    // Corner brackets for scan frame
    final bracketPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    const margin = 60.0;
    const bracketLen = 24.0;
    final left = margin;
    final right = size.width - margin;
    final top = size.height * 0.12;
    final bottom = size.height * 0.72;

    // Top-left
    canvas.drawLine(
        Offset(left, top), Offset(left + bracketLen, top), bracketPaint);
    canvas.drawLine(
        Offset(left, top), Offset(left, top + bracketLen), bracketPaint);

    // Top-right
    canvas.drawLine(
        Offset(right, top), Offset(right - bracketLen, top), bracketPaint);
    canvas.drawLine(
        Offset(right, top), Offset(right, top + bracketLen), bracketPaint);

    // Bottom-left
    canvas.drawLine(Offset(left, bottom),
        Offset(left + bracketLen, bottom), bracketPaint);
    canvas.drawLine(Offset(left, bottom),
        Offset(left, bottom - bracketLen), bracketPaint);

    // Bottom-right
    canvas.drawLine(Offset(right, bottom),
        Offset(right - bracketLen, bottom), bracketPaint);
    canvas.drawLine(Offset(right, bottom),
        Offset(right, bottom - bracketLen), bracketPaint);
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter old) =>
      old.scanProgress != scanProgress || old.pulseValue != pulseValue;
}

// ─── Roll call panel ──────────────────────────────────
class _StudentRollPanel extends StatelessWidget {
  final List<AttendanceRecord> records;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final void Function(String) onToggle;
  final StudentModel? Function(String) getStudent;
  final VoidCallback onEndSession;

  const _StudentRollPanel({
    required this.records,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onToggle,
    required this.getStudent,
    required this.onEndSession,
  });

  @override
  Widget build(BuildContext context) {
    final present = records.where((r) => r.isPresent).length;
    final absent = records.length - present;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle / header
            GestureDetector(
              onTap: onToggleExpand,
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white30,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _PillStat(
                            label: 'Present',
                            value: present,
                            color: AppColors.success),
                        const SizedBox(width: 8),
                        _PillStat(
                            label: 'Absent',
                            value: absent,
                            color: AppColors.error),
                        const Spacer(),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_up_rounded,
                          color: Colors.white54,
                          size: 22,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Student list
            if (isExpanded) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: records.length,
                  itemBuilder: (_, i) {
                    final record = records[i];
                    final student = getStudent(record.studentId);
                    return _StudentRollTile(
                      name: student?.name ?? record.studentId,
                      initials:
                          student?.initials ?? '?',
                      registrationNumber:
                          student?.registrationNumber ?? '',
                      isPresent: record.isPresent,
                      confidence: record.confidence,
                      onToggle: () => onToggle(record.studentId),
                    );
                  },
                ),
              ),
            ],

            // End session button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: onEndSession,
                  icon: const Icon(Icons.stop_rounded, size: 20),
                  label: const Text('End & Save Session',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.pill)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _PillStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$value $label',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _StudentRollTile extends StatelessWidget {
  final String name;
  final String initials;
  final String registrationNumber;
  final bool isPresent;
  final double? confidence;
  final VoidCallback onToggle;

  const _StudentRollTile({
    required this.name,
    required this.initials,
    required this.registrationNumber,
    required this.isPresent,
    this.confidence,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isPresent
            ? AppColors.success.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPresent
              ? AppColors.success.withValues(alpha: 0.4)
              : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isPresent
                ? AppColors.success.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.1),
            child: Text(
              initials,
              style: TextStyle(
                color: isPresent ? AppColors.success : Colors.white60,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color:
                        isPresent ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (registrationNumber.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    registrationNumber,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Confidence badge (if detected by camera)
          if (isPresent && confidence != null && confidence! < 1.0) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color:
                    AppColors.success.withValues(alpha: 0.2),
                borderRadius:
                    BorderRadius.circular(4),
              ),
              child: Text(
                '${(confidence! * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Toggle button
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isPresent
                    ? AppColors.success
                    : Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPresent
                    ? Icons.check_rounded
                    : Icons.close_rounded,
                color: isPresent
                    ? Colors.white
                    : Colors.white38,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
