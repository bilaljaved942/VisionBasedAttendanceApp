import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/instructor/instructor_shell.dart';
import 'screens/student/student_shell.dart';
import 'models/user_model.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const FASTAttendanceApp(),
    ),
  );
}

class FASTAttendanceApp extends StatelessWidget {
  const FASTAttendanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FAST Attendance',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const _AppRouter(),
    );
  }
}

/// Handles routing based on auth state
class _AppRouter extends StatelessWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (!state.isLoggedIn) {
      return const SplashScreen();
    }

    if (state.currentUser?.role == UserRole.instructor) {
      return const InstructorShell();
    }

    return const StudentShell();
  }
}
