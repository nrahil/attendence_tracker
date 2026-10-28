import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/leave_request_model.dart';
import '../models/attendance_model.dart';
import 'attendance_service.dart';
import 'notification_alert_service.dart';

class LeaveService {
  static final LeaveService _instance = LeaveService._internal();
  factory LeaveService() => _instance;
  LeaveService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AttendanceService _attendanceService = AttendanceService();
  final NotificationAlertService _alertService = NotificationAlertService();

  CollectionReference get _leaveCollection => _firestore.collection('leave_requests');

  /// Submit a new leave request
  Future<void> submitLeaveRequest(LeaveRequest request) async {
    final docRef = _leaveCollection.doc(request.id.isEmpty ? null : request.id);
    final reqWithId = LeaveRequest(
      id: docRef.id,
      studentId: request.studentId,
      studentName: request.studentName,
      courseId: request.courseId,
      courseName: request.courseName,
      startDate: request.startDate,
      endDate: request.endDate,
      reason: request.reason,
      leaveType: request.leaveType,
      status: LeaveStatus.pending,
      submittedAt: DateTime.now(),
    );
    await docRef.set(reqWithId.toMap());
  }

  /// Stream pending requests for a course or all courses (Teacher inbox)
  Stream<List<LeaveRequest>> streamPendingRequests({String? courseId}) {
    Query query = _leaveCollection.where('status', isEqualTo: LeaveStatus.pending.name);
    if (courseId != null && courseId.isNotEmpty) {
      query = query.where('courseId', isEqualTo: courseId);
    }
    return query.snapshots().map((snap) =>
      snap.docs.map((d) => LeaveRequest.fromFirestore(d)).toList(),
    );
  }

  /// Stream leave requests for a student
  Stream<List<LeaveRequest>> streamStudentRequests(String studentId) {
    return _leaveCollection
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => LeaveRequest.fromFirestore(d)).toList());
  }

  /// Approve a leave request and auto-update attendance records to 'excused'
  Future<void> approveLeaveRequest({
    required LeaveRequest request,
    required String reviewerId,
    required String reviewerName,
    String note = 'Approved by instructor',
  }) async {
    await _leaveCollection.doc(request.id).update({
      'status': LeaveStatus.approved.name,
      'reviewedBy': reviewerId,
      'reviewedByName': reviewerName,
      'reviewedAt': Timestamp.now(),
      'reviewNote': note,
    });

    // Auto-update attendance records in the leave date range to 'excused'
    DateTime current = DateTime(request.startDate.year, request.startDate.month, request.startDate.day);
    final end = DateTime(request.endDate.year, request.endDate.month, request.endDate.day);

    while (!current.isAfter(end)) {
      final dateKey = '${current.year}_${current.month}_${current.day}';
      final recordId = '${request.courseId}_${request.studentId}_$dateKey';

      final record = AttendanceRecord(
        id: recordId,
        studentId: request.studentId,
        studentName: request.studentName,
        courseId: request.courseId,
        courseName: request.courseName,
        date: current,
        status: AttendanceStatus.excused,
        markedBy: reviewerId,
        markedByName: reviewerName,
        notes: 'Leave Approved: ${request.reason}',
        auditTrail: [
          AuditEntry(
            modifiedBy: reviewerId,
            modifiedByName: reviewerName,
            timestamp: DateTime.now(),
            previousStatus: AttendanceStatus.absent,
            newStatus: AttendanceStatus.excused,
            reason: 'Leave request approved ($note)',
          ),
        ],
        createdAt: DateTime.now(),
      );

      await _attendanceService.markAttendance(
        record: record,
        actorId: reviewerId,
        actorName: reviewerName,
        reason: 'Automated adjustment for approved leave',
      );

      current = current.add(const Duration(days: 1));
    }

    // Trigger notification to student & parent
    await _alertService.triggerLeaveStatusAlert(
      studentId: request.studentId,
      studentName: request.studentName,
      leaveType: request.leaveType,
      isApproved: true,
      note: note,
    );
  }

  /// Reject a leave request
  Future<void> rejectLeaveRequest({
    required LeaveRequest request,
    required String reviewerId,
    required String reviewerName,
    String note = 'Insufficient documentation or attendance quota reached',
  }) async {
    await _leaveCollection.doc(request.id).update({
      'status': LeaveStatus.rejected.name,
      'reviewedBy': reviewerId,
      'reviewedByName': reviewerName,
      'reviewedAt': Timestamp.now(),
      'reviewNote': note,
    });

    await _alertService.triggerLeaveStatusAlert(
      studentId: request.studentId,
      studentName: request.studentName,
      leaveType: request.leaveType,
      isApproved: false,
      note: note,
    );
  }
}

