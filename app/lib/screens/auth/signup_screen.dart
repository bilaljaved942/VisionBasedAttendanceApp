import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../widgets/app_button.dart';
import 'login_screen.dart';

// ─── Step enum ───────────────────────────────────────────
enum _Step { role, details, face }

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _pageCtrl = PageController();

  _Step _currentStep = _Step.role;
  UserRole? _selectedRole;

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _regNumCtrl = TextEditingController();   // student only
  final _deptCtrl = TextEditingController();     // instructor only
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  // Face capture
  CameraController? _cameraController;
  XFile? _capturedImage;
  bool _isCameraReady = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _regNumCtrl.dispose();
    _deptCtrl.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  // ─── Camera Init ──────────────────────────────────────
  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;
      // Prefer front camera for face capture
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
      if (mounted) setState(() => _isCameraReady = true);
    } catch (_) {
      // Silently fail — we'll show a placeholder UI
    }
  }

  Future<void> _capturePhoto() async {
    if (_cameraController == null || !_isCameraReady) return;
    try {
      final file = await _cameraController!.takePicture();
      setState(() => _capturedImage = file);
    } catch (_) {}
  }

  // ─── Navigation ───────────────────────────────────────
  void _goToStep(_Step step) {
    setState(() => _currentStep = step);
    final index = _Step.values.indexOf(step);
    _pageCtrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  // ─── Register ─────────────────────────────────────────
  Future<void> _completeRegistration() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final id = generateId();
    UserModel newUser;

    if (_selectedRole == UserRole.instructor) {
      newUser = InstructorModel(
        id: id,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        department: _deptCtrl.text.trim().isEmpty
            ? null
            : _deptCtrl.text.trim(),
        faceImagePath: _capturedImage?.path,
      );
    } else {
      newUser = StudentModel(
        id: id,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        registrationNumber: _regNumCtrl.text.trim(),
        faceImagePath: _capturedImage?.path,
      );
    }

    final errMsg = context.read<AppState>().registerUser(newUser);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _error = errMsg;
    });

    if (errMsg != null) {
      // Go back to details step on error
      _goToStep(_Step.details);
    }
    // If null → AppState sets currentUser → _AppRouter navigates automatically
  }

  // ─── Build ────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator + header
            _buildHeader(),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildRoleStep(),
                  _buildDetailsStep(),
                  _buildFaceStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────
  Widget _buildHeader() {
    final stepIndex = _Step.values.indexOf(_currentStep);
    final titles = ['Choose role', 'Your details', 'Face capture'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back arrow + step count
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (_currentStep == _Step.role) {
                    Navigator.pop(context);
                  } else {
                    _goToStep(
                        _Step.values[_Step.values.indexOf(_currentStep) - 1]);
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                ),
              ),
              const Spacer(),
              Text(
                'Step ${stepIndex + 1} of ${_Step.values.length}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Progress bar
          Row(
            children: List.generate(_Step.values.length, (i) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < _Step.values.length - 1 ? 6 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= stepIndex
                        ? AppColors.primary
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          Text(
            titles[stepIndex],
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 4),
          Text(
            _stepSubtitle(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  String _stepSubtitle() {
    switch (_currentStep) {
      case _Step.role:
        return 'Select how you will use FAST Attendance.';
      case _Step.details:
        return 'Fill in your account information.';
      case _Step.face:
        return 'Capture your face for future recognition.';
    }
  }

  // ─── Step 1: Role ─────────────────────────────────────
  Widget _buildRoleStep() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
      child: Column(
        children: [
          _RoleCard(
            label: 'Instructor',
            description:
                'Create courses, manage students\nand take vision-based attendance.',
            icon: Icons.school_outlined,
            isSelected: _selectedRole == UserRole.instructor,
            onTap: () => setState(() => _selectedRole = UserRole.instructor),
          ),
          const SizedBox(height: 16),
          _RoleCard(
            label: 'Student',
            description:
                'View your enrolled courses\nand track attendance records.',
            icon: Icons.person_outline_rounded,
            isSelected: _selectedRole == UserRole.student,
            onTap: () => setState(() => _selectedRole = UserRole.student),
          ),
          const Spacer(),
          AppButtonFull(
            label: 'Continue',
            onPressed: _selectedRole == null
                ? null
                : () => _goToStep(_Step.details),
          ),
        ],
      ),
    );
  }

  // ─── Step 2: Details ──────────────────────────────────
  Widget _buildDetailsStep() {
    final isInstructor = _selectedRole == UserRole.instructor;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Full Name'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'Ahmed Hassan',
                prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),

            _label('Email Address'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'ahmed@example.com',
                prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Role-specific field
            if (!isInstructor) ...[
              _label('Registration Number'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _regNumCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: '21K-3456',
                  prefixIcon: Icon(Icons.badge_outlined, size: 20),
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Registration number is required'
                    : null,
              ),
              const SizedBox(height: 16),
            ],

            if (isInstructor) ...[
              _label('Department (Optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _deptCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Computer Science',
                  prefixIcon:
                      Icon(Icons.account_balance_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 16),
            ],

            _label('Password'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscurePass,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePass = !_obscurePass),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 6)
                  return 'Password must be at least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),

            _label('Confirm Password'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _confirmPassCtrl,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please confirm password';
                if (v != _passCtrl.text) return 'Passwords do not match';
                return null;
              },
            ),

            // Error
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                      color: AppColors.error, fontSize: 13),
                ),
              ),
            ],

            const SizedBox(height: 32),
            AppButtonFull(
              label: 'Continue',
              onPressed: () {
                if (_formKey.currentState?.validate() ?? false) {
                  _goToStep(_Step.face);
                  _initCamera();
                }
              },
            ),
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LoginScreen()),
                  );
                },
                child: RichText(
                  text: const TextSpan(
                    text: 'Already have an account? ',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 14),
                    children: [
                      TextSpan(
                        text: 'Log In',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ─── Step 3: Face ─────────────────────────────────────
  Widget _buildFaceStep() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
      child: Column(
        children: [
          // Camera / preview area
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              child: _capturedImage != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        // Show captured image (cross-platform approach)
                        Container(
                          color: Colors.black,
                          child: const Center(
                            child: Icon(Icons.check_circle_rounded,
                                color: AppColors.success, size: 72),
                          ),
                        ),
                        // Overlay text
                        const Positioned(
                          bottom: 24,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Text(
                              'Face captured ✓',
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
                            // Oval face guide overlay
                            CustomPaint(painter: _FaceGuideOverlayPainter()),
                            const Positioned(
                              top: 24,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Text(
                                  'Align your face in the oval',
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Complete',
                    onPressed: _completeRegistration,
                    isLoading: _isLoading,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                  ),
                ),
              ],
            ),
          ] else ...[
            AppButtonFull(
              label: _isCameraReady ? 'Capture Face' : 'Enable Camera',
              icon: Icons.camera_alt_outlined,
              onPressed:
                  _isCameraReady ? _capturePhoto : _initCamera,
            ),
            const SizedBox(height: 12),
            // Skip option
            TextButton(
              onPressed: () => _completeRegistration(),
              child: const Text(
                'Skip for now',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
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

  Widget _label(String text) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium,
      );
}

// ─── Role selection card ───────────────────────────────
class _RoleCard extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.label,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.15)
                    : AppColors.background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.textPrimary,
                size: 26,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isSelected)
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 22),
          ],
        ),
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

    // Dark overlay outside oval
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    // Oval border
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
