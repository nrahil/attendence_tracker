import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/parent_alert_model.dart';

class NotificationAlertService {
  static final NotificationAlertService _instance = NotificationAlertService._internal();
  factory NotificationAlertService() => _instance;
  NotificationAlertService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _alertsCollection => _firestore.collection('parent_alerts');

  /// Triggered automatically when a teacher marks a student absent
  Future<void> triggerAbsenceAlert({
    required String studentId,
    required String studentName,
    required String courseName,
    required DateTime date,
    String parentId = '',
  }) async {
    final dateStr = DateFormat('MMM dd, yyyy').format(date);
    final docRef = _alertsCollection.doc();

    final alert = ParentAlert(
      id: docRef.id,
      parentId: parentId,
      studentId: studentId,
      studentName: studentName,
      title: '🚨 Unexcused Absence: $studentName',
      message: '$studentName was marked absent for $courseName on $dateStr.',
      type: AlertType.absence,
      timestamp: DateTime.now(),
      isRead: false,
      channel: 'push',
    );

    await docRef.set(alert.toMap());
  }

  /// Triggered when a student arrives late
  Future<void> triggerTardyAlert({
    required String studentId,
    required String studentName,
    required String courseName,
    required int lateMinutes,
    required DateTime date,
    String parentId = '',
  }) async {
    final timeStr = DateFormat('hh:mm a').format(date);
    final docRef = _alertsCollection.doc();

    final alert = ParentAlert(
      id: docRef.id,
      parentId: parentId,
      studentId: studentId,
      studentName: studentName,
      title: '⏰ Tardy Notice: $studentName',
      message: '$studentName arrived $lateMinutes minutes late for $courseName today at $timeStr.',
      type: AlertType.tardy,
      timestamp: DateTime.now(),
      isRead: false,
      channel: 'push',
    );

    await docRef.set(alert.toMap());
  }

  /// Triggered when attendance percentage dips below threshold
  Future<void> triggerThresholdAlert({
    required String studentId,
    required String studentName,
    required String courseName,
    required double currentPercentage,
    required double threshold,
    String parentId = '',
  }) async {
    final docRef = _alertsCollection.doc();

    final alert = ParentAlert(
      id: docRef.id,
      parentId: parentId,
      studentId: studentId,
      studentName: studentName,
      title: '⚠️ Attendance Shortage Warning: $studentName',
      message: 'Attendance for $courseName has dropped to ${currentPercentage.toStringAsFixed(1)}% (Institutional requirement: ${threshold.toInt()}%). Intervention may be required.',
      type: AlertType.thresholdWarning,
      timestamp: DateTime.now(),
      isRead: false,
      channel: 'sms',
    );

    await docRef.set(alert.toMap());
  }

  /// Triggered when teacher reviews a leave request
  Future<void> triggerLeaveStatusAlert({
    required String studentId,
    required String studentName,
    required String leaveType,
    required bool isApproved,
    required String note,
    String parentId = '',
  }) async {
    final docRef = _alertsCollection.doc();

    final statusStr = isApproved ? 'Approved ✅' : 'Rejected ❌';
    final alert = ParentAlert(
      id: docRef.id,
      parentId: parentId,
      studentId: studentId,
      studentName: studentName,
      title: 'Leave Request $statusStr: $studentName',
      message: 'The $leaveType leave request for $studentName was $statusStr. Note: $note',
      type: AlertType.leaveUpdate,
      timestamp: DateTime.now(),
      isRead: false,
      channel: 'push',
    );

    await docRef.set(alert.toMap());
  }

  /// Stream live alerts for a student or parent
  Stream<List<ParentAlert>> streamAlerts({String? studentId, String? parentId}) {
    Query query = _alertsCollection.orderBy('timestamp', descending: true);
    if (studentId != null && studentId.isNotEmpty) {
      query = query.where('studentId', isEqualTo: studentId);
    }
    return query.snapshots().map((snap) =>
      snap.docs.map((d) => ParentAlert.fromFirestore(d)).toList(),
    );
  }

  /// Mark an alert as read
  Future<void> markAlertAsRead(String alertId) async {
    await _alertsCollection.doc(alertId).update({'isRead': true});
  }
}
