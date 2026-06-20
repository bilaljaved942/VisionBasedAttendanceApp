import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import 'register_face_screen.dart';

class StudentHome extends StatelessWidget {
  const StudentHome({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.currentUser! as StudentModel;
    final enrolledCourses = state.enrolledCourses;

    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    // Overall attendance across all courses
    double overallAttendance = 0.0;
    if (enrolledCourses.isNotEmpty) {
      double total = 0.0;
      for (final course in enrolledCourses) {
        total +=
            state.getStudentAttendance(user.id, course.id);
      }
      overallAttendance = total / enrolledCourses.length;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Header ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            greeting,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.firstName,
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                        ],
                      ),
                    ),
                    // Profile avatar + logout
                    GestureDetector(
                      onTap: () => _showProfileSheet(context, state, user),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          user.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ─── Face biometrics warning if missing ──────────
            if (user.faceImagePath == null || user.faceImagePath!.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: AppColors.error, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Face Biometrics Missing',
                              style: TextStyle(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'You skipped face capture during registration. You must register your face to allow teachers to mark your attendance automatically.',
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterFaceScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.face_retouching_natural, size: 18),
                            label: const Text('Register Face Now'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.pill),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ─── Attendance overview card ─────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _AttendanceOverviewCard(
                  percentage: overallAttendance,
                  courseCount: enrolledCourses.length,
                  registrationNumber: user.registrationNumber,
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 28)),

            // ─── Courses section title ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text('My Courses',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    if (enrolledCourses.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          // Switch to courses tab by popping shell
                        },
                        child: const Text(
                          'See all',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            // ─── Course list ──────────────────────────────────
            enrolledCourses.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(AppRadius.lg),
                          border: const Border.fromBorderSide(
                              BorderSide(color: AppColors.border)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.book_outlined,
                                size: 48, color: AppColors.textHint),
                            const SizedBox(height: 12),
                            Text(
                              'Not enrolled in any courses yet.\nAsk your instructor to add you.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(height: 1.6),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final course = enrolledCourses[i];
                        final attendance =
                            state.getStudentAttendance(user.id, course.id);
                        return Padding(
                          padding:
                              const EdgeInsets.fromLTRB(24, 0, 24, 12),
                          child: _StudentCourseCard(
                            courseName: course.name,
                            courseCode: course.displayLabel,
                            attendancePercent: attendance,
                          ),
                        );
                      },
                      childCount: enrolledCourses.length,
                    ),
                  ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  void _showProfileSheet(
      BuildContext context, AppState state, StudentModel user) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 28),
            CircleAvatar(
              radius: 32,
              backgroundColor: AppColors.primary,
              child: Text(
                user.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(user.name,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(user.email,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                user.registrationNumber,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  state.logout();
                },
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Log Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppRadius.pill)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Attendance overview card ─────────────────────────
class _AttendanceOverviewCard extends StatelessWidget {
  final double percentage;
  final int courseCount;
  final String registrationNumber;

  const _AttendanceOverviewCard({
    required this.percentage,
    required this.courseCount,
    required this.registrationNumber,
  });

  Color get _color {
    if (percentage >= 75) return AppColors.success;
    if (percentage >= 60) return AppColors.warning;
    return AppColors.error;
  }

  String get _status {
    if (courseCount == 0) return 'No courses yet';
    if (percentage >= 75) return 'Good standing';
    if (percentage >= 60) return 'Needs attention';
    return 'Critical — at risk';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overall Attendance',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      courseCount == 0
                          ? '—'
                          : '${percentage.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: courseCount == 0
                        ? Colors.white.withValues(alpha: 0.12)
                        : _color.withValues(alpha: 0.25),
                    borderRadius:
                        BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    _status,
                    style: TextStyle(
                      color: courseCount == 0
                          ? Colors.white70
                          : _color,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$courseCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'courses',
                style: TextStyle(
                    color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Student course card ──────────────────────────────
class _StudentCourseCard extends StatelessWidget {
  final String courseName;
  final String courseCode;
  final double attendancePercent;

  const _StudentCourseCard({
    required this.courseName,
    required this.courseCode,
    required this.attendancePercent,
  });

  Color get _barColor {
    if (attendancePercent >= 75) return AppColors.success;
    if (attendancePercent >= 60) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: const Border.fromBorderSide(
            BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.book_rounded, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(courseName,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(courseCode,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Text(
                attendancePercent == 0
                    ? 'No data'
                    : '${attendancePercent.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: attendancePercent == 0
                      ? AppColors.textSecondary
                      : _barColor,
                ),
              ),
            ],
          ),
          if (attendancePercent > 0) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: attendancePercent / 100,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation(_barColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  attendancePercent >= 75
                      ? 'Good standing'
                      : attendancePercent >= 60
                          ? 'Needs improvement'
                          : 'Critical — at risk',
                  style: TextStyle(
                      fontSize: 11,
                      color: _barColor,
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '75% required',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text(
              'No sessions recorded yet.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}
