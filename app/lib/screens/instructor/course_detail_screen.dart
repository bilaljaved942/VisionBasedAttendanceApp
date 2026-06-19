import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../theme/app_theme.dart';
import '../../models/course_model.dart';
import '../../models/user_model.dart';

class CourseDetailScreen extends StatefulWidget {
  final CourseModel course;

  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  String _query = '';

  CourseModel _latestCourse(AppState state) {
    try {
      return state.allCourses
          .firstWhere((c) => c.id == widget.course.id);
    } catch (_) {
      return widget.course;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final course = _latestCourse(state);

    final enrolledStudents = course.enrolledStudentIds
        .map((id) => state.getStudentById(id))
        .whereType<StudentModel>()
        .where((s) =>
            s.name.toLowerCase().contains(_query.toLowerCase()) ||
            s.registrationNumber.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ─── Header ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: const Border.fromBorderSide(
                              BorderSide(color: AppColors.border)),
                        ),
                        child: const Icon(
                            Icons.arrow_back_ios_new_rounded, size: 18),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Course header card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: Text(
                              course.code,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            course.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _CourseChip(course.section),
                              const SizedBox(width: 8),
                              _CourseChip(course.semester),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${course.enrolledCount} students enrolled',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Section title + Add button
                    Row(
                      children: [
                        Text(
                          'Enrolled Students',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () =>
                              _showAddStudentSheet(context, state, course),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_add_outlined,
                                    size: 16, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'Add',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Search enrolled
                    TextField(
                      onChanged: (v) => setState(() => _query = v),
                      decoration: const InputDecoration(
                        hintText: 'Search enrolled students…',
                        prefixIcon:
                            Icon(Icons.search_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // ─── Students list ────────────────────────────────
            enrolledStudents.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: const Border.fromBorderSide(
                              BorderSide(color: AppColors.border)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.people_outline_rounded,
                                size: 48, color: AppColors.textHint),
                            const SizedBox(height: 12),
                            Text(
                              _query.isEmpty
                                  ? 'No students enrolled yet.\nTap "Add" to enroll students.'
                                  : 'No results for "$_query"',
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
                        final student = enrolledStudents[i];
                        return Padding(
                          padding:
                              const EdgeInsets.fromLTRB(24, 0, 24, 10),
                          child: _StudentEnrolledTile(
                            student: student,
                            onRemove: () => _confirmRemove(
                                context, state, course, student),
                          ),
                        );
                      },
                      childCount: enrolledStudents.length,
                    ),
                  ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  void _showAddStudentSheet(
      BuildContext context, AppState state, CourseModel course) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, ctrl) =>
            _AddStudentSheet(course: course, scrollController: ctrl),
      ),
    );
  }

  void _confirmRemove(BuildContext context, AppState state,
      CourseModel course, StudentModel student) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Text('Remove Student?'),
        content: Text(
            'Remove ${student.name} from ${course.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              state.removeStudentFromCourse(course.id, student.id);
            },
            child: const Text('Remove',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ─── Course chip pill ─────────────────────────────────
class _CourseChip extends StatelessWidget {
  final String label;
  const _CourseChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ─── Enrolled Student Tile ────────────────────────────
class _StudentEnrolledTile extends StatelessWidget {
  final StudentModel student;
  final VoidCallback onRemove;

  const _StudentEnrolledTile(
      {required this.student, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: const Border.fromBorderSide(
            BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.background,
            child: Text(
              student.initials,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student.name,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  student.registrationNumber,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.person_remove_outlined, size: 20),
            color: AppColors.error,
          ),
        ],
      ),
    );
  }
}

// ─── Add Student Sheet ────────────────────────────────
class _AddStudentSheet extends StatefulWidget {
  final CourseModel course;
  final ScrollController scrollController;

  const _AddStudentSheet(
      {required this.course, required this.scrollController});

  @override
  State<_AddStudentSheet> createState() => _AddStudentSheetState();
}

class _AddStudentSheetState extends State<_AddStudentSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final course = state.allCourses
        .firstWhere((c) => c.id == widget.course.id, orElse: () => widget.course);

    // Show all students not yet enrolled
    final notEnrolled = state.allStudents
        .where((s) => !course.enrolledStudentIds.contains(s.id))
        .where((s) =>
            s.name.toLowerCase().contains(_query.toLowerCase()) ||
            s.registrationNumber.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
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
          Text('Add Students',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Search and add students to ${widget.course.name}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Search by name or reg. number…',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: notEnrolled.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty
                          ? 'All registered students are already enrolled.'
                          : 'No students found for "$_query".',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                : ListView.separated(
                    controller: widget.scrollController,
                    itemCount: notEnrolled.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppColors.border),
                    itemBuilder: (ctx, i) {
                      final student = notEnrolled[i];
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 6),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.background,
                          child: Text(
                            student.initials,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        title: Text(student.name,
                            style:
                                Theme.of(context).textTheme.titleMedium),
                        subtitle: Text(student.registrationNumber,
                            style: Theme.of(context).textTheme.bodyMedium),
                        trailing: GestureDetector(
                          onTap: () {
                            state.enrollStudent(course.id, student.id);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: const Text(
                              'Add',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
