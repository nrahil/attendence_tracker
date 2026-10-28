import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/qr_session_model.dart';
import '../../services/qr_attendance_service.dart';
import '../../services/geofence_service.dart';

class QRAttendanceBroadcastScreen extends StatefulWidget {
  final String courseId;
  final String courseName;
  final String teacherId;
  final String teacherName;

  const QRAttendanceBroadcastScreen({
    super.key,
    required this.courseId,
    required this.courseName,
    this.teacherId = 'teacher_demo',
    this.teacherName = 'Dr. S. K. Raman',
  });

  @override
  State<QRAttendanceBroadcastScreen> createState() => _QRAttendanceBroadcastScreenState();
}

class _QRAttendanceBroadcastScreenState extends State<QRAttendanceBroadcastScreen> {
  final QRAttendanceService _qrService = QRAttendanceService();
  late String _sessionId;
  QRSession? _currentSession;
  Timer? _rotationTimer;
  Timer? _countdownTicker;
  int _secondsLeft = 60;
  double _geofenceRadius = 100.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _sessionId = 'QR_${widget.courseId}_${today.year}_${today.month}_${today.day}_${today.hour}';
    _startSession();
  }

  Future<void> _startSession() async {
    final session = await _qrService.startOrRotateSession(
      sessionId: _sessionId,
      courseId: widget.courseId,
      courseName: widget.courseName,
      teacherId: widget.teacherId,
      teacherName: widget.teacherName,
      location: GeofenceService.defaultCampusLocation,
      radiusMeters: _geofenceRadius,
      durationSeconds: 60,
    );

    if (mounted) {
      setState(() {
        _currentSession = session;
        _secondsLeft = 60;
        _isLoading = false;
      });
      _startTimers();
    }
  }

  void _startTimers() {
    _rotationTimer?.cancel();
    _countdownTicker?.cancel();

    // 1-second countdown ticker for UI progress
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_secondsLeft > 0) {
          _secondsLeft--;
        }
      });
    });

    // 60-second periodic token rotation to prevent screenshot sharing & proxy attendance
    _rotationTimer = Timer.periodic(const Duration(seconds: 60), (t) async {
      if (!mounted) return;
      final session = await _qrService.startOrRotateSession(
        sessionId: _sessionId,
        courseId: widget.courseId,
        courseName: widget.courseName,
        teacherId: widget.teacherId,
        teacherName: widget.teacherName,
        location: GeofenceService.defaultCampusLocation,
        radiusMeters: _geofenceRadius,
        durationSeconds: 60,
      );
      if (mounted) {
        setState(() {
          _currentSession = session;
          _secondsLeft = 60;
        });
      }
    });
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _countdownTicker?.cancel();
    super.dispose();
  }

  Future<void> _finalizeSession() async {
    await _qrService.endSession(_sessionId);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance session finalized and closed.'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.courseName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const Text('Dynamic QR & Geofenced Broadcast', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Force Token Rotation',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _startSession,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : StreamBuilder<QRSession?>(
              stream: _qrService.streamSession(_sessionId),
              builder: (context, snapshot) {
                final session = snapshot.data ?? _currentSession;
                final attendees = session?.attendeeNames ?? [];

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Projected QR display card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Geofence status tag
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.gps_fixed, size: 14, color: Color(0xFF10B981)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'GPS Geofence: ${_geofenceRadius.toInt()}m Radius Active',
                                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // High-tech visual QR presentation widget
                            _buildVisualQRCode(session?.toPayloadString() ?? 'ATTEND:CS301'),

                            const SizedBox(height: 16),

                            // Dynamic Rotation Countdown
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.timer_outlined, size: 18, color: Color(0xFF6366F1)),
                                const SizedBox(width: 6),
                                Text(
                                  'Rotates in $_secondsLeft s',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF6366F1)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _secondsLeft / 60.0,
                                backgroundColor: const Color(0xFFE2E8F0),
                                color: _secondsLeft < 15 ? const Color(0xFFEF4444) : const Color(0xFF6366F1),
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Security Nonce: ${session?.nonce ?? "------"} • Anti-Proxy Enabled',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Geofence Radius Selector
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined, color: Color(0xFF38BDF8), size: 20),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Perimeter Geofence Radius',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            DropdownButton<double>(
                              value: _geofenceRadius,
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                              underline: const SizedBox(),
                              items: const [
                                DropdownMenuItem(value: 50.0, child: Text('50m (Room)')),
                                DropdownMenuItem(value: 100.0, child: Text('100m (Wing)')),
                                DropdownMenuItem(value: 200.0, child: Text('200m (Campus)')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _geofenceRadius = val);
                                  _startSession();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Real-time verified attendees stream
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.people_alt_outlined, color: Color(0xFF10B981), size: 20),
                                    const SizedBox(width: 8),
                                    const Text('Verified Attendees', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${attendees.length} Verified',
                                    style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            if (attendees.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text('Waiting for students to scan...', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                                ),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: attendees.length,
                                separatorBuilder: (_, __) => const Divider(color: Color(0xFF334155), height: 12),
                                itemBuilder: (ctx, idx) {
                                  final name = attendees[idx];
                                  return Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.2),
                                        child: Text('${idx + 1}', style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                                      ),
                                      const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 16),
                                      const SizedBox(width: 4),
                                      const Text('Verified', style: TextStyle(color: Color(0xFF10B981), fontSize: 11)),
                                    ],
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Finalize Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.done_all, color: Colors.white),
                          label: const Text('Close Session & Finalize Roll Call', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: _finalizeSession,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  /// Visual presentation widget representing the rotating dynamic matrix
  Widget _buildVisualQRCode(String payload) {
    return Container(
      width: 220,
      height: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6366F1), width: 3),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Corner anchors
          Positioned(top: 0, left: 0, child: _buildAnchorBox()),
          Positioned(top: 0, right: 0, child: _buildAnchorBox()),
          Positioned(bottom: 0, left: 0, child: _buildAnchorBox()),

          // Centered dynamic badge
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_2, size: 76, color: Color(0xFF0F172A)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('DYNAMIC TOKEN', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnchorBox() {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.black, width: 2),
      ),
      padding: const EdgeInsets.all(6),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(4),
        child: Container(color: Colors.black),
      ),
    );
  }
}
