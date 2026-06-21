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
  CourseModel? _activeCourse;

  @override
  void initState() {
    super.initState();
    _activeCourse = widget.course;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadSessionsForCourse(_activeCourse!.id);
    });
  }

  CourseModel _latestCourse(AppState state, String courseId) {
    try {
      return state.allCourses.firstWhere((c) => c.id == courseId);
    } catch (_) {
      return widget.course;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final course = _latestCourse(state, _activeCourse?.id ?? widget.course.id);

    final enrolledStudents = course.enrolledStudentIds
        .map((id) => state.getStudentById(id))
        .whereType<StudentModel>()
        .where((s) =>
            s.name.toLowerCase().contains(_query.toLowerCase()) ||
            s.registrationNumber.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Static Header Card Section
              Padding(
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
                    const SizedBox(height: 16),

                    // Course header card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
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
                          const SizedBox(height: 10),
                          Text(
                            course.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
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
                          const SizedBox(height: 10),
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
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // TabBar Selection
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicatorColor: AppColors.primary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  tabs: [
                    Tab(text: 'Enrolled Students'),
                    Tab(text: 'Attendance Ledger'),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),

              // Tab View Content
              Expanded(
                child: TabBarView(
                  children: [
                    _buildStudentsTab(state, course, enrolledStudents),
                    _buildLedgerTab(state),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentsTab(AppState state, CourseModel course, List<StudentModel> enrolledStudents) {
    return Column(
      children: [
        // Title and add student row
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
          child: Row(
            children: [
              Text(
                'Class Roster',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showAddStudentSheet(context, state, course),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add_outlined, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Add Student',
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
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Search enrolled students…',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // List view
        Expanded(
          child: enrolledStudents.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Center(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: const Border.fromBorderSide(
                            BorderSide(color: AppColors.border)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_outline_rounded,
                              size: 48, color: AppColors.textHint),
                          const SizedBox(height: 12),
                          Text(
                            _query.isEmpty
                                ? 'No students enrolled yet.\nTap "Add Student" to enroll students.'
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
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 80),
                  itemCount: enrolledStudents.length,
                  itemBuilder: (ctx, i) {
                    final student = enrolledStudents[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _StudentEnrolledTile(
                        student: student,
                        onRemove: () => _confirmRemove(
                            context, state, course, student),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLedgerTab(AppState state) {
    final course = _latestCourse(state, _activeCourse?.id ?? widget.course.id);
    final enrolledStudents = course.enrolledStudentIds
        .map((id) => state.getStudentById(id))
        .whereType<StudentModel>()
        .toList();

    final sessions = List<AttendanceSession>.from(state.getSessionsForCourse(course.id))
      ..sort((a, b) => a.date.compareTo(b.date));

    final myCourses = state.myCourses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dropdown Course Selector
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Course & Section',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<CourseModel>(
                    value: myCourses.firstWhere((c) => c.id == course.id, orElse: () => course),
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
                    dropdownColor: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    items: myCourses.map((c) {
                      return DropdownMenuItem<CourseModel>(
                        value: c,
                        child: Text(
                          '${c.name} (${c.code} • ${c.section})',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (newCourse) {
                      if (newCourse != null) {
                        setState(() {
                          _activeCourse = newCourse;
                        });
                        state.loadSessionsForCourse(newCourse.id);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        // Spreadsheet / Grid
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : enrolledStudents.isEmpty
                  ? _buildEmptyLedgerState('No students enrolled in this course.')
                  : sessions.isEmpty
                      ? _buildEmptyLedgerState('No attendance sessions recorded yet.\nStart a session in the Attendance tab.')
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Theme(
                                    data: Theme.of(context).copyWith(
                                      dividerColor: AppColors.border,
                                    ),
                                    child: DataTable(
                                      columnSpacing: 24,
                                      horizontalMargin: 16,
                                      headingRowColor: WidgetStateProperty.all(AppColors.background),
                                      dataRowMaxHeight: 52,
                                      dataRowMinHeight: 48,
                                      columns: [
                                        const DataColumn(
                                          label: Text(
                                            'Student',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        ...sessions.map((session) {
                                          final dateStr = '${session.date.day}/${session.date.month}';
                                          return DataColumn(
                                            label: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                Text(
                                                  dateStr,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                Text(
                                                  session.lectureName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 9,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                      rows: enrolledStudents.map((student) {
                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    student.name,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  Text(
                                                    student.registrationNumber,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            ...sessions.map((session) {
                                              final record = session.records.firstWhere(
                                                (r) => r.studentId == student.id,
                                                orElse: () => AttendanceRecord(studentId: student.id),
                                              );
                                              final isPresent = record.isPresent;

                                              return DataCell(
                                                Center(
                                                  child: Container(
                                                    width: 26,
                                                    height: 26,
                                                    decoration: BoxDecoration(
                                                      color: isPresent
                                                          ? AppColors.success.withValues(alpha: 0.12)
                                                          : AppColors.error.withValues(alpha: 0.12),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      isPresent
                                                          ? Icons.check_rounded
                                                          : Icons.close_rounded,
                                                      size: 14,
                                                      color: isPresent
                                                          ? AppColors.success
                                                          : AppColors.error,
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildEmptyLedgerState(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.table_chart_outlined, size: 48, color: AppColors.textHint),
              const SizedBox(height: 16),
              Text(
                text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ],
          ),
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
                    separatorBuilder: (_, _) =>
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
