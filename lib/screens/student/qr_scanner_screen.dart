import 'package:flutter/material.dart';
import '../../services/qr_attendance_service.dart';
import '../../services/geofence_service.dart';

class QRScannerScreen extends StatefulWidget {
  final String studentId;
  final String studentName;

  const QRScannerScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> with SingleTickerProviderStateMixin {
  final QRAttendanceService _qrService = QRAttendanceService();
  final TextEditingController _manualCodeController = TextEditingController();
  late AnimationController _laserController;
  bool _isVerifying = false;

  // Mock student GPS coordinates (inside campus perimeter)
  GeoCoordinates _studentLocation = GeofenceService.defaultCampusLocation;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserController.dispose();
    _manualCodeController.dispose();
    super.dispose();
  }

  Future<void> _processScan(String payload) async {
    setState(() => _isVerifying = true);

    final result = await _qrService.claimAttendance(
      payload: payload,
      studentId: widget.studentId,
      studentName: widget.studentName,
      studentLocation: _studentLocation,
    );

    if (mounted) {
      setState(() => _isVerifying = false);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                result.isSuccess ? Icons.check_circle : Icons.error_outline,
                color: result.isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                size: 28,
              ),
              const SizedBox(width: 10),
              Text(
                result.isSuccess ? 'Attendance Verified' : 'Check-in Rejected',
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(result.message, style: const TextStyle(fontSize: 14, height: 1.4)),
              if (result.isSuccess) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Signed: ${result.courseName ?? "Course Session"}\nAudit entry logged automatically.',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (result.isSuccess) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: result.isSuccess ? const Color(0xFF10B981) : const Color(0xFF6366F1),
              ),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  void _simulateInstantCheckin() {
    final today = DateTime.now();
    final sampleSessionId = 'QR_CS301_${today.year}_${today.month}_${today.day}_${today.hour}';
    final samplePayload = 'ATTEND:$sampleSessionId:CS301:sample_nonce:${DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch}:28.6139:77.2090:100.0';
    _processScan(samplePayload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Dynamic QR & GPS Check-in', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: Stack(
        children: [
          // Viewfinder background
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF6366F1), width: 2),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Stack(
                    children: [
                      // Animated scanning laser line
                      AnimatedBuilder(
                        animation: _laserController,
                        builder: (ctx, child) {
                          return Positioned(
                            top: _laserController.value * 240,
                            left: 10,
                            right: 10,
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: const Color(0xFF38BDF8),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.8),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const Center(
                        child: Icon(Icons.qr_code_scanner, size: 80, color: Colors.white24),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Align the on-screen QR code within the frame',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on, size: 14, color: Color(0xFF10B981)),
                  const SizedBox(width: 4),
                  Text(
                    'GPS Perimeter Geofence active (±100m)',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),

          // Bottom quick action controls
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.flash_on, color: Colors.white),
                    label: const Text('Simulate Scan Current Class Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _isVerifying ? null : _simulateInstantCheckin,
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Manual Payload Entry'),
                        content: TextField(
                          controller: _manualCodeController,
                          decoration: const InputDecoration(hintText: 'Paste ATTEND:... token'),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () {
                              final text = _manualCodeController.text.trim();
                              Navigator.pop(ctx);
                              if (text.isNotEmpty) _processScan(text);
                            },
                            child: const Text('Verify'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Enter Token Manually', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),

          if (_isVerifying)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF6366F1)),
                    SizedBox(height: 16),
                    Text('Verifying token & geofence...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
