import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../models/course_model.dart';
import '../../models/user_model.dart';
import '../../widgets/app_button.dart';
import 'course_detail_screen.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final courses = state.myCourses
        .where((c) =>
            c.name.toLowerCase().contains(_query.toLowerCase()) ||
            c.code.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('My Courses',
                        style: Theme.of(context).textTheme.displayMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${state.myCourses.length} course${state.myCourses.length != 1 ? 's' : ''} created',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),

                    // Search bar
                    TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'Search courses…',
                        prefixIcon:
                            Icon(Icons.search_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Course list
            courses.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _EmptyCourses(),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final course = courses[i];
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
                          child: _CourseCard(
                            course: course,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CourseDetailScreen(course: course),
                              ),
                            ),
                            onDelete: () =>
                                _confirmDelete(context, state, course),
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

      // FAB to create a new course
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateCourseSheet(context, state),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showCreateCourseSheet(BuildContext context, AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => _CreateCourseSheet(
        instructorId: state.currentUser!.id,
        onCreate: state.createCourse,
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, AppState state, CourseModel course) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Delete Course?'),
        content: Text(
            'This will permanently delete "${course.name}". Students will be unenrolled.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              state.deleteCourse(course.id);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ─── Course Card ──────────────────────────────────────
class _CourseCard extends StatelessWidget {
  final CourseModel course;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CourseCard({
    required this.course,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: const Border.fromBorderSide(
              BorderSide(color: AppColors.border)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Course icon
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
                  const SizedBox(width: 16),

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
                        const SizedBox(height: 8),
                        Text(
                          '${course.semester} Semester',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_horiz, size: 22),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    onSelected: (v) {
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_outline_rounded,
                                size: 18, color: AppColors.error),
                            SizedBox(width: 8),
                            Text('Delete',
                                style: TextStyle(color: AppColors.error)),
                          ])),
                    ],
                  ),
                ],
              ),
            ),

            // Bottom row
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(AppRadius.lg)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.people_outline_rounded,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '${course.enrolledCount} students enrolled',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Text(
                        'View',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios_rounded,
                          size: 11, color: AppColors.primary),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Empty Courses ────────────────────────────────────
class _EmptyCourses extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(36),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: const Border.fromBorderSide(
            BorderSide(color: AppColors.border)),
      ),
      child: Column(
        children: [
          const Icon(Icons.book_outlined, size: 48, color: AppColors.textHint),
          const SizedBox(height: 16),
          Text(
            'No courses yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button below to\ncreate your first course.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}

// ─── Create Course Sheet ──────────────────────────────
class _CreateCourseSheet extends StatefulWidget {
  final String instructorId;
  final void Function(CourseModel) onCreate;

  const _CreateCourseSheet({
    required this.instructorId,
    required this.onCreate,
  });

  @override
  State<_CreateCourseSheet> createState() => _CreateCourseSheetState();
}

class _CreateCourseSheetState extends State<_CreateCourseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController();
  final _semesterCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _sectionCtrl.dispose();
    _semesterCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final course = CourseModel(
      id: generateId(),
      name: _nameCtrl.text.trim(),
      code: _codeCtrl.text.trim().toUpperCase(),
      section: _sectionCtrl.text.trim(),
      semester: _semesterCtrl.text.trim(),
      instructorId: widget.instructorId,
    );
    widget.onCreate(course);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Create New Course',
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 24),

            _field('Course Name', _nameCtrl, 'e.g. Computer Vision'),
            const SizedBox(height: 14),
            _field('Course Code', _codeCtrl, 'e.g. CS-301'),
            const SizedBox(height: 14),
            _field('Section', _sectionCtrl, 'e.g. Section A'),
            const SizedBox(height: 14),
            _field('Semester', _semesterCtrl, 'e.g. Spring 2026'),
            const SizedBox(height: 28),

            AppButtonFull(label: 'Create Course', onPressed: _submit),
          ],
        ),
      ),
    );
  }

  Widget _field(
      String label, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          decoration: InputDecoration(hintText: hint),
          validator: (v) =>
              v == null || v.trim().isEmpty ? '$label is required' : null,
        ),
      ],
    );
  }
}
