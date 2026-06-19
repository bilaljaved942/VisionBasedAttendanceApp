import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/course_model.dart';

class AppState extends ChangeNotifier {
  // ─── Auth ────────────────────────────────────────────
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isInstructor => _currentUser?.role == UserRole.instructor;
  bool get isStudent => _currentUser?.role == UserRole.student;

  // ─── Registered users (acts as in-memory DB) ─────────
  final List<UserModel> _users = [];
  List<UserModel> get allUsers => List.unmodifiable(_users);

  List<StudentModel> get allStudents =>
      _users.whereType<StudentModel>().toList();

  List<InstructorModel> get allInstructors =>
      _users.whereType<InstructorModel>().toList();

  // ─── Courses ──────────────────────────────────────────
  final List<CourseModel> _courses = [];
  List<CourseModel> get allCourses => List.unmodifiable(_courses);

  /// Courses belonging to the currently logged-in instructor
  List<CourseModel> get myCourses {
    if (_currentUser == null) return [];
    return _courses
        .where((c) => c.instructorId == _currentUser!.id)
        .toList();
  }

  /// Courses the currently logged-in student is enrolled in
  List<CourseModel> get enrolledCourses {
    if (_currentUser == null) return [];
    return _courses
        .where((c) => c.enrolledStudentIds.contains(_currentUser!.id))
        .toList();
  }

  // ─── Active Attendance Session ────────────────────────
  bool _isSessionActive = false;
  bool get isSessionActive => _isSessionActive;

  CourseModel? _activeSessionCourse;
  CourseModel? get activeSessionCourse => _activeSessionCourse;

  List<AttendanceRecord> _sessionRecords = [];
  List<AttendanceRecord> get sessionRecords =>
      List.unmodifiable(_sessionRecords);

  Timer? _detectionTimer;

  // ─── Attendance History ───────────────────────────────
  final List<AttendanceSession> _sessions = [];
  List<AttendanceSession> get allSessions => List.unmodifiable(_sessions);

  // ─── Auth Methods ─────────────────────────────────────

  /// Returns null on success, or an error message string
  String? login(String email, String password) {
    final email_ = email.trim().toLowerCase();
    final user = _users.firstWhere(
      (u) =>
          u.email.toLowerCase() == email_ &&
          u.password == password,
      orElse: () => _dummyUser,
    );
    if (user == _dummyUser) {
      return 'Invalid email or password.';
    }
    _currentUser = user;
    notifyListeners();
    return null;
  }

  String? registerUser(UserModel user) {
    final existingEmail = _users.any(
      (u) => u.email.toLowerCase() == user.email.toLowerCase(),
    );
    if (existingEmail) {
      return 'An account with this email already exists.';
    }
    _users.add(user);
    _currentUser = user;
    notifyListeners();
    return null;
  }

  void logout() {
    stopAttendanceSession();
    _currentUser = null;
    notifyListeners();
  }

  // ─── Course Management ────────────────────────────────

  void createCourse(CourseModel course) {
    _courses.add(course);
    notifyListeners();
  }

  void updateCourse(CourseModel updated) {
    final idx = _courses.indexWhere((c) => c.id == updated.id);
    if (idx != -1) {
      _courses[idx] = updated;
      notifyListeners();
    }
  }

  void deleteCourse(String courseId) {
    _courses.removeWhere((c) => c.id == courseId);
    notifyListeners();
  }

  /// Enroll a student into a course
  String? enrollStudent(String courseId, String studentId) {
    final idx = _courses.indexWhere((c) => c.id == courseId);
    if (idx == -1) return 'Course not found.';
    if (_courses[idx].enrolledStudentIds.contains(studentId)) {
      return 'Student is already enrolled.';
    }
    final updated = List<String>.from(_courses[idx].enrolledStudentIds)
      ..add(studentId);
    _courses[idx] = _courses[idx].copyWith(enrolledStudentIds: updated);
    notifyListeners();
    return null;
  }

