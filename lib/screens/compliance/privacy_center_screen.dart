import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/compliance_consent_model.dart';
import '../../services/compliance_service.dart';
import '../../services/biometric_security_service.dart';

class PrivacyCenterScreen extends StatefulWidget {
  const PrivacyCenterScreen({super.key});

  @override
  State<PrivacyCenterScreen> createState() => _PrivacyCenterScreenState();
}

class _PrivacyCenterScreenState extends State<PrivacyCenterScreen> {
  final ComplianceService _complianceService = ComplianceService();
  final BiometricSecurityService _biometricService = BiometricSecurityService();

  final Map<ConsentType, bool> _localConsents = {
    ConsentType.ferpaEducationalPrivacy: true,
    ConsentType.gdprDataProcessing: true,
    ConsentType.biometricProcessingConsent: true,
    ConsentType.parentalConsentForMinor: true,
  };

  bool _isExporting = false;

  Future<void> _toggleConsent(ConsentType type, bool val) async {
    setState(() => _localConsents[type] = val);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _complianceService.recordConsent(
        userId: user.uid,
        userEmail: user.email ?? '',
        consentType: type,
        isAccepted: val,
      );
    }
  }

  Future<void> _exportDataArchive() async {
    setState(() => _isExporting = true);
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'student_1';

    try {
      final jsonArchive = await _complianceService.generateGDPRDataArchive(uid);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.inventory_2_outlined, color: Color(0xFF10B981)),
                SizedBox(width: 8),
                Text('GDPR Data Archive', style: TextStyle(fontSize: 18)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Text(
                  jsonArchive,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
              ElevatedButton.icon(
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Share JSON Archive'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                onPressed: () {
                  Navigator.pop(ctx);
                  Share.share(jsonArchive, subject: 'GDPR Personal Data Portability Archive');
                },
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _requestErasure() async {
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('GDPR Right to Erasure'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Under GDPR Article 17, requesting erasure will anonymize your personal identifiers while preserving regulatory audit hashes.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for Request',
                hintText: 'e.g. Graduated / Institution transfer',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Submit Erasure Request', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await _complianceService.requestRightToErasure(
          userId: user.uid,
          reason: reasonController.text.trim().isEmpty ? 'User requested erasure' : reasonController.text.trim(),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erasure request logged. Personal data anonymized.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Privacy, FERPA & Compliance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Regulatory Badge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.gavel_rounded, color: Color(0xFF38BDF8), size: 32),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('FERPA & GDPR Compliance Shield', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                        SizedBox(height: 4),
                        Text(
                          'Your educational attendance data is strictly safeguarded under federal privacy guidelines & European data rights.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Consent Management Section
            const Text('Mandatory & Explicit Consents', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            ...ConsentType.values.map((type) {
              final isAgreed = _localConsents[type] ?? true;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isAgreed ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: isAgreed ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(type.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                          Switch(
                            value: isAgreed,
                            activeColor: const Color(0xFF6366F1),
                            onChanged: (val) => _toggleConsent(type, val),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(type.summary, style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.3)),
                    ],
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),

            // Biometric Encryption Enclave Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.fingerprint, color: Color(0xFF6366F1), size: 24),
                      SizedBox(width: 10),
                      Text('Biometric Security Enclave', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Zero Raw Image Guarantee: Raw photos are never stored in databases.\n'
                    '• Irreversible Hash: Facial features converted to 128-dimensional AES-256 salted vectors.\n'
                    '• Encryption at Rest: Enclave vectors encrypted with institutional KMS keys.',
                    style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.security, size: 16),
                    label: const Text('Verify Biometric Integrity'),
                    style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: () async {
                      final result = await _biometricService.verifyBiometricCheckin(studentId: 'student_1');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result.message),
                            backgroundColor: result.isMatch ? const Color(0xFF10B981) : const Color(0xFF6366F1),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Data Rights Section (GDPR Art. 15, 17, 20)
            const Text('Your Data Rights (GDPR / FERPA)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.download_for_offline_outlined, color: Color(0xFF10B981)),
                    title: const Text('Download Personal Data Archive'),
                    subtitle: const Text('GDPR Article 20: Complete export of attendance & consents'),
                    trailing: _isExporting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: _isExporting ? null : _exportDataArchive,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFEF4444)),
                    title: const Text('Request Account Erasure', style: TextStyle(color: Color(0xFFEF4444))),
                    subtitle: const Text('GDPR Article 17: Right to be forgotten (Anonymizes identity)'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: _requestErasure,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

