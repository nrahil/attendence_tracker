import 'package:cloud_firestore/cloud_firestore.dart';

enum AlertType {
  absence,
  tardy,
  thresholdWarning,
  leaveUpdate;

  String get displayName {
    switch (this) {
      case AlertType.absence:
        return 'Unexcused Absence';
      case AlertType.tardy:
        return 'Late Arrival';
      case AlertType.thresholdWarning:
        return 'Shortage Warning';
      case AlertType.leaveUpdate:
        return 'Leave Status Update';
    }
  }
}

class ParentAlert {
  final String id;
  final String parentId;
  final String studentId;
  final String studentName;
  final String title;
  final String message;
  final AlertType type;
  final DateTime timestamp;
  final bool isRead;
  final String channel; // push, sms, email

  ParentAlert({
    required this.id,
    required this.parentId,
    required this.studentId,
    required this.studentName,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
    this.channel = 'push',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'parentId': parentId,
    'studentId': studentId,
    'studentName': studentName,
    'title': title,
    'message': message,
    'type': type.name,
    'timestamp': Timestamp.fromDate(timestamp),
    'isRead': isRead,
    'channel': channel,
  };

  factory ParentAlert.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ParentAlert(
      id: doc.id,
      parentId: data['parentId'] ?? '',
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: AlertType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => AlertType.absence,
      ),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: data['isRead'] ?? false,
      channel: data['channel'] ?? 'push',
    );
  }

  ParentAlert copyWith({bool? isRead}) {
    return ParentAlert(
      id: id,
      parentId: parentId,
      studentId: studentId,
      studentName: studentName,
      title: title,
      message: message,
      type: type,
      timestamp: timestamp,
      isRead: isRead ?? this.isRead,
      channel: channel,
    );
  }
}
