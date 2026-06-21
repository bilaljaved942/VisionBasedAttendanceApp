import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/instructor/instructor_shell.dart';
import 'screens/student/student_shell.dart';
import 'models/user_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env asset
  await dotenv.load(fileName: '.env');

  // Sanitize Supabase URL to strip trailing slashes or /rest/v1 paths
  String rawUrl = dotenv.env['SUPABASE_URL'] ?? '';
  String sanitizedUrl = rawUrl.trim();
  while (sanitizedUrl.endsWith('/')) {
    sanitizedUrl = sanitizedUrl.substring(0, sanitizedUrl.length - 1);
  }
  if (sanitizedUrl.endsWith('/rest/v1')) {
    sanitizedUrl = sanitizedUrl.substring(0, sanitizedUrl.length - '/rest/v1'.length);
  }
  while (sanitizedUrl.endsWith('/')) {
    sanitizedUrl = sanitizedUrl.substring(0, sanitizedUrl.length - 1);
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: sanitizedUrl,
    publishableKey: dotenv.env['SUPABASE_ANON_KEY']!.trim(),
  );

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

class _AppRouter extends StatefulWidget {
  const _AppRouter();

  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().checkAuthState();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    // Show a loading spinner while checking session on startup
    if (state.isCheckingAuth) {
      return const Scaffold(
        backgroundColor: Color(0xFFF9F9F9),
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.black,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (!state.isLoggedIn) return const SplashScreen();

    return state.currentUser?.role == UserRole.instructor
        ? const InstructorShell()
        : const StudentShell();
  }
}
