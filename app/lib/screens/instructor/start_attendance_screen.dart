import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../models/course_model.dart';
import '../../widgets/app_button.dart';
import 'camera_screen.dart';

class StartAttendanceScreen extends StatefulWidget {
  const StartAttendanceScreen({super.key});

  @override
  State<StartAttendanceScreen> createState() =>
      _StartAttendanceScreenState();
}

class _StartAttendanceScreenState extends State<StartAttendanceScreen> {
  CourseModel? _selectedCourse;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final courses = state.myCourses;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text('Start Attendance',
                  style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 6),
              Text(
                'Select a course to begin face recognition roll call.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: 32),

              // Info card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: AppColors.info, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'The camera will scan faces of enrolled students automatically. '
                        'You can manually override attendance after the session.',
                        style: TextStyle(
                          color: AppColors.info,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              Text('Select Course',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),

              if (courses.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: const Border.fromBorderSide(
                        BorderSide(color: AppColors.border)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.book_outlined,
                          size: 36, color: AppColors.textHint),
                      const SizedBox(height: 12),
                      Text(
                        'No courses found. Create a course first from the Courses tab.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: courses.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final course = courses[i];
                      final isSelected =
                          _selectedCourse?.id == course.id;

                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedCourse = course),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.surface,
                            borderRadius:
                                BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: isSelected ? 0 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : AppColors.background,
                                  borderRadius:
                                      BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.book_rounded,
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      course.name,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      course.displayLabel,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isSelected
                                            ? Colors.white
                                                .withValues(alpha: 0.65)
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${course.enrolledCount} students',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.65)
                                      : AppColors.textSecondary,
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 20),

              AppButtonFull(
                label: 'Open Camera',
                icon: Icons.camera_alt_outlined,
                onPressed: _selectedCourse == null
                    ? null
                    : () {
                        if (_selectedCourse!.enrolledCount == 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'No students enrolled in this course.'),
                            ),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CameraScreen(
                                course: _selectedCourse!),
                          ),
                        );
                      },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
