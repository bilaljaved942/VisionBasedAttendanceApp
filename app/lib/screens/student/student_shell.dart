import 'package:flutter/material.dart';
import 'student_home.dart';
import 'student_courses_screen.dart';
import '../../widgets/floating_nav_bar.dart';

class StudentShell extends StatefulWidget {
  const StudentShell({super.key});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _currentIndex = 0;

  final _screens = const [
    StudentHome(),
    StudentCoursesScreen(),
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
      label: 'My Courses',
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
