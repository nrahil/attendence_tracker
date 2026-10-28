import 'package:cloud_firestore/cloud_firestore.dart';

enum LeaveStatus {
  pending,
  approved,
  rejected;

  String get displayName {
    switch (this) {
      case LeaveStatus.pending:
        return 'Pending';
      case LeaveStatus.approved:
        return 'Approved';
      case LeaveStatus.rejected:
        return 'Rejected';
    }
  }
}

class LeaveRequest {
  final String id;
  final String studentId;
  final String studentName;
  final String courseId;
  final String courseName;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String leaveType; // Medical, Family, Academic, etc.
  final LeaveStatus status;
  final DateTime submittedAt;
  final String? reviewedBy;
  final String? reviewedByName;
  final DateTime? reviewedAt;
  final String? reviewNote;

  LeaveRequest({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.courseId,
    required this.courseName,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.leaveType = 'Medical',
    this.status = LeaveStatus.pending,
    required this.submittedAt,
    this.reviewedBy,
    this.reviewedByName,
    this.reviewedAt,
    this.reviewNote,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'studentId': studentId,
    'studentName': studentName,
    'courseId': courseId,
    'courseName': courseName,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': Timestamp.fromDate(endDate),
    'reason': reason,
    'leaveType': leaveType,
    'status': status.name,
    'submittedAt': Timestamp.fromDate(submittedAt),
    'reviewedBy': reviewedBy,
    'reviewedByName': reviewedByName,
    'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
    'reviewNote': reviewNote,
  };

  factory LeaveRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return LeaveRequest(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      courseId: data['courseId'] ?? '',
      courseName: data['courseName'] ?? '',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reason: data['reason'] ?? '',
      leaveType: data['leaveType'] ?? 'General',
      status: LeaveStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => LeaveStatus.pending,
      ),
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedBy: data['reviewedBy'],
      reviewedByName: data['reviewedByName'],
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewNote: data['reviewNote'],
    );
  }

  LeaveRequest copyWith({
    LeaveStatus? status,
    String? reviewedBy,
    String? reviewedByName,
    DateTime? reviewedAt,
    String? reviewNote,
  }) {
    return LeaveRequest(
      id: id,
      studentId: studentId,
      studentName: studentName,
      courseId: courseId,
      courseName: courseName,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
      leaveType: leaveType,
      status: status ?? this.status,
      submittedAt: submittedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedByName: reviewedByName ?? this.reviewedByName,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewNote: reviewNote ?? this.reviewNote,
    );
  }
}

