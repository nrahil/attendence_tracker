import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/compliance_consent_model.dart';

class ComplianceService {
  static final ComplianceService _instance = ComplianceService._internal();
  factory ComplianceService() => _instance;
  ComplianceService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _consentCollection => _firestore.collection('compliance_consents');

  /// Record or update explicit consent (FERPA, GDPR, Biometrics)
  Future<void> recordConsent({
    required String userId,
    required String userEmail,
    required ConsentType consentType,
    required bool isAccepted,
  }) async {
    final docId = '${userId}_${consentType.name}';
    final record = ConsentRecord(
      id: docId,
      userId: userId,
      userEmail: userEmail,
      consentType: consentType,
      agreedAt: DateTime.now(),
      isAccepted: isAccepted,
      revokedAt: isAccepted ? null : DateTime.now(),
    );

    await _consentCollection.doc(docId).set(record.toMap(), SetOptions(merge: true));
  }

  /// Stream of user signed consents
  Stream<List<ConsentRecord>> streamUserConsents(String userId) {
    return _consentCollection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ConsentRecord.fromFirestore(d)).toList());
  }

  /// GDPR Article 15/20: Generates a complete data portability export archive
  Future<String> generateGDPRDataArchive(String userId) async {
    final userDoc = await _firestore.collection('users').doc(userId).get();
    final consents = await _consentCollection.where('userId', isEqualTo: userId).get();
    final studentRecords = await _firestore
        .collection('attendance_records')
        .where('studentId', isEqualTo: userId)
        .get();
    final leaveRequests = await _firestore
        .collection('leave_requests')
        .where('studentId', isEqualTo: userId)
        .get();

    final exportData = {
      'exportType': 'GDPR Article 20 Personal Data Portability Archive',
      'generatedAt': DateTime.now().toIso8601String(),
      'userId': userId,
      'userProfile': userDoc.data() ?? {},
      'consents': consents.docs.map((d) => d.data()).toList(),
      'attendanceRecords': studentRecords.docs.map((d) => d.data()).toList(),
      'leaveRequests': leaveRequests.docs.map((d) => d.data()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  /// GDPR Article 17: Right to Erasure / Account Data Purge
  Future<void> requestRightToErasure({
    required String userId,
    required String reason,
  }) async {
    final batch = _firestore.batch();

    // 1. Log erasure audit request before scrubbing
    final erasureLogRef = _firestore.collection('erasure_audit_logs').doc();
    batch.set(erasureLogRef, {
      'userId': userId,
      'requestedAt': Timestamp.now(),
      'reason': reason,
      'status': 'completed',
      'complianceClause': 'GDPR Article 17 (Right to Erasure)',
    });

    // 2. Anonymize user profile
    final userRef = _firestore.collection('users').doc(userId);
    batch.update(userRef, {
      'email': 'anonymized_${userId.substring(0, 5)}@erased.user',
      'displayName': 'Anonymized Student',
      'isErased': true,
      'erasedAt': Timestamp.now(),
    });

    await batch.commit();
  }
}
