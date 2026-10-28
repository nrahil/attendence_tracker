import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/geofence_service.dart';

class QRSession {
  final String id;
  final String courseId;
  final String courseName;
  final String teacherId;
  final String teacherName;
  final String nonce;
  final GeoCoordinates location;
  final double radiusMeters;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isActive;
  final List<String> attendeeIds;
  final List<String> attendeeNames;

  QRSession({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.teacherId,
    required this.teacherName,
    required this.nonce,
    required this.location,
    this.radiusMeters = 100.0,
    required this.createdAt,
    required this.expiresAt,
    this.isActive = true,
    this.attendeeIds = const [],
    this.attendeeNames = const [],
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  int get remainingSeconds {
    final diff = expiresAt.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'courseId': courseId,
    'courseName': courseName,
    'teacherId': teacherId,
    'teacherName': teacherName,
    'nonce': nonce,
    'location': location.toMap(),
    'radiusMeters': radiusMeters,
    'createdAt': Timestamp.fromDate(createdAt),
    'expiresAt': Timestamp.fromDate(expiresAt),
    'isActive': isActive,
    'attendeeIds': attendeeIds,
    'attendeeNames': attendeeNames,
  };

  factory QRSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return QRSession(
      id: doc.id,
      courseId: data['courseId'] ?? '',
      courseName: data['courseName'] ?? '',
      teacherId: data['teacherId'] ?? '',
      teacherName: data['teacherName'] ?? '',
      nonce: data['nonce'] ?? '',
      location: GeoCoordinates.fromMap(data['location'] ?? {}),
      radiusMeters: (data['radiusMeters'] as num?)?.toDouble() ?? 100.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate() ?? DateTime.now().add(const Duration(seconds: 60)),
      isActive: data['isActive'] ?? true,
      attendeeIds: List<String>.from(data['attendeeIds'] ?? []),
      attendeeNames: List<String>.from(data['attendeeNames'] ?? []),
    );
  }

  /// Generates the compact payload string to encode inside the dynamic QR code
  String toPayloadString() {
    return 'ATTEND:$id:$courseId:$nonce:${expiresAt.millisecondsSinceEpoch}:${location.latitude}:${location.longitude}:$radiusMeters';
  }
}
