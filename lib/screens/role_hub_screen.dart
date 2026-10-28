import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';
import '../services/attendance_service.dart';
import '../services/attendance_analytics_service.dart';
import '../widgets/shortage_alert_banner.dart';
import 'teacher/mark_attendance_screen.dart';

class RoleHubScreen extends StatefulWidget {
  const RoleHubScreen({super.key});

  @override
  State<RoleHubScreen> createState() => _RoleHubScreenState();
}

class _RoleHubScreenState extends State<RoleHubScreen> with SingleTickerProviderStateMixin {
  final AttendanceService _service = AttendanceService();
  UserRole _activeRole = UserRole.student;
  late TabController _tabController;

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

  // ================= 1. STUDENT PORTAL =================
  Widget _buildStudentPortal(User? user) {
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
          // Role header badge
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  child: const Icon(Icons.school, color: Color(0xFF6366F1)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? user?.email ?? 'Student Portal',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Enrolled in 5 active courses',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
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

          // Quick Action Cards
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Check-in (Phase 3 Ready)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.qr_code_scanner,
                        label: 'Scan Dynamic QR',
                        color: const Color(0xFF6366F1),
                        subtitle: 'Phase 3 Feature',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildActionTile(
                        icon: Icons.nfc,
                        label: 'RFID Smart Card',
                        color: const Color(0xFF0EA5E9),
                        subtitle: 'Phase 3 Feature',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Student Course Breakdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Course Attendance Standing',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
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

  // ================= 2. TEACHER PORTAL =================
  Widget _buildTeacherPortal(User? user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                child: const Icon(Icons.person_pin, color: Color(0xFF10B981)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? 'Teacher Dashboard',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      '3 Classes Scheduled Today',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Quick Roll Call Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.checklist_rounded, color: Colors.white, size: 28),
                    SizedBox(width: 8),
                    Text(
                      'Non-Disruptive Digital Roll Call',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Take attendance with 3-state toggle (Present / Late / Absent), bulk mark all, and automated audit logs.',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded, color: Color(0xFF6366F1)),
                  label: const Text(
                    'Start Roll Call for CS-301',
                    style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
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
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Pending Leave Requests (Workflow)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildLeaveRequestItem('Aarav Sharma', 'Medical Leave', 'Oct 28 - Oct 29', 'Fever & Doctor Consultation'),
          _buildLeaveRequestItem('Ananya Verma', 'Family Emergency', 'Oct 30', 'Attending sister\'s wedding'),
        ],
      ),
    );
  }

  // ================= 3. PARENT PORTAL =================
  Widget _buildParentPortal(User? user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                child: const Icon(Icons.family_restroom, color: Color(0xFFF59E0B)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Parent Safety & Transparency Portal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Linked Ward: Aarav Sharma (Grade 11-A)', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Real-time Today Status
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
                  child: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 32),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Today\'s Status: Present & On-Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF10B981))),
                      SizedBox(height: 4),
                      Text('Checked in at 08:42 AM via Campus Entrance', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Notification Alert Preference
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notifications_active, color: Color(0xFF6366F1), size: 20),
                    SizedBox(width: 8),
                    Text('Real-Time Instant Alert Channels', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildNotificationToggle('Push Notifications (Instant)', true),
                _buildNotificationToggle('SMS Alert on Unexcused Absence', true),
                _buildNotificationToggle('Weekly Email Summary Report', false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= 4. ADMINISTRATOR PORTAL =================
  Widget _buildAdminPortal(User? user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                child: const Icon(Icons.admin_panel_settings, color: Color(0xFFEF4444)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Campus Administrator Dashboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Auditing, Compliance & Institution Analytics', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // High level campus metrics
          Row(
            children: [
              Expanded(child: _buildStatCard('88.4%', 'Campus Attendance', const Color(0xFF10B981), Icons.bar_chart)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('42', 'At-Risk Students', const Color(0xFFEF4444), Icons.warning_amber)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('99.2%', 'Compliance Index', const Color(0xFF6366F1), Icons.verified)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('18', 'Audit Adjustments', const Color(0xFFF59E0B), Icons.history)),
            ],
          ),
          const SizedBox(height: 24),

          // Compliance & Reports
          const Text('Compliance & Audit Reports (FERPA / GDPR)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFEF4444)),
            title: const Text('Export Monthly Accreditation PDF'),
            subtitle: const Text('Includes classroom audit logs and attendance percentages'),
            trailing: const Icon(Icons.download),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Generating compliance report export...')),
              );
            },
          ),
        ],
      ),
    );
  }

  // Helper widgets
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

  Widget _buildLeaveRequestItem(String student, String type, String dates, String reason) {
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
                  child: Text(student, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(type, style: const TextStyle(color: Color(0xFF6366F1), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(dates, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 4),
            Text(reason, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Approve & Update', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationToggle(String label, bool value) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      activeColor: const Color(0xFF6366F1),
      onChanged: (val) {},
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
}

