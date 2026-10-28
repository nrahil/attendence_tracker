import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/qr_session_model.dart';
import '../models/attendance_model.dart';
import 'attendance_service.dart';
import 'geofence_service.dart';

class QRClaimResult {
  final bool isSuccess;
  final String message;
  final String? courseName;

  const QRClaimResult({
    required this.isSuccess,
    required this.message,
    this.courseName,
  });
}

class QRAttendanceService {
  static final QRAttendanceService _instance = QRAttendanceService._internal();
  factory QRAttendanceService() => _instance;
  QRAttendanceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AttendanceService _attendanceService = AttendanceService();

  CollectionReference get _qrCollection => _firestore.collection('qr_sessions');

  /// Creates or updates a dynamic 60-second rotating QR session
  Future<QRSession> startOrRotateSession({
    required String sessionId,
    required String courseId,
    required String courseName,
    required String teacherId,
    required String teacherName,
    GeoCoordinates? location,
    double radiusMeters = 100.0,
    int durationSeconds = 60,
  }) async {
    final docRef = _qrCollection.doc(sessionId);
    final randomNonce = (100000 + Random().nextInt(900000)).toString();

    final now = DateTime.now();
    final expiresAt = now.add(Duration(seconds: durationSeconds));

    final session = QRSession(
      id: docRef.id,
      courseId: courseId,
      courseName: courseName,
      teacherId: teacherId,
      teacherName: teacherName,
      nonce: randomNonce,
      location: location ?? GeofenceService.defaultCampusLocation,
      radiusMeters: radiusMeters,
      createdAt: now,
      expiresAt: expiresAt,
      isActive: true,
    );

    await docRef.set(session.toMap(), SetOptions(merge: true));
    return session;
  }

  /// Real-time stream of the session so the teacher sees attendees pop up live
  Stream<QRSession?> streamSession(String sessionId) {
    return _qrCollection.doc(sessionId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return QRSession.fromFirestore(snap);
    });
  }

  /// Student claims attendance by submitting the scanned QR payload
  Future<QRClaimResult> claimAttendance({
    required String payload,
    required String studentId,
    required String studentName,
    GeoCoordinates? studentLocation,
  }) async {
    try {
      if (!payload.startsWith('ATTEND:')) {
        return const QRClaimResult(
          isSuccess: false,
          message: 'Invalid QR Code format. Please scan an authorized class attendance code.',
        );
      }

      final parts = payload.split(':');
      if (parts.length < 8) {
        return const QRClaimResult(
          isSuccess: false,
          message: 'Malformed attendance payload.',
        );
      }

      final sessionId = parts[1];
      final courseId = parts[2];
      final nonce = parts[3];
      final expiresAtMillis = int.tryParse(parts[4]) ?? 0;
      final centerLat = double.tryParse(parts[5]) ?? 0.0;
      final centerLon = double.tryParse(parts[6]) ?? 0.0;
      final radius = double.tryParse(parts[7]) ?? 100.0;

      // 1. Validate Expiration
      final nowMillis = DateTime.now().millisecondsSinceEpoch;
      if (nowMillis > expiresAtMillis) {
        return const QRClaimResult(
          isSuccess: false,
          message: 'QR Code has expired! Dynamic codes rotate every 60 seconds. Please scan the current code on screen.',
        );
      }

      // 2. Fetch Live Session from Firestore
      final sessionDoc = await _qrCollection.doc(sessionId).get();
      if (!sessionDoc.exists) {
        return const QRClaimResult(isSuccess: false, message: 'Class session not found or already closed.');
      }

      final session = QRSession.fromFirestore(sessionDoc);
      if (!session.isActive) {
        return const QRClaimResult(isSuccess: false, message: 'Attendance session has been closed by the teacher.');
      }

      if (session.nonce != nonce) {
        return const QRClaimResult(
          isSuccess: false,
          message: 'Stale token. The teacher screen has rotated to a new security token.',
        );
      }

      // 3. Geofence Validation
      if (studentLocation != null) {
        final geoValidation = GeofenceService.validateLocation(
          studentLocation: studentLocation,
          centerLocation: GeoCoordinates(latitude: centerLat, longitude: centerLon),
          radiusMeters: radius,
        );

        if (!geoValidation.isInside) {
          return QRClaimResult(
            isSuccess: false,
            message: geoValidation.message,
          );
        }
      }

      // 4. Duplicate Check
      if (session.attendeeIds.contains(studentId)) {
        return QRClaimResult(
          isSuccess: true,
          message: 'You have already verified attendance for this session!',
          courseName: session.courseName,
        );
      }

      // 5. Append Student to Session Attendees
      await _qrCollection.doc(sessionId).update({
        'attendeeIds': FieldValue.arrayUnion([studentId]),
        'attendeeNames': FieldValue.arrayUnion([studentName]),
      });

      // 6. Record in Core Attendance Collection with Audit Log
      final today = DateTime.now();
      final dateKey = '${today.year}_${today.month}_${today.day}';
      final recordId = '${courseId}_${studentId}_$dateKey';

      final record = AttendanceRecord(
        id: recordId,
        studentId: studentId,
        studentName: studentName,
        courseId: courseId,
        courseName: session.courseName,
        date: DateTime(today.year, today.month, today.day),
        status: AttendanceStatus.present,
        lateMinutes: 0,
        markedBy: 'dynamic_qr_system',
        markedByName: 'Dynamic QR & Geofence System',
        notes: 'Verified via 60s Dynamic QR token & GPS Geofence boundary',
        auditTrail: [
          AuditEntry(
            modifiedBy: studentId,
            modifiedByName: studentName,
            timestamp: today,
            previousStatus: AttendanceStatus.absent,
            newStatus: AttendanceStatus.present,
            reason: 'Self-service Dynamic QR + Geofence Verified Check-in',
          ),
        ],
        createdAt: today,
      );

      await _attendanceService.markAttendance(
        record: record,
        actorId: studentId,
        actorName: studentName,
        reason: 'Dynamic QR Check-in verified',
      );

      return QRClaimResult(
        isSuccess: true,
        message: 'Attendance successfully verified and logged!',
        courseName: session.courseName,
      );
    } catch (e) {
      return QRClaimResult(
        isSuccess: false,
        message: 'Verification failed: $e',
      );
    }
  }

  /// Deactivate session
  Future<void> endSession(String sessionId) async {
    await _qrCollection.doc(sessionId).update({'isActive': false});
  }
}

