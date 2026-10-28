import 'package:cloud_firestore/cloud_firestore.dart';

enum ConsentType {
  ferpaEducationalPrivacy,
  gdprDataProcessing,
  biometricProcessingConsent,
  parentalConsentForMinor;

  String get title {
    switch (this) {
      case ConsentType.ferpaEducationalPrivacy:
        return 'FERPA Educational Records Privacy Notice';
      case ConsentType.gdprDataProcessing:
        return 'GDPR Data Processing & Storage Consent';
      case ConsentType.biometricProcessingConsent:
        return 'Biometric Template Processing & Encryption Consent';
      case ConsentType.parentalConsentForMinor:
        return 'Parental Authorization for Minor Attendance Tracking';
    }
  }

  String get summary {
    switch (this) {
      case ConsentType.ferpaEducationalPrivacy:
        return 'Grants authorized educational personnel access to attendance records while prohibiting unauthorized disclosure under federal FERPA regulations.';
      case ConsentType.gdprDataProcessing:
        return 'Authorizes the encrypted processing of attendance events, right to data access (Art. 15), and right to erasure (Art. 17).';
      case ConsentType.biometricProcessingConsent:
        return 'Consents to mathematical vector extraction for check-in. Raw biometric imagery is NEVER stored, and embeddings are AES-256 encrypted.';
      case ConsentType.parentalConsentForMinor:
        return 'Confirms legal guardian authorization for automated real-time SMS/push absence notifications and campus check-in monitoring.';
    }
  }
}

class ConsentRecord {
  final String id;
  final String userId;
  final String userEmail;
  final ConsentType consentType;
  final DateTime agreedAt;
  final String appVersion;
  final bool isAccepted;
  final DateTime? revokedAt;

  ConsentRecord({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.consentType,
    required this.agreedAt,
    this.appVersion = '1.0.0',
    this.isAccepted = true,
    this.revokedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'userEmail': userEmail,
    'consentType': consentType.name,
    'agreedAt': Timestamp.fromDate(agreedAt),
    'appVersion': appVersion,
    'isAccepted': isAccepted,
    'revokedAt': revokedAt != null ? Timestamp.fromDate(revokedAt!) : null,
  };

  factory ConsentRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ConsentRecord(
      id: doc.id,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      consentType: ConsentType.values.firstWhere(
        (e) => e.name == data['consentType'],
        orElse: () => ConsentType.ferpaEducationalPrivacy,
      ),
      agreedAt: (data['agreedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      appVersion: data['appVersion'] ?? '1.0.0',
      isAccepted: data['isAccepted'] ?? true,
      revokedAt: (data['revokedAt'] as Timestamp?)?.toDate(),
    );
  }
}

