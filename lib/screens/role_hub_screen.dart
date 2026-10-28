import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/attendance_model.dart';
import '../models/leave_request_model.dart';
import '../models/parent_alert_model.dart';
import '../services/attendance_service.dart';
import '../services/attendance_analytics_service.dart';
import '../services/leave_service.dart';
import '../services/notification_alert_service.dart';
import '../services/report_export_service.dart';
import '../services/predictive_analytics_service.dart';
import '../widgets/shortage_alert_banner.dart';
import '../widgets/submit_leave_dialog.dart';
import 'teacher/mark_attendance_screen.dart';
import 'teacher/leave_approval_screen.dart';
import 'teacher/qr_attendance_broadcast_screen.dart';
import 'student/qr_scanner_screen.dart';
import 'compliance/privacy_center_screen.dart';
import 'admin/integrations_screen.dart';

class RoleHubScreen extends StatefulWidget {
  const RoleHubScreen({super.key});

  @override
  State<RoleHubScreen> createState() => _RoleHubScreenState();
}

class _RoleHubScreenState extends State<RoleHubScreen> with SingleTickerProviderStateMixin {
  final AttendanceService _service = AttendanceService();
  final LeaveService _leaveService = LeaveService();
  final NotificationAlertService _alertService = NotificationAlertService();
  final ReportExportService _exportService = ReportExportService();

  UserRole _activeRole = UserRole.student;
  late TabController _tabController;

