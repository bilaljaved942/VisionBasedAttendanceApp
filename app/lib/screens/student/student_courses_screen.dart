import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../models/course_model.dart';

class StudentCoursesScreen extends StatefulWidget {
  const StudentCoursesScreen({super.key});

  @override
  State<StudentCoursesScreen> createState() => _StudentCoursesScreenState();
}

class _StudentCoursesScreenState extends State<StudentCoursesScreen> {
  CourseModel? _selectedCourse;

  Color _getStatusColor(double attendancePercent, int totalSessions) {
    if (totalSessions == 0) return AppColors.textSecondary;
    if (attendancePercent >= 75) return AppColors.success;
    if (attendancePercent >= 60) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.currentUser! as StudentModel;
    final courses = state.enrolledCourses;

    // Default to the first course if not set or if current selection is invalid
    CourseModel? course;
    if (courses.isNotEmpty) {
      course = _selectedCourse != null && courses.any((c) => c.id == _selectedCourse!.id)
          ? courses.firstWhere((c) => c.id == _selectedCourse!.id)
          : courses.first;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: courses.isEmpty
            ? _buildEmptyState()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Page Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Attendance',
                            style: Theme.of(context).textTheme.displayMedium),
                        const SizedBox(height: 4),
                        Text(
                          'Track attendance logs across your enrolled courses',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),

                  // Horizontal Course Selector Bar
                  SizedBox(
                    height: 84,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: courses.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (ctx, i) {
                        final c = courses[i];
                        final isSelected = course?.id == c.id;
                        final attendance = state.getStudentAttendance(user.id, c.id);

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedCourse = c;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 150,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.border,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  c.code,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white70 : AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        c.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? Colors.white : AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${attendance.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected ? Colors.white : AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Selected Course Stats & Table View
                  if (course != null)
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 80),
                        child: _buildCourseDetails(state, user, course),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildCourseDetails(AppState state, StudentModel user, CourseModel course) {
    final attendance = state.getStudentAttendance(user.id, course.id);
    final sessions = List<AttendanceSession>.from(state.getSessionsForCourse(course.id))
      ..sort((a, b) => b.date.compareTo(a.date)); // Newest sessions first for logs

    final totalSessions = sessions.length;
    final presentSessions = sessions
        .where((s) => s.records.any((r) => r.studentId == user.id && r.isPresent))
        .length;

    final statusColor = _getStatusColor(attendance, totalSessions);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Course Stats Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.name,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 18),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${course.displayLabel}  •  ${course.semester}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        totalSessions == 0 ? '—' : '${attendance.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Attendance',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: totalSessions == 0 ? 0 : attendance / 100,
                  backgroundColor: AppColors.border,
                  valueColor: AlwaysStoppedAnimation(statusColor),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 18),

              // Stats Row
              Row(
                children: [
                  _StatItem(
                    label: 'Total Lectures',
                    value: '$totalSessions',
                    icon: Icons.calendar_today_outlined,
                  ),
                  _StatDivider(),
                  _StatItem(
                    label: 'Present Lectures',
                    value: '$presentSessions',
                    icon: Icons.check_circle_outline_rounded,
                    color: AppColors.success,
                  ),
                  _StatDivider(),
                  _StatItem(
                    label: 'Absent Lectures',
                    value: '${totalSessions - presentSessions}',
                    icon: Icons.cancel_outlined,
                    color: totalSessions - presentSessions > 0 ? AppColors.error : AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status pill
              if (totalSessions > 0)
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: statusColor.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          attendance >= 75 ? Icons.check_circle_rounded : Icons.warning_rounded,
                          color: statusColor,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          attendance >= 75
                              ? 'You satisfy the 75% threshold requirement'
                              : 'Attendance threshold shortage alert',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Session Logs Table Header
        Text(
          'Detailed Attendance Records',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),

        // History Table Card
        sessions.isEmpty
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.history_toggle_off_rounded, size: 40, color: AppColors.textHint),
                    const SizedBox(height: 12),
                    Text(
                      'No sessions recorded yet for this course.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: AppColors.border),
                    child: DataTable(
                      columnSpacing: 16,
                      horizontalMargin: 16,
                      headingRowColor: WidgetStateProperty.all(AppColors.background),
                      columns: const [
                        DataColumn(
                          label: Text(
                            'Date',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Lecture Name',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Status',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ],
                      rows: sessions.map((session) {
                        final record = session.records.firstWhere(
                          (r) => r.studentId == user.id,
                          orElse: () => AttendanceRecord(studentId: user.id),
                        );
                        final isPresent = record.isPresent;
                        final dateStr = '${session.date.day}/${session.date.month}/${session.date.year}';

                        return DataRow(
                          cells: [
                            DataCell(Text(dateStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                            DataCell(
                              Text(
                                session.lectureName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isPresent
                                          ? AppColors.success.withValues(alpha: 0.12)
                                          : AppColors.error.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isPresent ? 'Present' : 'Absent',
                                      style: TextStyle(
                                        color: isPresent ? AppColors.success : AppColors.error,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (isPresent && record.confidence != null && record.confidence! < 1.0) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '${(record.confidence! * 100).toStringAsFixed(0)}%',
                                      style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.book_outlined, size: 48, color: AppColors.textHint),
              const SizedBox(height: 16),
              Text(
                'No courses yet.\nAsk your instructor to enroll you.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatItem({
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
          Icon(icon, size: 16, color: color ?? AppColors.textSecondary),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color ?? AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: AppColors.border,
    );
  }
}
