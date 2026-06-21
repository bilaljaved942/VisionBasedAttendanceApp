import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/course_model.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  // ─── AUTH ─────────────────────────────────────────────

  static Future<String?> signUp({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? registrationNumber,
    String? department,
    XFile? faceImage,
  }) async {
    try {
      final response = await client.auth.signUp(
        email: email,
        password: password,
      );
      if (response.user == null) return 'Sign up failed. Please try again.';

      String? faceUrl;
      if (faceImage != null) {
        try {
          final bytes = await faceImage.readAsBytes();
          final fileExt = faceImage.path.split('.').last;
          final fileName = '${response.user!.id}.$fileExt';
          await client.storage.from('face-images').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
            ),
          );
          faceUrl = client.storage.from('face-images').getPublicUrl(fileName);
        } catch (e) {
          // ignore storage upload failures and proceed with null face_url
          debugPrint('Supabase Storage Upload Error: $e');
        }
      }

      await client.from('profiles').insert({
        'id': response.user!.id,
        'name': name,
        'email': email,
        'role': role == UserRole.instructor ? 'instructor' : 'student',
        'reg_number': registrationNumber,
        'department': department,
        'face_url': faceUrl,
      });

      return null; // success
    } on AuthException catch (e) {
      return e.message;
    } on PostgrestException catch (e) {
      return e.message;
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  static Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return null; // success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  // ─── PROFILES ─────────────────────────────────────────

  static Future<UserModel?> getProfile(String uid) async {
    try {
      final data = await client
          .from('profiles')
          .select()
          .eq('id', uid)
          .single();
      return _toModel(data);
    } catch (_) {
      return null;
    }
  }

  static Future<List<StudentModel>> getAllStudents() async {
    try {
      final data = await client
          .from('profiles')
          .select()
          .eq('role', 'student')
          .order('name');
      return data
          .map<StudentModel>((d) => _toModel(d) as StudentModel)
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ─── COURSES ──────────────────────────────────────────

  static Future<List<CourseModel>> getInstructorCourses(
      String instructorId) async {
    try {
      final data = await client
          .from('courses')
          .select('*, enrollments(student_id)')
          .eq('instructor_id', instructorId)
          .order('created_at', ascending: false);

      return (data as List).map<CourseModel>((d) {
        final enrollments = (d['enrollments'] as List?) ?? [];
        return CourseModel(
          id: d['id'],
          name: d['name'],
          code: d['code'],
          section: d['section'],
          semester: d['semester'],
          instructorId: d['instructor_id'],
          enrolledStudentIds:
              enrollments.map<String>((e) => e['student_id'] as String).toList(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<CourseModel>> getStudentCourses(String studentId) async {
    try {
      final data = await client
          .from('enrollments')
          .select('courses(*, enrollments(student_id))')
          .eq('student_id', studentId);

      return (data as List).map<CourseModel>((e) {
        final c = e['courses'] as Map<String, dynamic>;
        final enrollments = (c['enrollments'] as List?) ?? [];
        return CourseModel(
          id: c['id'],
          name: c['name'],
          code: c['code'],
          section: c['section'],
          semester: c['semester'],
          instructorId: c['instructor_id'],
          enrolledStudentIds:
              enrollments.map<String>((en) => en['student_id'] as String).toList(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Returns the created CourseModel with its Supabase-generated UUID.
  static Future<CourseModel?> createCourse(CourseModel course) async {
    try {
      final data = await client
          .from('courses')
          .insert({
            'name': course.name,
            'code': course.code,
            'section': course.section,
            'semester': course.semester,
            'instructor_id': course.instructorId,
          })
          .select()
          .single();

      return CourseModel(
        id: data['id'],
        name: data['name'],
        code: data['code'],
        section: data['section'],
        semester: data['semester'],
        instructorId: data['instructor_id'],
        enrolledStudentIds: [],
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteCourse(String courseId) async {
    await client.from('courses').delete().eq('id', courseId);
  }

  static Future<bool> updateCourse(CourseModel course) async {
    try {
      await client.from('courses').update({
        'name': course.name,
        'code': course.code,
        'section': course.section,
        'semester': course.semester,
      }).eq('id', course.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── ENROLLMENTS ──────────────────────────────────────

  static Future<String?> enrollStudent(
      String courseId, String studentId) async {
    try {
      await client.from('enrollments').insert({
        'course_id': courseId,
        'student_id': studentId,
      });
      return null;
    } on PostgrestException catch (e) {
      if (e.code == '23505') return 'Student is already enrolled.';
      return e.message;
    } catch (_) {
      return 'Failed to enroll student.';
    }
  }

  static Future<void> removeStudent(
      String courseId, String studentId) async {
    await client
        .from('enrollments')
        .delete()
        .eq('course_id', courseId)
        .eq('student_id', studentId);
  }

  // ─── ATTENDANCE ───────────────────────────────────────

  static Future<void> saveAttendanceSession({
    required String courseId,
    required String instructorId,
    required String lectureName,
    required DateTime date,
    required List<AttendanceRecord> records,
  }) async {
    try {
      // Insert session, get back generated UUID
      final sessionData = await client
          .from('attendance_sessions')
          .insert({
            'course_id': courseId,
            'instructor_id': instructorId,
            'lecture_name': lectureName,
            'date': date.toIso8601String(),
          })
          .select()
          .single();

      final sessionId = sessionData['id'] as String;

      // Bulk insert all attendance records
      final recordRows = records
          .map((r) => {
                'session_id': sessionId,
                'student_id': r.studentId,
                'is_present': r.isPresent,
                'detected_at': r.detectedAt?.toIso8601String(),
                'confidence': r.confidence,
              })
          .toList();

      if (recordRows.isNotEmpty) {
        await client.from('attendance_records').insert(recordRows);
      }
    } catch (_) {
      // silently fail — session data stays local
    }
  }

  static Future<List<AttendanceSession>> getSessionsForCourse(
      String courseId) async {
    try {
      final data = await client
          .from('attendance_sessions')
          .select('*, attendance_records(*)')
          .eq('course_id', courseId)
          .order('date', ascending: false);

      return (data as List).map<AttendanceSession>((s) {
        final rawRecords = (s['attendance_records'] as List?) ?? [];
        final records = rawRecords.map((r) {
          final rec = AttendanceRecord(studentId: r['student_id'] as String);
          rec.isPresent = r['is_present'] as bool;
          rec.confidence = (r['confidence'] as num?)?.toDouble();
          rec.detectedAt = r['detected_at'] != null
              ? DateTime.parse(r['detected_at'] as String)
              : null;
          return rec;
        }).toList();

        return AttendanceSession(
          id: s['id'],
          courseId: s['course_id'],
          instructorId: s['instructor_id'],
          date: DateTime.parse(s['date'] as String),
          lectureName: s['lecture_name'] ?? 'Class Session',
          records: records,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<double> getStudentAttendance(
      String studentId, String courseId) async {
    try {
      // Count total sessions for course
      final sessions = await client
          .from('attendance_sessions')
          .select('id')
          .eq('course_id', courseId);

      if ((sessions as List).isEmpty) return 0.0;

      final sessionIds =
          sessions.map((s) => s['id'] as String).toList();

      // Count sessions where student was present
      final present = await client
          .from('attendance_records')
          .select('id')
          .inFilter('session_id', sessionIds)
          .eq('student_id', studentId)
          .eq('is_present', true);

      return ((present as List).length / sessions.length) * 100;
    } catch (_) {
      return 0.0;
    }
  }

  // ─── HELPERS ──────────────────────────────────────────

  static UserModel _toModel(Map<String, dynamic> d) {
    final role = d['role'] == 'instructor' ? UserRole.instructor : UserRole.student;
    if (role == UserRole.instructor) {
      return InstructorModel(
        id: d['id'],
        name: d['name'],
        email: d['email'],
        password: '',
        department: d['department'] ?? '',
        faceImagePath: d['face_url'],
      );
    } else {
      return StudentModel(
        id: d['id'],
        name: d['name'],
        email: d['email'],
        password: '',
        registrationNumber: d['reg_number'] ?? '',
        faceImagePath: d['face_url'],
      );
    }
  }
}
