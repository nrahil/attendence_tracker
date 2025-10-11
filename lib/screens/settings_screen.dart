import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendence_manager/screens/auth/login_screen.dart';
import 'package:attendence_manager/widgets/threshold_dialog.dart';
import 'package:attendence_manager/main.dart';
import 'package:share_plus/share_plus.dart';

class SettingsScreen extends StatelessWidget {
  
  const SettingsScreen({super.key});

  Future<void> _deleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.warning_outlined, color: Color(0xFFEF4444), size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Delete Account')),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action cannot be undone!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFEF4444),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'All your data including courses, attendance records, and settings will be permanently deleted.',
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          // Delete all courses and their subcollections
          final userCourses = FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .collection('courses');
          
          final batch = FirebaseFirestore.instance.batch();
          final snapshots = await userCourses.get();
          
          for (var doc in snapshots.docs) {
            // Delete attendance logs
            final attendanceLogs = await doc.reference.collection('attendance_log').get();
            for (var log in attendanceLogs.docs) {
              batch.delete(log.reference);
            }
            batch.delete(doc.reference);
          }
          await batch.commit();

          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .delete();

          await currentUser.delete();

          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (ctx) => LoginScreen()),
              (Route<dynamic> route) => false,
            );
          }
        }
      } on FirebaseAuthException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Error: ${e.message}')),
                ],
              ),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  Future<Map<String, dynamic>> _getUserStats() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return {'courses': 0, 'totalClasses': 0, 'avgAttendance': 0.0};
    }

    final coursesSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('courses')
        .get();

    int totalClasses = 0;
    double totalPercentage = 0;

    for (var doc in coursesSnapshot.docs) {
      final data = doc.data();
      totalClasses += (data['classesHeld'] as int? ?? 0);
      totalPercentage += double.parse(data['attendancePercentage'] as String? ?? '0');
    }

    return {
      'courses': coursesSnapshot.docs.length,
      'totalClasses': totalClasses,
      'avgAttendance': coursesSnapshot.docs.isNotEmpty 
          ? totalPercentage / coursesSnapshot.docs.length 
          : 0.0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Enhanced App Bar with Stats
          SliverAppBar(
            expandedHeight: 250,
            floating: false,
            pinned: true,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [const Color(0xFF0EA5E9), const Color(0xFF06B6D4)],
                ),
              ),
              child: FlexibleSpaceBar(
                title: const Text(
                  'Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                background: FutureBuilder<Map<String, dynamic>>(
                  future: _getUserStats(),
                  builder: (context, snapshot) {
                    final stats = snapshot.data ?? {'courses': 0, 'totalClasses': 0, 'avgAttendance': 0.0};
                    
                    return Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildQuickStat(
                                '${stats['courses']}',
                                'Courses',
                                Icons.book_outlined,
                              ),
                              _buildQuickStat(
                                '${stats['totalClasses']}',
                                'Total Classes',
                                Icons.school_outlined,
                              ),
                              _buildQuickStat(
                                '${(stats['avgAttendance'] as double).toStringAsFixed(1)}%',
                                'Avg. Attendance',
                                Icons.trending_up,
                              ),
                            ],
                          ),
                          const SizedBox(height: 60),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                const Color(0xFF1E293B),
                                const Color(0xFF334155),
                              ]
                            : [
                                const Color(0xFF0EA5E9).withOpacity(0.1),
                                const Color(0xFF06B6D4).withOpacity(0.05),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark 
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [const Color(0xFF38BDF8), const Color(0xFF22D3EE)]
                                  : [const Color(0xFF0EA5E9), const Color(0xFF06B6D4)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0EA5E9))
                                    .withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              currentUser?.email?.substring(0, 1).toUpperCase() ?? 'U',
                              style: TextStyle(
                                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Signed in as',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark 
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentUser?.email ?? 'No email',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Appearance Section
                  
                  // Preferences Section
                  _buildSectionHeader('PREFERENCES', isDark),
                  const SizedBox(height: 12),
                  
                  _buildSettingCard(
                    context,
                    icon: Icons.percent_outlined,
                    iconColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0EA5E9),
                    title: 'Attendance Threshold',
                    subtitle: 'Set your target attendance percentage',
                    isDark: isDark,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => const ThresholdDialog(),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  _buildSettingCard(
                    context,
                    icon: Icons.notifications_outlined,
                    iconColor: isDark ? const Color(0xFFA78BFA) : const Color(0xFF8B5CF6),
                    title: 'Notifications',
                    subtitle: 'Manage notification preferences',
                    isDark: isDark,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.white),
                              SizedBox(width: 12),
                              Text('Coming soon!'),
                            ],
                          ),
                          backgroundColor: isDark 
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF0EA5E9),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  
                  // Data & Privacy Section
                  _buildSectionHeader('DATA & PRIVACY', isDark),
                  const SizedBox(height: 12),
                  
                  _buildSettingCard(
                    context,
                    icon: Icons.download_outlined,
                    iconColor: const Color(0xFF10B981),
                    title: 'Export Data',
                    subtitle: 'Download your attendance data',
                    isDark: isDark,
                    onTap: () async {
                      // Simple export functionality
                      final currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser != null) {
                        final coursesSnapshot = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUser.uid)
                            .collection('courses')
                            .get();
                        
                        String data = 'Attendance Report\n\n';
                        for (var doc in coursesSnapshot.docs) {
                          final course = doc.data();
                          data += 'Course: ${course['courseName']}\n';
                          data += 'Instructor: ${course['instructorName']}\n';
                          data += 'Attendance: ${course['attendancePercentage']}%\n';
                          data += 'Classes Held: ${course['classesHeld']}\n';
                          data += 'Classes Missed: ${course['classesMissed']}\n\n';
                        }
                        
                        await Share.share(
                          data,
                          subject: 'My Attendance Report',
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  _buildSettingCard(
                    context,
                    icon: Icons.backup_outlined,
                    iconColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0EA5E9),
                    title: 'Backup & Sync',
                    subtitle: 'Your data is automatically backed up',
                    isDark: isDark,
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.cloud_done, size: 14, color: Color(0xFF10B981)),
                          SizedBox(width: 4),
                          Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // About Section
                  _buildSectionHeader('ABOUT', isDark),
                  const SizedBox(height: 12),
                  
                  _buildSettingCard(
                    context,
                    icon: Icons.info_outlined,
                    iconColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    title: 'About App',
                    subtitle: 'Version 2.0.0',
                    isDark: isDark,
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: 'Attendance Manager',
                        applicationVersion: '2.0.0',
                        applicationIcon: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [const Color(0xFF38BDF8), const Color(0xFF22D3EE)]
                                  : [const Color(0xFF0EA5E9), const Color(0xFF06B6D4)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.school_outlined,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                        children: [
                          const Text(
                            'A modern and elegant attendance tracking application built with Flutter.',
                            style: TextStyle(height: 1.5),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  _buildSettingCard(
                    context,
                    icon: Icons.star_outline,
                    iconColor: const Color(0xFFFBBF24),
                    title: 'Rate App',
                    subtitle: 'Share your feedback with us',
                    isDark: isDark,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(Icons.favorite, color: Colors.white),
                              SizedBox(width: 12),
                              Text('Thank you for your support!'),
                            ],
                          ),
                          backgroundColor: const Color(0xFFFBBF24),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  _buildSettingCard(
                    context,
                    icon: Icons.share_outlined,
                    iconColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0EA5E9),
                    title: 'Share App',
                    subtitle: 'Tell your friends about this app',
                    isDark: isDark,
                    onTap: () async {
                      await Share.share(
                        'Check out Attendance Manager - A modern app to track your attendance!\n\nDownload now!',
                        subject: 'Attendance Manager App',
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  
                  // Account Section
                  _buildSectionHeader('ACCOUNT', isDark),
                  const SizedBox(height: 12),
                  
                  _buildSettingCard(
                    context,
                    icon: Icons.logout_outlined,
                    iconColor: const Color(0xFFF59E0B),
                    title: 'Logout',
                    subtitle: 'Sign out of your account',
                    isDark: isDark,
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: const Text('Logout'),
                          content: const Text('Are you sure you want to logout?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Logout'),
                            ),
                          ],
                        ),
                      );
                      
                      if (confirm == true) {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (ctx) => LoginScreen(),
                            ),
                            (Route<dynamic> route) => false,
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  _buildSettingCard(
                    context,
                    icon: Icons.delete_forever_outlined,
                    iconColor: const Color(0xFFEF4444),
                    title: 'Delete Account',
                    subtitle: 'Permanently delete your account and data',
                    isDark: isDark,
                    onTap: () => _deleteAccount(context),
                    isDangerous: true,
                  ),
                  const SizedBox(height: 40),
                  
                  // App Footer
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [const Color(0xFF38BDF8), const Color(0xFF22D3EE)]
                                  : [const Color(0xFF0EA5E9), const Color(0xFF06B6D4)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: (isDark 
                                    ? const Color(0xFF38BDF8)
                                    : const Color(0xFF0EA5E9)).withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.school_outlined,
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Attendance Manager',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Version 2.0.0',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark 
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Made with ❤️ by Your Team',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark 
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isDark,
    VoidCallback? onTap,
    Widget? trailing,
    bool isDangerous = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDangerous 
              ? const Color(0xFFEF4444).withOpacity(0.3)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(isDark ? 0.2 : 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDangerous 
                              ? const Color(0xFFEF4444)
                              : (isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark 
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                trailing ?? Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDangerous 
                      ? const Color(0xFFEF4444)
                      : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}