import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_button.dart';
import 'auth/login_screen.dart';
import 'auth/signup_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),

              // Logo mark
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.face_retouching_natural_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Headline
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FAST\nAttendance',
                        style:
                            Theme.of(context).textTheme.displayLarge?.copyWith(
                                  height: 1.1,
                                ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Vision-based attendance marking\nfor FAST-NUCES — fast, accurate,\nand completely hands-free.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.6,
                            ),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(flex: 3),

              // Action buttons
              FadeTransition(
                opacity: _fadeAnim,
                child: Column(
                  children: [
                    AppButtonFull(
                      label: 'Log In',
                      onPressed: () => _navigate(context, isSignup: false),
                    ),
                    const SizedBox(height: 14),
                    AppButtonFull(
                      label: 'Create Account',
                      onPressed: () => _navigate(context, isSignup: true),
                      isPrimary: false,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Footer
              Center(
                child: Text(
                  'FAST University Islamabad • CS Dept',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, {required bool isSignup}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => isSignup ? const SignupScreen() : const LoginScreen(),
      ),
    );
  }
}
