import 'package:flutter/material.dart';
import 'instructor_home.dart';
import 'courses_screen.dart';
import 'start_attendance_screen.dart';
import '../../widgets/floating_nav_bar.dart';

class InstructorShell extends StatefulWidget {
  final int initialTab;
  const InstructorShell({super.key, this.initialTab = 0});

  @override
  State<InstructorShell> createState() => _InstructorShellState();
}

class _InstructorShellState extends State<InstructorShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
  }

  final _screens = const [
    InstructorHome(),
    CoursesScreen(),
    StartAttendanceScreen(),
  ];

  final _navItems = const [
    FloatingNavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    FloatingNavItem(
      icon: Icons.book_outlined,
      activeIcon: Icons.book_rounded,
      label: 'Courses',
    ),
    FloatingNavItem(
      icon: Icons.camera_alt_outlined,
      activeIcon: Icons.camera_alt_rounded,
      label: 'Attendance',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: FloatingNavBar(
        currentIndex: _currentIndex,
        items: _navItems,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}
