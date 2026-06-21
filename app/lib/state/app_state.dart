import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/course_model.dart';
import '../services/supabase_service.dart';

class AppState extends ChangeNotifier {
  // ─── Auth State ───────────────────────────────────────
  UserModel? _currentUser;
  bool _isCheckingAuth = true;
  bool _isLoading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isCheckingAuth => _isCheckingAuth;
  bool get isLoading => _isLoading;

  // ─── Data Cache ───────────────────────────────────────
  List<StudentModel> _allStudents = [];
  List<CourseModel> _myCourses = [];
  final Map<String, List<AttendanceSession>> _sessionsCache = {};
  final Map<String, double> _attendanceCache = {};

  List<StudentModel> get allStudents => List.unmodifiable(_allStudents);
  List<CourseModel> get myCourses => List.unmodifiable(_myCourses);
  List<CourseModel> get enrolledCourses => List.unmodifiable(_myCourses);
  List<CourseModel> get allCourses => List.unmodifiable(_myCourses);

  // ─── Active Attendance Session ────────────────────────
  CourseModel? _activeSessionCourse;
  List<AttendanceRecord> _sessionRecords = [];
  Timer? _detectionTimer;

  CourseModel? get activeSessionCourse => _activeSessionCourse;
  List<AttendanceRecord> get sessionRecords => List.unmodifiable(_sessionRecords);

  // ─── On App Start ─────────────────────────────────────

  Future<void> checkAuthState() async {
    _isCheckingAuth = true;
    notifyListeners();
    final session = SupabaseService.client.auth.currentSession;
    if (session != null) {
      await _loadCurrentUser();
    }
    _isCheckingAuth = false;
    notifyListeners();
  }

  // ─── Auth Operations ──────────────────────────────────

  Future<String?> login(String email, String password) async {
    _setLoading(true);
    final error =
        await SupabaseService.signIn(email: email, password: password);
    if (error != null) {
      _setLoading(false);
      return error;
    }
    await _loadCurrentUser();
    _setLoading(false);
    return null;
  }

