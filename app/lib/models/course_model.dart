class CourseModel {
  final String id;
  final String name;
  final String code;
  final String section;
  final String semester;
  final String instructorId;
  final List<String> enrolledStudentIds;

  const CourseModel({
    required this.id,
    required this.name,
    required this.code,
    required this.section,
    required this.semester,
    required this.instructorId,
    this.enrolledStudentIds = const [],
  });

  CourseModel copyWith({
    String? name,
    String? code,
    String? section,
    String? semester,
    List<String>? enrolledStudentIds,
  }) {
    return CourseModel(
      id: id,
      name: name ?? this.name,
      code: code ?? this.code,
      section: section ?? this.section,
      semester: semester ?? this.semester,
      instructorId: instructorId,
      enrolledStudentIds: enrolledStudentIds ?? this.enrolledStudentIds,
    );
  }

  int get enrolledCount => enrolledStudentIds.length;

  /// Display label e.g. "CS-301 — Section A"
  String get displayLabel => '$code  •  $section';
}

class AttendanceRecord {
  final String studentId;
  bool isPresent;
  DateTime? detectedAt;
  double? confidence;

  AttendanceRecord({
    required this.studentId,
    this.isPresent = false,
    this.detectedAt,
    this.confidence,
  });
}

class AttendanceSession {
  final String id;
  final String courseId;
  final String instructorId;
  final DateTime date;
  final String lectureName;
  final List<AttendanceRecord> records;

  AttendanceSession({
    required this.id,
    required this.courseId,
    required this.instructorId,
    required this.date,
    required this.lectureName,
    required this.records,
  });

  int get presentCount => records.where((r) => r.isPresent).length;
  int get absentCount => records.where((r) => !r.isPresent).length;
  double get attendancePercentage =>
      records.isEmpty ? 0.0 : (presentCount / records.length) * 100;
}
