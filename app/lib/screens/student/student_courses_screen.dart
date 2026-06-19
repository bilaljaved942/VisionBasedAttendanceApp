import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../models/course_model.dart';

class StudentCoursesScreen extends StatelessWidget {
  const StudentCoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.currentUser! as StudentModel;
    final courses = state.enrolledCourses;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Courses',
                        style: Theme.of(context).textTheme.displayMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Enrolled in ${courses.length} course${courses.length != 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),

            courses.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        padding: const EdgeInsets.all(36),
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
                              'No courses yet.\nAsk your instructor to enroll you.',
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
                        final course = courses[i];
                        final attendance =
                            state.getStudentAttendance(user.id, course.id);
                        final sessions =
                            state.getSessionsForCourse(course.id);
                        final presentSessions = sessions
                            .where((s) => s.records.any(
                                  (r) =>
                                      r.studentId == user.id &&
                                      r.isPresent,
                                ))
                            .length;

                        return Padding(
                          padding:
                              const EdgeInsets.fromLTRB(24, 0, 24, 16),
                          child: _CourseDetailCard(
                            course: course,
                            attendancePercent: attendance,
                            totalSessions: sessions.length,
                            presentSessions: presentSessions,
                          ),
                        );
                      },
                      childCount: courses.length,
                    ),
                  ),

            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }
}

class _CourseDetailCard extends StatelessWidget {
  final CourseModel course;
  final double attendancePercent;
  final int totalSessions;
  final int presentSessions;

  const _CourseDetailCard({
    required this.course,
    required this.attendancePercent,
    required this.totalSessions,
    required this.presentSessions,
  });

  Color get _color {
    if (attendancePercent >= 75) return AppColors.success;
    if (attendancePercent >= 60) return AppColors.warning;
    if (totalSessions == 0) return AppColors.textSecondary;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: const Border.fromBorderSide(
            BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          // Course header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      course.code.split('-').first,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course.displayLabel,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course.semester,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  totalSessions == 0
                      ? '—'
                      : '${attendancePercent.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _color,
                  ),
                ),
              ],
            ),
          ),

          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value:
                    totalSessions == 0 ? 0 : attendancePercent / 100,
                backgroundColor: AppColors.border,
                valueColor: AlwaysStoppedAnimation(_color),
                minHeight: 6,
              ),
            ),
          ),

          // Stats row
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(
                vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                _Stat(
                  label: 'Sessions',
                  value: '$totalSessions',
                  icon: Icons.calendar_today_outlined,
                ),
                _Divider(),
                _Stat(
                  label: 'Present',
                  value: '$presentSessions',
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.success,
                ),
                _Divider(),
                _Stat(
                  label: 'Absent',
                  value: '${totalSessions - presentSessions}',
                  icon: Icons.cancel_outlined,
                  color: totalSessions - presentSessions > 0
                      ? AppColors.error
                      : AppColors.textSecondary,
                ),
              ],
            ),
          ),

          // Status message
          if (totalSessions > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(
                      color: _color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      attendancePercent >= 75
                          ? Icons.check_circle_rounded
                          : Icons.warning_rounded,
                      color: _color,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      attendancePercent >= 75
                          ? 'You meet the 75% requirement'
                          : 'Below 75% — risk of shortage',
                      style: TextStyle(
                        color: _color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon,
              size: 18,
              color: color ?? AppColors.textSecondary),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color ?? AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.border,
    );
  }
}
