import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';

class AttendanceService {
  static final AttendanceService _instance = AttendanceService._internal();
  factory AttendanceService() => _instance;
  AttendanceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _attendanceCollection => _firestore.collection('attendance_records');
  CollectionReference get _usersCollection => _firestore.collection('users');

  /// Fetch or listen to user profile
  Stream<AppUser> streamUserProfile(String uid) {
    return _usersCollection.doc(uid).snapshots().map((doc) {
      if (!doc.exists) {
        return AppUser(uid: uid, email: '');
      }
      return AppUser.fromFirestore(doc);
    });
  }

  /// Update user's RBAC role
  Future<void> updateUserRole(String uid, UserRole role) async {
    await _usersCollection.doc(uid).set({
      'role': role.name,
      'updatedAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  /// Mark or update a single attendance record with audit trail
  Future<void> markAttendance({
    required AttendanceRecord record,
    required String actorId,
    required String actorName,
    String reason = 'Initial mark',
  }) async {
    final docRef = _attendanceCollection.doc(record.id.isEmpty ? null : record.id);
    
    // Check if previous record exists to append to audit trail
    final existingDoc = await docRef.get();
    List<AuditEntry> trail = List<AuditEntry>.from(record.auditTrail);

    if (existingDoc.exists) {
      final existingData = AttendanceRecord.fromFirestore(existingDoc);
      trail.add(
        AuditEntry(
          modifiedBy: actorId,
          modifiedByName: actorName,
          timestamp: DateTime.now(),
          previousStatus: existingData.status,
          newStatus: record.status,
          reason: reason,
        ),
      );
    } else {
      trail.add(
        AuditEntry(
          modifiedBy: actorId,
          modifiedByName: actorName,
          timestamp: DateTime.now(),
          previousStatus: AttendanceStatus.absent,
          newStatus: record.status,
          reason: reason,
        ),
      );
    }

    final finalRecord = record.copyWith(auditTrail: trail);
    await docRef.set(finalRecord.toMap(), SetOptions(merge: true));
  }

  /// 1-Tap Bulk Mark Attendance for a course session (e.g. "Mark All Present")
  Future<void> bulkMarkAttendance({
    required String courseId,
    required String courseName,
    required List<Map<String, String>> students, // [{'id': '123', 'name': 'John'}]
    required DateTime date,
    required AttendanceStatus status,
    required String teacherId,
    required String teacherName,
    String reason = 'Bulk session mark',
  }) async {
    final batch = _firestore.batch();
    final dateKey = '${date.year}_${date.month}_${date.day}';

    for (final student in students) {
      final sId = student['id'] ?? '';
      final sName = student['name'] ?? '';
      final docId = '${courseId}_${sId}_$dateKey';
      final docRef = _attendanceCollection.doc(docId);

      final record = AttendanceRecord(
        id: docId,
        studentId: sId,
        studentName: sName,
        courseId: courseId,
        courseName: courseName,
        date: DateTime(date.year, date.month, date.day),
        status: status,
        markedBy: teacherId,
        markedByName: teacherName,
        notes: reason,
        auditTrail: [
          AuditEntry(
            modifiedBy: teacherId,
            modifiedByName: teacherName,
            timestamp: DateTime.now(),
            previousStatus: AttendanceStatus.absent,
            newStatus: status,
            reason: reason,
          ),
        ],
        createdAt: DateTime.now(),
      );

      batch.set(docRef, record.toMap(), SetOptions(merge: true));
    }

    await batch.commit();
  }

  /// Stream of records for a student across all courses or a single course
  Stream<List<AttendanceRecord>> streamStudentRecords(String studentId, {String? courseId}) {
    Query query = _attendanceCollection.where('studentId', isEqualTo: studentId);
    if (courseId != null && courseId.isNotEmpty) {
      query = query.where('courseId', isEqualTo: courseId);
    }
    return query.snapshots().map((snap) =>
      snap.docs.map((d) => AttendanceRecord.fromFirestore(d)).toList(),
    );
  }

  /// Stream of records for a course on a specific day (used by Teacher marking screen)
  Stream<List<AttendanceRecord>> streamCourseDateRecords(String courseId, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return _attendanceCollection
        .where('courseId', isEqualTo: courseId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map((snap) => snap.docs.map((d) => AttendanceRecord.fromFirestore(d)).toList());
  }

  /// Stream all records for a course (for analytics)
  Stream<List<AttendanceRecord>> streamCourseAllRecords(String courseId) {
    return _attendanceCollection
        .where('courseId', isEqualTo: courseId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => AttendanceRecord.fromFirestore(d)).toList());
  }
}