  // Parent portal state: multi-child switcher
  int _selectedChildIndex = 0;
  final List<Map<String, String>> _wards = [
    {'id': 'student_1', 'name': 'Aarav Sharma', 'grade': 'Grade 11-A', 'roll': '101'},
    {'id': 'student_3', 'name': 'Ananya Verma', 'grade': 'Grade 8-B', 'roll': '204'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUserRole();
  }

  void _loadUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()!.containsKey('role')) {
        final roleName = doc.data()!['role'] as String;
        final matchedRole = UserRole.values.firstWhere(
          (e) => e.name == roleName,
          orElse: () => UserRole.student,
        );
        setState(() {
          _activeRole = matchedRole;
          _tabController.index = matchedRole.index;
        });
      }
    }
  }

  void _switchRole(UserRole role) async {
    setState(() {
      _activeRole = role;
      _tabController.index = role.index;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _service.updateUserRole(user.uid, role);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched view to ${role.displayName} Portal'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _simulateNfcTap(String studentId, String studentName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.nfc, color: Color(0xFF0EA5E9), size: 28),
            SizedBox(width: 8),
            Text('RFID Smart Card Reader'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.credit_card, size: 64, color: Color(0xFF0EA5E9)),
            const SizedBox(height: 16),
            Text('Hold campus smart card against back of device for $studentName (ID: $studentId)...'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('ISO 14443-A • UID: 04:A2:3B:11:F9:5C', style: TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final today = DateTime.now();
              final record = AttendanceRecord(
                id: 'CS301_${studentId}_${today.year}_${today.month}_${today.day}',
                studentId: studentId,
                studentName: studentName,
                courseId: 'CS301',
                courseName: 'CS-301: Advanced Algorithms',
                date: DateTime(today.year, today.month, today.day),
                status: AttendanceStatus.present,
                markedBy: 'rfid_terminal_gate_1',
                markedByName: 'Campus Gate 1 RFID Terminal',
                notes: 'Card tap verified: UID 04:A2:3B:11:F9:5C',
                auditTrail: [
                  AuditEntry(
                    modifiedBy: 'rfid_terminal',
                    modifiedByName: 'RFID Reader Terminal',
                    timestamp: today,
                    previousStatus: AttendanceStatus.absent,
                    newStatus: AttendanceStatus.present,
                    reason: 'RFID Smart Card Hardware Tap',
                  ),
                ],
                createdAt: today,
              );
              await _service.markAttendance(
                record: record,
                actorId: studentId,
                actorName: studentName,
                reason: 'RFID Smart Card Check-in',
              );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('RFID Card Verified! Attendance recorded for CS-301.'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
            child: const Text('Simulate Card Tap', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Role Portals Hub',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) => _switchRole(UserRole.values[index]),
          isScrollable: false,
          labelColor: const Color(0xFF6366F1),
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: const Color(0xFF6366F1),
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.school_outlined, size: 20), text: 'Student'),
            Tab(icon: Icon(Icons.person_pin_outlined, size: 20), text: 'Teacher'),
            Tab(icon: Icon(Icons.family_restroom_outlined, size: 20), text: 'Parent'),
            Tab(icon: Icon(Icons.admin_panel_settings_outlined, size: 20), text: 'Admin'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildStudentPortal(user),
          _buildTeacherPortal(user),
          _buildParentPortal(user),
          _buildAdminPortal(user),
        ],
      ),
    );
  }

  // ================= 1. STUDENT PORTAL (PHASE 3 ENHANCED) =================
  Widget _buildStudentPortal(User? user) {
    final studentId = user?.uid ?? 'student_1';
    final studentName = user?.displayName ?? user?.email?.split('@').first ?? 'Aarav Sharma';

    final mockAnalysis = AttendanceAnalyticsService.calculateFromCounts(
      classesHeld: 24,
      classesMissed: 8,
      threshold: 75.0,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Student profile card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  child: const Icon(Icons.school, color: Color(0xFF6366F1), size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(studentName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      const Text('ID: CS-2024-101 • Computer Science', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.note_add_outlined, size: 16),
                  label: const Text('Apply Leave'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => SubmitLeaveDialog(
                        studentId: studentId,
                        studentName: studentName,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Shortage Alert Banner
          ShortageAlertBanner(
            analysis: mockAnalysis,
            onTapDetails: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Shortage Threshold Breakdown'),
                  content: Text(
                    'Total classes: ${mockAnalysis.totalClasses}\n'
                    'Attended: ${mockAnalysis.attendedClasses}\n'
                    'Current Percentage: ${mockAnalysis.percentage}%\n'
                    'Classes to reach 75%: ${mockAnalysis.classesNeededForThreshold}',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                  ],
                ),
              );
            },
          ),

          // Versatile Frictionless Check-In (Phase 3 Active)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.flash_on, color: Color(0xFF6366F1), size: 20),
                    SizedBox(width: 8),
                    Text('Frictionless Check-in (Phase 3 Active)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (ctx) => QRScannerScreen(
                                studentId: studentId,
                                studentName: studentName,
                              ),
                            ),
                          );
                        },
                        child: _buildActionTile(
                          icon: Icons.qr_code_scanner,
                          label: 'Scan Dynamic QR',
                          color: const Color(0xFF6366F1),
                          subtitle: 'With GPS Geofence (±100m)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _simulateNfcTap(studentId, studentName),
                        child: _buildActionTile(
                          icon: Icons.nfc,
                          label: 'RFID Smart Card',
                          color: const Color(0xFF0EA5E9),
                          subtitle: 'NFC Instant Tap Reader',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Student's Submitted Leave Requests Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('My Leave Requests (Live Status)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => SubmitLeaveDialog(
                        studentId: studentId,
                        studentName: studentName,
                      ),
                    );
                  },
                  child: const Text('+ New Request'),
                ),
              ],
            ),
          ),

          StreamBuilder<List<LeaveRequest>>(
            stream: _leaveService.streamStudentRequests(studentId),
            builder: (ctx, snapshot) {
              final requests = snapshot.data ?? [];
              if (requests.isEmpty) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Text('No leave applications submitted yet.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: requests.length,
                itemBuilder: (c, idx) {
                  final r = requests[idx];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      dense: true,
                      leading: _buildLeaveStatusIcon(r.status),
                      title: Text('${r.leaveType} — ${r.courseName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${DateFormat('MMM dd').format(r.startDate)} - ${DateFormat('MMM dd').format(r.endDate)}\nReason: ${r.reason}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getLeaveStatusColor(r.status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          r.status.displayName,
                          style: TextStyle(color: _getLeaveStatusColor(r.status), fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 16),

          // Course Breakdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Subject-Wise Attendance Standing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildCourseAttendanceItem('Data Structures & Algorithms', 88.0, 22, 25),
                _buildCourseAttendanceItem('Database Management Systems', 70.0, 14, 20),
                _buildCourseAttendanceItem('Operating Systems', 65.0, 13, 20),
                _buildCourseAttendanceItem('Computer Networks', 92.0, 23, 25),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= 2. TEACHER PORTAL (PHASE 3 ENHANCED) =================
  Widget _buildTeacherPortal(User? user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                child: const Icon(Icons.person_pin, color: Color(0xFF10B981), size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.displayName ?? 'Dr. S. K. Raman', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    const Text('Department of Computer Science • 3 Sections', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Dynamic QR Broadcast Launcher Card (Phase 3)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.qr_code_2, color: Color(0xFF38BDF8), size: 26),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Broadcast Dynamic QR Session', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Rotating 60s tokens + GPS geofencing perimeter', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.sensors, color: Colors.white),
                    label: const Text('Start Projector QR Display (CS-301)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => const QRAttendanceBroadcastScreen(
                            courseId: 'CS301',
                            courseName: 'CS-301: Advanced Algorithms',
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Digital Roll Call Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.checklist_rtl, color: Color(0xFF10B981), size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Manual 3-State Roll Call', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('Present / Late / Absent fast toggles with audit verification', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (ctx) => const MarkAttendanceScreen(
                          courseId: 'CS301',
                          courseName: 'CS-301: Advanced Algorithms',
                        ),
                      ),
                    );
                  },
                  child: const Text('Open', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Leave Requests Approval Queue Header with Live Badge
          StreamBuilder<List<LeaveRequest>>(
            stream: _leaveService.streamPendingRequests(),
            builder: (context, snapshot) {
              final pendingCount = snapshot.data?.length ?? 0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('Student Leave Requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          if (pendingCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$pendingCount PENDING',
                                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (ctx) => const LeaveApprovalScreen()),
                          );
                        },
                        child: const Text('View All Queue'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (pendingCount == 0)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Center(
                        child: Text('🎉 No pending leave requests to review.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: snapshot.data!.take(2).length,
                      itemBuilder: (ctx, idx) {
                        final req = snapshot.data![idx];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(req.studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(req.leaveType, style: const TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${DateFormat('MMM dd').format(req.startDate)} - ${DateFormat('MMM dd').format(req.endDate)} • ${req.courseName}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 4),
                                Text('"${req.reason}"', style: const TextStyle(fontSize: 13)),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => _leaveService.rejectLeaveRequest(
                                        request: req,
                                        reviewerId: user?.uid ?? 'teacher_1',
                                        reviewerName: user?.displayName ?? 'Instructor',
                                      ),
                                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
                                      child: const Text('Reject'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () => _leaveService.approveLeaveRequest(
                                        request: req,
                                        reviewerId: user?.uid ?? 'teacher_1',
                                        reviewerName: user?.displayName ?? 'Instructor',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text('Approve & Excuse', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ================= 3. PARENT PORTAL =================
  Widget _buildParentPortal(User? user) {
    final selectedWard = _wards[_selectedChildIndex];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Multi-Child Switcher Strip
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: List.generate(_wards.length, (idx) {
                final ward = _wards[idx];
                final isSelected = idx == _selectedChildIndex;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedChildIndex = idx),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        children: [
                          Text(
                            ward['name'] ?? '',
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            ward['grade'] ?? '',
                            style: TextStyle(
                              color: isSelected ? const Color(0xFF4338CA) : const Color(0xFF94A3B8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),

          // Daily Attendance Live Status Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${selectedWard['name']} — Present Today',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF10B981)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Verified for CS-301 at 08:35 AM • On-Time',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Real-Time Notification & Absence Alerts Feed
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.notifications_active, color: Color(0xFFEF4444), size: 20),
                  SizedBox(width: 8),
                  Text('Real-Time Absence & Tardy Feed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () => setState(() {}),
              ),
            ],
          ),
          const SizedBox(height: 8),

          StreamBuilder<List<ParentAlert>>(
            stream: _alertService.streamAlerts(studentId: selectedWard['id']),
            builder: (ctx, snapshot) {
              final alerts = snapshot.data ?? [];

              if (alerts.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Text('No urgent alerts. Attendance is smooth!', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: alerts.take(4).length,
                itemBuilder: (c, idx) {
                  final alert = alerts[idx];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: _getAlertColor(alert.type).withValues(alpha: 0.3)),
                    ),
                    child: ListTile(
                      leading: Icon(_getAlertIcon(alert.type), color: _getAlertColor(alert.type)),
                      title: Text(alert.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                        '${alert.message}\n${DateFormat('MMM dd, hh:mm a').format(alert.timestamp)} via ${alert.channel.toUpperCase()}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 20),

          // Instant Communication & Actions
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.call_outlined, size: 18),
                  label: const Text('Contact Teacher'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening instructor direct line...')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.note_add_outlined, size: 18),
                  label: const Text('Apply Leave'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => SubmitLeaveDialog(
                        studentId: selectedWard['id'] ?? 'student_1',
                        studentName: selectedWard['name'] ?? 'Ward',
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= 4. ADMINISTRATOR PORTAL (PHASE 3 ENHANCED) =================
  Widget _buildAdminPortal(User? user) {
    final sampleAtRiskStudents = PredictiveAnalyticsService.getSampleAtRiskCohort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                child: const Icon(Icons.admin_panel_settings, color: Color(0xFFEF4444), size: 26),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Campus Administrator Dashboard', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    Text('Auditing, Compliance, Predictive Intelligence & Analytics', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Campus-wide metrics
          Row(
            children: [
              Expanded(child: _buildStatCard('88.4%', 'Campus Attendance', const Color(0xFF10B981), Icons.bar_chart)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('3 Flagged', 'At-Risk Students', const Color(0xFFEF4444), Icons.warning_amber)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('99.2%', 'Compliance Index', const Color(0xFF6366F1), Icons.verified)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('18 Logs', 'Audit Adjustments', const Color(0xFFF59E0B), Icons.history)),
            ],
          ),
          const SizedBox(height: 24),

          // Automated Compliance Reports (Phase 3 Feature)
          const Text('Automated Compliance Reports (FERPA & Accreditation)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFEF4444), size: 32),
              title: const Text('Export Compliance Audit Report', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Generates structured audit logs, roster data & accreditation tables'),
              trailing: ElevatedButton.icon(
                icon: const Icon(Icons.share, size: 16, color: Colors.white),
                label: const Text('Export', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                onPressed: () async {
                  final sampleReport = AttendanceReportData(
                    institutionName: 'Apex University • Department of Computer Science',
                    courseName: 'CS-301: Advanced Algorithms',
                    academicTerm: 'Fall Semester 2026',
                    averagePercentage: 88.4,
                    totalClasses: 25,
                    studentStats: [
                      {'id': '101', 'name': 'Aarav Sharma', 'held': 25, 'attended': 22, 'percentage': 88.0, 'status': 'Good'},
                      {'id': '102', 'name': 'Aditi Rao', 'held': 25, 'attended': 24, 'percentage': 96.0, 'status': 'Excellent'},
                      {'id': '103', 'name': 'Devansh Patel', 'held': 25, 'attended': 15, 'percentage': 60.0, 'status': 'At-Risk'},
                      {'id': '104', 'name': 'Rohan Sen', 'held': 25, 'attended': 17, 'percentage': 68.0, 'status': 'Warning'},
                    ],
                    auditLogs: [
                      AuditEntry(
                        modifiedBy: 'Dr. Raman',
                        modifiedByName: 'Dr. S. K. Raman',
                        timestamp: DateTime.now().subtract(const Duration(days: 2)),
                        previousStatus: AttendanceStatus.absent,
                        newStatus: AttendanceStatus.excused,
                        reason: 'Approved Medical Certificate from Apex Hospital',
                      ),
                    ],
                  );

                  await _exportService.exportAndShareReport(sampleReport);
                },
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Enterprise Integrations & Compliance Center (Phase 4)
          const Text('Enterprise Integrations & Compliance Shield', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildIntegrationsCard(),
          const SizedBox(height: 24),

          // Predictive Early Warning System (Phase 3 Feature)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.psychology_outlined, color: Color(0xFF6366F1), size: 22),
                  SizedBox(width: 8),
                  Text('Predictive Early Warning Analytics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('ML Trajectory Model', style: TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sampleAtRiskStudents.length,
            itemBuilder: (ctx, idx) {
              final student = sampleAtRiskStudents[idx];
              final isCritical = student.riskTier == RiskTier.critical;
              final badgeColor = isCritical ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: badgeColor.withValues(alpha: 0.3), width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(student.studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                Text(student.courseName, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              student.riskTier.displayName,
                              style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text('Current: ${student.currentPercentage}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 12),
                          const Icon(Icons.trending_down, size: 16, color: Color(0xFFEF4444)),
                          const SizedBox(width: 4),
                          Text('Projected: ${student.projectedPercentage}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: badgeColor)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(student.recommendedAction, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.support_agent, size: 16),
                          label: const Text('Deploy Support Counselor'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6366F1),
                            side: const BorderSide(color: Color(0xFF6366F1)),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Counselor dispatched for ${student.studentName}. Intervention logged.'),
                                backgroundColor: const Color(0xFF6366F1),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ================= ENTERPRISE INTEGRATIONS & COMPLIANCE (PHASE 4) =================
  Widget _buildIntegrationsCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.hub_outlined, color: Color(0xFF6366F1), size: 28),
            title: const Text('LMS & SIS/ERP Connectors Hub', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Google Classroom, Canvas LMS, PowerSchool mutual TLS webhooks'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const IntegrationsScreen()),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF10B981), size: 28),
            title: const Text('Privacy, FERPA & Biometric Enclave', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Consent audit logs, AES-256 vector encryption & GDPR Art. 17/20 tools'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const PrivacyCenterScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  // ================= HELPERS =================
  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildCourseAttendanceItem(String name, double percentage, int attended, int total) {
    final isLow = percentage < 75.0;
    final color = isLow ? const Color(0xFFEF4444) : const Color(0xFF10B981);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('$attended of $total classes attended', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${percentage.toStringAsFixed(1)}%',
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const Spacer(),
              Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Icon _buildLeaveStatusIcon(LeaveStatus status) {
    switch (status) {
      case LeaveStatus.pending:
        return const Icon(Icons.hourglass_top, color: Color(0xFFF59E0B), size: 20);
      case LeaveStatus.approved:
        return const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20);
      case LeaveStatus.rejected:
        return const Icon(Icons.cancel, color: Color(0xFFEF4444), size: 20);
    }
  }

  Color _getLeaveStatusColor(LeaveStatus status) {
    switch (status) {
      case LeaveStatus.pending:
        return const Color(0xFFF59E0B);
      case LeaveStatus.approved:
        return const Color(0xFF10B981);
      case LeaveStatus.rejected:
        return const Color(0xFFEF4444);
    }
  }

  IconData _getAlertIcon(AlertType type) {
    switch (type) {
      case AlertType.absence:
        return Icons.warning_amber_rounded;
      case AlertType.tardy:
        return Icons.access_time_rounded;
      case AlertType.thresholdWarning:
        return Icons.trending_down_rounded;
      case AlertType.leaveUpdate:
        return Icons.info_outline;
    }
  }

  Color _getAlertColor(AlertType type) {
    switch (type) {
      case AlertType.absence:
        return const Color(0xFFEF4444);
      case AlertType.tardy:
        return const Color(0xFFF59E0B);
      case AlertType.thresholdWarning:
        return const Color(0xFFDC2626);
      case AlertType.leaveUpdate:
        return const Color(0xFF6366F1);
    }
  }
}