  /// Remove a student from a course
  void removeStudentFromCourse(String courseId, String studentId) {
    final idx = _courses.indexWhere((c) => c.id == courseId);
    if (idx == -1) return;
    final updated = List<String>.from(_courses[idx].enrolledStudentIds)
      ..remove(studentId);
    _courses[idx] = _courses[idx].copyWith(enrolledStudentIds: updated);
    notifyListeners();
  }

  // ─── Attendance Session ───────────────────────────────

  void startAttendanceSession(CourseModel course) {
    _activeSessionCourse = course;
    _isSessionActive = true;

    // Initialize all enrolled students as Absent
    _sessionRecords = course.enrolledStudentIds
        .map((sid) => AttendanceRecord(studentId: sid))
        .toList();

    notifyListeners();

    // Simulate face detection: every 2.5 seconds, detect a random absent student
    _detectionTimer =
        Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      _simulateDetection();
    });
  }

  void _simulateDetection() {
    final absent = _sessionRecords.where((r) => !r.isPresent).toList();
    if (absent.isEmpty) {
      _detectionTimer?.cancel();
      return;
    }
    final rng = Random();
    // 80% chance to detect a student on each tick
    if (rng.nextDouble() < 0.80) {
      final target = absent[rng.nextInt(absent.length)];
      final idx =
          _sessionRecords.indexWhere((r) => r.studentId == target.studentId);
      if (idx != -1) {
        _sessionRecords[idx].isPresent = true;
        _sessionRecords[idx].detectedAt = DateTime.now();
        _sessionRecords[idx].confidence = 0.82 + rng.nextDouble() * 0.17;
        notifyListeners();
      }
    }
  }

  /// Manually toggle a student's attendance during session
  void toggleStudentAttendance(String studentId) {
    final idx =
        _sessionRecords.indexWhere((r) => r.studentId == studentId);
    if (idx != -1) {
      _sessionRecords[idx].isPresent = !_sessionRecords[idx].isPresent;
      if (_sessionRecords[idx].isPresent) {
        _sessionRecords[idx].detectedAt = DateTime.now();
        _sessionRecords[idx].confidence = 1.0; // manual = 100%
      } else {
        _sessionRecords[idx].detectedAt = null;
        _sessionRecords[idx].confidence = null;
      }
      notifyListeners();
    }
  }

  void stopAttendanceSession() {
    _detectionTimer?.cancel();
    _isSessionActive = false;
    _activeSessionCourse = null;
    _sessionRecords = [];
    notifyListeners();
  }

  void saveAndEndSession() {
    _detectionTimer?.cancel();
    if (_activeSessionCourse != null) {
      final session = AttendanceSession(
        id: generateId(),
        courseId: _activeSessionCourse!.id,
        instructorId: _currentUser!.id,
        date: DateTime.now(),
        records: List.from(_sessionRecords),
      );
      _sessions.add(session);
    }
    stopAttendanceSession();
  }

  // ─── Query Helpers ────────────────────────────────────

  UserModel? getUserById(String id) {
    try {
      return _users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  StudentModel? getStudentById(String id) {
    try {
      return _users.whereType<StudentModel>().firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Get sessions for a specific course
  List<AttendanceSession> getSessionsForCourse(String courseId) =>
      _sessions.where((s) => s.courseId == courseId).toList();

  /// Get attendance percentage for a student in a course
  double getStudentAttendance(String studentId, String courseId) {
    final sessions = getSessionsForCourse(courseId);
    if (sessions.isEmpty) return 0.0;
    final present = sessions
        .where((s) => s.records.any(
              (r) => r.studentId == studentId && r.isPresent,
            ))
        .length;
    return (present / sessions.length) * 100;
  }

  // Sentinel user used to signal "not found" in firstWhere
  static final _dummyUser = UserModel(
    id: '__dummy__',
    name: '',
    email: '',
    password: '',
    role: UserRole.student,
  );

  @override
  void dispose() {
    _detectionTimer?.cancel();
    super.dispose();
  }
}
