import 'dart:math';

enum UserRole { instructor, student }

class UserModel {
  final String id;
  final String name;
  final String email;
  final String password; // In production, this would be hashed
  final UserRole role;
  final String? faceImagePath; // Path or base64 of captured face

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.faceImagePath,
  });

  UserModel copyWith({
    String? name,
    String? email,
    String? faceImagePath,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password,
      role: role,
      faceImagePath: faceImagePath ?? this.faceImagePath,
    );
  }

  /// Returns user's initials (e.g. "AH" from "Ali Hassan")
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// First name only
  String get firstName => name.split(' ').first;
}

class StudentModel extends UserModel {
  final String registrationNumber; // e.g. "21K-3456"

  const StudentModel({
    required super.id,
    required super.name,
    required super.email,
    required super.password,
    required this.registrationNumber,
    super.faceImagePath,
  }) : super(role: UserRole.student);

  @override
  StudentModel copyWith({
    String? name,
    String? email,
    String? faceImagePath,
    String? registrationNumber,
  }) {
    return StudentModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      faceImagePath: faceImagePath ?? this.faceImagePath,
    );
  }
}

class InstructorModel extends UserModel {
  final String? department;

  const InstructorModel({
    required super.id,
    required super.name,
    required super.email,
    required super.password,
    this.department,
    super.faceImagePath,
  }) : super(role: UserRole.instructor);

  @override
  InstructorModel copyWith({
    String? name,
    String? email,
    String? faceImagePath,
    String? department,
  }) {
    return InstructorModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password,
      department: department ?? this.department,
      faceImagePath: faceImagePath ?? this.faceImagePath,
    );
  }
}

/// Helper to generate a unique ID
String generateId() {
  final rng = Random();
  return DateTime.now().millisecondsSinceEpoch.toString() +
      rng.nextInt(9999).toString();
}