  Future<String?> registerUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? registrationNumber,
    String? department,
    XFile? faceImage,
  }) async {
    _setLoading(true);
    final error = await SupabaseService.signUp(
      name: name,
      email: email,
      password: password,
      role: role,
      registrationNumber: registrationNumber,
      department: department,
      faceImage: faceImage,
    );
    if (error != null) {
      _setLoading(false);
      return error;
    }
    await _loadCurrentUser();
    _setLoading(false);
    return null;
  }

  Future<String?> updateStudentFaceImage(XFile file) async {
    if (_currentUser == null) return 'No user logged in';
    _setLoading(true);
    try {
      final bytes = await file.readAsBytes();
      final fileExt = file.path.split('.').last;
      final fileName = '${_currentUser!.id}.$fileExt';
      
      await SupabaseService.client.storage.from('face-images').uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );
      
      final faceUrl = SupabaseService.client.storage.from('face-images').getPublicUrl(fileName);
      
      await SupabaseService.client.from('profiles').update({
        'face_url': faceUrl,
      }).eq('id', _currentUser!.id);
      
      await _loadCurrentUser();
      _setLoading(false);
      return null;
    } catch (e) {
      _setLoading(false);
      return 'Failed to upload image: $e';
    }
  }

  Future<void> logout() async {
    _stopDetectionTimer();
    await SupabaseService.signOut();
    _currentUser = null;
    _allStudents = [];
    _myCourses = [];
    _sessionsCache.clear();
    _attendanceCache.clear();
    _activeSessionCourse = null;
    _sessionRecords = [];
    notifyListeners();
  }

  // ─── Data Loading ─────────────────────────────────────

  Future<void> _loadCurrentUser() async {
    final uid = SupabaseService.client.auth.currentUser?.id;
    if (uid == null) return;
    _currentUser = await SupabaseService.getProfile(uid);
    if (_currentUser != null) await _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (_currentUser == null) return;
    if (_currentUser!.role == UserRole.instructor) {
      _allStudents =
          await SupabaseService.getAllStudents();
      _myCourses =
          await SupabaseService.getInstructorCourses(_currentUser!.id);
    } else {
      _myCourses =
          await SupabaseService.getStudentCourses(_currentUser!.id);
      for (final course in _myCourses) {
        _sessionsCache[course.id] =
            await SupabaseService.getSessionsForCourse(course.id);
        _attendanceCache[course.id] =
            await SupabaseService.getStudentAttendance(
                _currentUser!.id, course.id);
      }
    }
  }

  Future<void> refreshCourses() async {
    if (_currentUser == null) return;
    _setLoading(true);
    try {
      if (_currentUser!.role == UserRole.instructor) {
        _myCourses =
            await SupabaseService.getInstructorCourses(_currentUser!.id);
      } else {
        _myCourses =
            await SupabaseService.getStudentCourses(_currentUser!.id);
        for (final course in _myCourses) {
          _sessionsCache[course.id] =
              await SupabaseService.getSessionsForCourse(course.id);
          _attendanceCache[course.id] =
              await SupabaseService.getStudentAttendance(
                  _currentUser!.id, course.id);
        }
      }
    } catch (_) {}
    _setLoading(false);
    notifyListeners();
  }

  // ─── Course Management ────────────────────────────────

  Future<String?> createCourse(CourseModel course) async {
    final created = await SupabaseService.createCourse(course);
    if (created != null) {
      _myCourses = [created, ..._myCourses];
      notifyListeners();
      return null;
    }
    return 'Failed to create course. Please try again.';
  }

  Future<void> deleteCourse(String courseId) async {
    await SupabaseService.deleteCourse(courseId);
    _myCourses = _myCourses.where((c) => c.id != courseId).toList();
    notifyListeners();
  }

  Future<String?> updateCourse(CourseModel course) async {
    final success = await SupabaseService.updateCourse(course);
    if (success) {
      final idx = _myCourses.indexWhere((c) => c.id == course.id);
      if (idx != -1) {
        final updatedCourse = course.copyWith(
          enrolledStudentIds: _myCourses[idx].enrolledStudentIds,
        );
        _myCourses[idx] = updatedCourse;
        notifyListeners();
      }
      return null;
    }
    return 'Failed to update course. Please try again.';
  }

  Future<String?> enrollStudent(String courseId, String studentId) async {
    final error =
        await SupabaseService.enrollStudent(courseId, studentId);
    if (error == null) await refreshCourses();
    return error;
  }

  Future<void> removeStudentFromCourse(
      String courseId, String studentId) async {
    await SupabaseService.removeStudent(courseId, studentId);
    await refreshCourses();
  }

  // ─── Data Accessors ───────────────────────────────────

  StudentModel? getStudentById(String id) {
    try {
      return _allStudents.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  List<AttendanceSession> getSessionsForCourse(String courseId) =>
      _sessionsCache[courseId] ?? [];

  Future<void> loadSessionsForCourse(String courseId) async {
    _setLoading(true);
    try {
      final sessions = await SupabaseService.getSessionsForCourse(courseId);
      _sessionsCache[courseId] = sessions;
    } catch (_) {
      // keep empty
    }
    _setLoading(false);
    notifyListeners();
  }

  double getStudentAttendance(String studentId, String courseId) =>
      _attendanceCache[courseId] ?? 0.0;

  // ─── Attendance Session (local simulation) ────────────

  void startAttendanceSession(CourseModel course) {
    _activeSessionCourse = course;
    _sessionRecords = course.enrolledStudentIds
        .map((id) => AttendanceRecord(studentId: id))
        .toList();
    notifyListeners();

    _detectionTimer =
        Timer.periodic(const Duration(milliseconds: 2500), (_) {
      _simulateDetection();
    });
  }

  void _simulateDetection() {
    final absent =
        _sessionRecords.where((r) => !r.isPresent).toList();
    if (absent.isEmpty) {
      _stopDetectionTimer();
      return;
    }
    final rng = Random();
    if (rng.nextDouble() < 0.80) {
      final target = absent[rng.nextInt(absent.length)];
      final idx = _sessionRecords
          .indexWhere((r) => r.studentId == target.studentId);
      if (idx != -1) {
        _sessionRecords[idx].isPresent = true;
        _sessionRecords[idx].detectedAt = DateTime.now();
        _sessionRecords[idx].confidence = 0.82 + rng.nextDouble() * 0.17;
        notifyListeners();
      }
    }
  }

  void toggleStudentAttendance(String studentId) {
    final idx =
        _sessionRecords.indexWhere((r) => r.studentId == studentId);
    if (idx != -1) {
      _sessionRecords[idx].isPresent = !_sessionRecords[idx].isPresent;
      if (_sessionRecords[idx].isPresent) {
        _sessionRecords[idx].detectedAt = DateTime.now();
        _sessionRecords[idx].confidence = 1.0;
      } else {
        _sessionRecords[idx].detectedAt = null;
        _sessionRecords[idx].confidence = null;
      }
      notifyListeners();
    }
  }

  Future<void> saveAndEndSession({
    required String lectureName,
    required DateTime date,
  }) async {
    _stopDetectionTimer();
    if (_activeSessionCourse != null && _currentUser != null) {
      await SupabaseService.saveAttendanceSession(
        courseId: _activeSessionCourse!.id,
        instructorId: _currentUser!.id,
        lectureName: lectureName,
        date: date,
        records: List.from(_sessionRecords),
      );
    }
    _activeSessionCourse = null;
    _sessionRecords = [];
    notifyListeners();
  }

  // ─── Helpers ──────────────────────────────────────────

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }

  void _stopDetectionTimer() {
    _detectionTimer?.cancel();
    _detectionTimer = null;
  }

  @override
  void dispose() {
    _stopDetectionTimer();
    super.dispose();
  }
}
