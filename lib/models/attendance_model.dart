import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  student,
  teacher,
  parent,
  admin;

  String get displayName {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.parent:
        return 'Parent';
      case UserRole.admin:
        return 'Administrator';
    }
  }
}

enum AttendanceStatus {
  present,
  absent,
  late,
  excused;

  String get displayName {
    switch (this) {
      case AttendanceStatus.present:
        return 'Present';
      case AttendanceStatus.absent:
        return 'Absent';
      case AttendanceStatus.late:
        return 'Late';
      case AttendanceStatus.excused:
        return 'Excused';
    }
  }
}

/// Immutable audit entry recording manual edits to attendance
class AuditEntry {
  final String modifiedBy;
  final String modifiedByName;
  final DateTime timestamp;
  final AttendanceStatus previousStatus;
  final AttendanceStatus newStatus;
  final String reason;

  AuditEntry({
    required this.modifiedBy,
    required this.modifiedByName,
    required this.timestamp,
    required this.previousStatus,
    required this.newStatus,
    required this.reason,
  });

  Map<String, dynamic> toMap() => {
    'modifiedBy': modifiedBy,
    'modifiedByName': modifiedByName,
    'timestamp': Timestamp.fromDate(timestamp),
    'previousStatus': previousStatus.name,
    'newStatus': newStatus.name,
    'reason': reason,
  };

  factory AuditEntry.fromMap(Map<String, dynamic> map) => AuditEntry(
    modifiedBy: map['modifiedBy'] ?? '',
    modifiedByName: map['modifiedByName'] ?? '',
    timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    previousStatus: AttendanceStatus.values.firstWhere(
      (e) => e.name == map['previousStatus'],
      orElse: () => AttendanceStatus.absent,
    ),
    newStatus: AttendanceStatus.values.firstWhere(
      (e) => e.name == map['newStatus'],
      orElse: () => AttendanceStatus.present,
    ),
    reason: map['reason'] ?? '',
  );
}

/// Core attendance record supporting 3-state statuses + late minutes + audit trail
class AttendanceRecord {
  final String id;
  final String studentId;
  final String studentName;
  final String courseId;
  final String courseName;
  final DateTime date;
  final AttendanceStatus status;
  final int lateMinutes;
  final String markedBy;
  final String markedByName;
  final String notes;
  final List<AuditEntry> auditTrail;
  final DateTime createdAt;

  AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.courseId,
    this.courseName = '',
    required this.date,
    required this.status,
    this.lateMinutes = 0,
    required this.markedBy,
    this.markedByName = '',
    this.notes = '',
    this.auditTrail = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'studentId': studentId,
    'studentName': studentName,
    'courseId': courseId,
    'courseName': courseName,
    'date': Timestamp.fromDate(date),
    'status': status.name,
    'lateMinutes': lateMinutes,
    'markedBy': markedBy,
    'markedByName': markedByName,
    'notes': notes,
    'auditTrail': auditTrail.map((e) => e.toMap()).toList(),
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory AttendanceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AttendanceRecord(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      courseId: data['courseId'] ?? '',
      courseName: data['courseName'] ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: AttendanceStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => AttendanceStatus.absent,
      ),
      lateMinutes: (data['lateMinutes'] as num?)?.toInt() ?? 0,
      markedBy: data['markedBy'] ?? '',
      markedByName: data['markedByName'] ?? '',
      notes: data['notes'] ?? '',
      auditTrail: ((data['auditTrail'] as List<dynamic>?) ?? [])
          .map((e) => AuditEntry.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  AttendanceRecord copyWith({
    AttendanceStatus? status,
    int? lateMinutes,
    String? notes,
    List<AuditEntry>? auditTrail,
  }) {
    return AttendanceRecord(
      id: id,
      studentId: studentId,
      studentName: studentName,
      courseId: courseId,
      courseName: courseName,
      date: date,
      status: status ?? this.status,
      lateMinutes: lateMinutes ?? this.lateMinutes,
      markedBy: markedBy,
      markedByName: markedByName,
      notes: notes ?? this.notes,
      auditTrail: auditTrail ?? this.auditTrail,
      createdAt: createdAt,
    );
  }
}

/// User Profile with Role-Based Access Control metadata
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String studentId;
  final String phone;
  final List<String> enrolledCourses;
  final List<String> childrenIds; // for Parents
  final int attendanceThreshold;

  AppUser({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.role = UserRole.student,
    this.studentId = '',
    this.phone = '',
    this.enrolledCourses = const [],
    this.childrenIds = const [],
    this.attendanceThreshold = 75,
  });

  Map<String, dynamic> toMap() => {
    'uid': uid,
    'email': email,
    'displayName': displayName,
    'role': role.name,
    'studentId': studentId,
    'phone': phone,
    'enrolledCourses': enrolledCourses,
    'childrenIds': childrenIds,
    'attendanceThreshold': attendanceThreshold,
  };

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AppUser(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == data['role'],
        orElse: () => UserRole.student,
      ),
      studentId: data['studentId'] ?? '',
      phone: data['phone'] ?? '',
      enrolledCourses: List<String>.from(data['enrolledCourses'] ?? []),
      childrenIds: List<String>.from(data['childrenIds'] ?? []),
      attendanceThreshold: (data['attendanceThreshold'] as num?)?.toInt() ?? 75,
    );
  }
}

