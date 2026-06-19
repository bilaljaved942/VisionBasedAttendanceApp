class Student {
  final String id;
  final String name;
  final String department;
  final String section;
  final String semester;
  final String photoUrl; // Mock path or URL
  final List<double> faceEmbedding; // Simulated face embedding vectors

  Student({
    required this.id,
    required this.name,
    required this.department,
    required this.section,
    required this.semester,
    required this.photoUrl,
    required this.faceEmbedding,
  });

  Student copyWith({
    String? id,
    String? name,
    String? department,
    String? section,
    String? semester,
    String? photoUrl,
    List<double>? faceEmbedding,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      department: department ?? this.department,
      section: section ?? this.section,
      semester: semester ?? this.semester,
      photoUrl: photoUrl ?? this.photoUrl,
      faceEmbedding: faceEmbedding ?? this.faceEmbedding,
    );
  }
}

class Course {
  final String id;
  final String code;
  final String name;

  Course({
    required this.id,
    required this.code,
    required this.name,
  });
}

class ClassSection {
  final String id;
  final String courseId;
  final String name; // e.g. "Section A"
  final String schedule; // e.g. "Mon/Wed 10:00 AM"

  ClassSection({
    required this.id,
    required this.courseId,
    required this.name,
    required this.schedule,
  });
}

class AttendanceRecord {
  final String studentId;
  final String studentName;
  final String studentPhotoUrl;
  final String status; // "Present" or "Absent"
  final DateTime? detectedTime;
  final double? confidence; // confidence score of face match (e.g. 0.94)
  final bool isManualOverride; // If the teacher manually toggled status

  AttendanceRecord({
    required this.studentId,
    required this.studentName,
    required this.studentPhotoUrl,
    required this.status,
    this.detectedTime,
    this.confidence,
    this.isManualOverride = false,
  });

  AttendanceRecord copyWith({
    String? studentId,
    String? studentName,
    String? studentPhotoUrl,
    String? status,
    DateTime? detectedTime,
    double? confidence,
    bool? isManualOverride,
  }) {
    return AttendanceRecord(
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentPhotoUrl: studentPhotoUrl ?? this.studentPhotoUrl,
      status: status ?? this.status,
      detectedTime: detectedTime ?? this.detectedTime,
      confidence: confidence ?? this.confidence,
      isManualOverride: isManualOverride ?? this.isManualOverride,
    );
  }
}

class AttendanceSession {
  final String id;
  final String courseId;
  final String courseCode;
  final String courseName;
  final String sectionName;
  final DateTime timestamp;
  final List<AttendanceRecord> records;

  AttendanceSession({
    required this.id,
    required this.courseId,
    required this.courseCode,
    required this.courseName,
    required this.sectionName,
    required this.timestamp,
    required this.records,
  });

  int get presentCount => records.where((r) => r.status == 'Present').length;
  int get absentCount => records.where((r) => r.status == 'Absent').length;
  double get attendanceRate => records.isEmpty ? 0.0 : (presentCount / records.length) * 100;
}
