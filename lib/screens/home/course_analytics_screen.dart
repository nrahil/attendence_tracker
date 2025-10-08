import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class CourseAnalyticsScreen extends StatefulWidget {
  final String courseId;
  final String courseName;

  const CourseAnalyticsScreen({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<CourseAnalyticsScreen> createState() => _CourseAnalyticsScreenState();
}

class _CourseAnalyticsScreenState extends State<CourseAnalyticsScreen> with SingleTickerProviderStateMixin {
  final firestore = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
    }
    _showUpdateAttendanceDialog(selectedDay);
  }

  Future<void> _showUpdateAttendanceDialog(DateTime date) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark 
                      ? [const Color(0xFF38BDF8), const Color(0xFF22D3EE)]
                      : [const Color(0xFF0EA5E9), const Color(0xFF06B6D4)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.calendar_today, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mark Attendance', style: TextStyle(fontSize: 18)),
                  Text(
                    DateFormat('MMM dd, yyyy').format(date),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusButton(
              ctx,
              'Present',
              Icons.check_circle_outline,
              const Color(0xFF10B981),
              'attended',
            ),
            const SizedBox(height: 12),
            _buildStatusButton(
              ctx,
              'Absent',
              Icons.cancel_outlined,
              const Color(0xFFEF4444),
              'missed',
            ),
            const SizedBox(height: 12),
            _buildStatusButton(
              ctx,
              'Holiday',
              Icons.beach_access_outlined,
              const Color(0xFFF59E0B),
              'holiday',
            ),
            const SizedBox(height: 12),
            _buildStatusButton(
              ctx,
              'Class Cancelled',
              Icons.event_busy_outlined,
              const Color(0xFF64748B),
              'cancelled',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null) {
      if (result == 'attended' || result == 'missed') {
        _showNumberInputDialog(date, result);
      } else {
        await _updateAttendanceLog(date, result, 0);
      }
    }
  }

  Widget _buildStatusButton(
    BuildContext ctx,
    String label,
    IconData icon,
    Color color,
    String status,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: () => Navigator.of(ctx).pop(status),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  final TextEditingController _preDefined = TextEditingController(text: "1");
  
  Future<void> _showNumberInputDialog(DateTime date, String status) async {
    int count = 1;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Number of classes $status'),
        content: TextField(
          keyboardType: TextInputType.number,
          controller: _preDefined,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Enter number of classes',
            prefixIcon: Icon(Icons.numbers),
          ),
          onChanged: (value) {
            count = int.tryParse(value) ?? 1;
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _updateAttendanceLog(date, status, count);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateAttendanceLog(DateTime date, String status, int count) async {
    final docId = DateFormat('yyyy-MM-dd').format(date);
    final docRef = firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('courses')
        .doc(widget.courseId)
        .collection('attendance_log')
        .doc(docId);

    try {
      await docRef.set({
        'date': date,
        'status': status,
        'count': count,
      });

      await _recalculateAttendance(currentUser!.uid, widget.courseId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Attendance updated to $status'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Failed to update attendance'),
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

  Future<void> _recalculateAttendance(String userId, String courseId) async {
    final courseDocRef =
        firestore.collection('users').doc(userId).collection('courses').doc(courseId);
    final attendanceLogSnapshot =
        await courseDocRef.collection('attendance_log').get();

    int classesHeld = 0;
    int classesMissed = 0;

    for (var doc in attendanceLogSnapshot.docs) {
      final status = doc.data()['status'] as String;
      final count = doc.data()['count'] as int? ?? 1;

      if (status != 'holiday' && status != 'cancelled') {
        classesHeld += count;
        if (status == 'missed') {
          classesMissed += count;
        }
      }
    }

    final attendancePercentage = (classesHeld > 0)
        ? ((classesHeld - classesMissed) / classesHeld) * 100
        : 0.0;

    await courseDocRef.update({
      'classesHeld': classesHeld,
      'classesMissed': classesMissed,
      'attendancePercentage': attendancePercentage.toStringAsFixed(2),
    });
  }

  Color _getMarkerColor(String status) {
    switch (status) {
      case 'attended':
        return const Color(0xFF10B981);
      case 'missed':
        return const Color(0xFFEF4444);
      case 'holiday':
        return const Color(0xFFF59E0B);
      case 'cancelled':
        return const Color(0xFF64748B);
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: firestore
            .collection('users')
            .doc(currentUser!.uid)
            .collection('courses')
            .doc(widget.courseId)
            .snapshots(),
        builder: (context, courseSnapshot) {
          if (courseSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!courseSnapshot.hasData || !courseSnapshot.data!.exists) {
            return const Center(child: Text('Course data not found.'));
          }

          final courseData = courseSnapshot.data!.data() as Map<String, dynamic>;
          final attendancePercentage =
              double.tryParse(courseData['attendancePercentage'] as String? ?? '0') ?? 0;
          final classesHeld = courseData['classesHeld'] as int? ?? 0;
          final classesMissed = courseData['classesMissed'] as int? ?? 0;
          final classesAttended = classesHeld - classesMissed;
          final instructorName = courseData['instructorName'] as String? ?? 'N/A';

          const double threshold = 75;
          double classesToAttend = 0;
          double classesToMiss = 0;

          if (attendancePercentage < threshold) {
            classesToAttend =
                (threshold * classesHeld - attendancePercentage * classesHeld) /
                    (100 - threshold);
          } else {
            classesToMiss =
                (100 * (classesHeld - classesMissed) - threshold * classesHeld) /
                    threshold;
          }

          return CustomScrollView(
            slivers: [
              // Enhanced App Bar with gradient
              SliverAppBar(
                expandedHeight: 200,
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
                    title: Text(
                      widget.courseName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                              : [const Color(0xFF0EA5E9), const Color(0xFF06B6D4)],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_outline, color: Colors.white70, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  instructorName,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 60),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              // Content
              StreamBuilder<QuerySnapshot>(
                stream: firestore
                    .collection('users')
                    .doc(currentUser!.uid)
                    .collection('courses')
                    .doc(widget.courseId)
                    .collection('attendance_log')
                    .snapshots(),
                builder: (context, attendanceSnapshot) {
                  if (attendanceSnapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  Map<String, String> attendanceHistory = {};
                  Map<String, int> attendanceCountHistory = {};
                  if (attendanceSnapshot.hasData) {
                    for (var doc in attendanceSnapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final date = (data['date'] as Timestamp).toDate();
                      final key = DateFormat('yyyy-MM-dd').format(date);
                      attendanceHistory[key] = data['status'] as String;
                      attendanceCountHistory[key] = data['count'] as int? ?? 1;
                    }
                  }

                  return SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // Stats Cards
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  'Attendance',
                                  '${attendancePercentage.toStringAsFixed(1)}%',
                                  Icons.pie_chart_outline,
                                  attendancePercentage >= 75 
                                      ? const Color(0xFF10B981) 
                                      : const Color(0xFFEF4444),
                                  isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  'Present',
                                  '$classesAttended',
                                  Icons.check_circle_outline,
                                  const Color(0xFF10B981),
                                  isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  'Absent',
                                  '$classesMissed',
                                  Icons.cancel_outlined,
                                  const Color(0xFFEF4444),
                                  isDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Prediction Card
                        if (classesHeld > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: attendancePercentage < threshold
                                      ? [
                                          const Color(0xFFEF4444).withOpacity(0.1),
                                          const Color(0xFFF87171).withOpacity(0.05),
                                        ]
                                      : [
                                          const Color(0xFF10B981).withOpacity(0.1),
                                          const Color(0xFF34D399).withOpacity(0.05),
                                        ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: attendancePercentage < threshold
                                      ? const Color(0xFFEF4444).withOpacity(0.3)
                                      : const Color(0xFF10B981).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: attendancePercentage < threshold
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      attendancePercentage < threshold
                                          ? Icons.trending_up
                                          : Icons.info_outline,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          attendancePercentage < threshold
                                              ? 'Need More Classes'
                                              : 'Great Progress!',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          attendancePercentage < threshold
                                              ? 'Attend ${classesToAttend.ceil()} more classes to reach ${threshold.toInt()}%'
                                              : 'You can miss ${classesToMiss.floor()} classes and stay above ${threshold.toInt()}%',
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
                                ],
                              ),
                            ),
                          ),
                        
                        // Tab Bar
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [const Color(0xFF38BDF8), const Color(0xFF22D3EE)]
                                    : [const Color(0xFF0EA5E9), const Color(0xFF06B6D4)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            indicatorPadding: const EdgeInsets.all(4),
                            labelColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            unselectedLabelColor: isDark 
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                            tabs: const [
                              Tab(text: 'Calendar'),
                              Tab(text: 'Stats'),
                              Tab(text: 'History'),
                            ],
                          ),
                        ),
                        
                        // Tab Content
                        SizedBox(
                          height: 600,
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              // Calendar Tab
                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isDark 
                                          ? const Color(0xFF334155)
                                          : const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: TableCalendar(
                                    firstDay: DateTime.utc(2020, 1, 1),
                                    lastDay: DateTime.now(),
                                    focusedDay: _focusedDay,
                                    calendarFormat: _calendarFormat,
                                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                                    onDaySelected: _onDaySelected,
                                    onFormatChanged: (format) {
                                      setState(() {
                                        _calendarFormat = format;
                                      });
                                    },
                                    onPageChanged: (focusedDay) {
                                      _focusedDay = focusedDay;
                                    },
                                    calendarStyle: CalendarStyle(
                                      outsideDaysVisible: false,
                                      weekendTextStyle: TextStyle(
                                        color: isDark 
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF64748B),
                                      ),
                                      defaultTextStyle: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      todayDecoration: BoxDecoration(
                                        color: isDark 
                                            ? const Color(0xFF38BDF8).withOpacity(0.3)
                                            : const Color(0xFF0EA5E9).withOpacity(0.3),
                                        shape: BoxShape.circle,
                                      ),
                                      selectedDecoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: isDark
                                              ? [const Color(0xFF38BDF8), const Color(0xFF22D3EE)]
                                              : [const Color(0xFF0EA5E9), const Color(0xFF06B6D4)],
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    headerStyle: HeaderStyle(
                                      formatButtonVisible: false,
                                      titleCentered: true,
                                      titleTextStyle: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      leftChevronIcon: Icon(
                                        Icons.chevron_left,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      rightChevronIcon: Icon(
                                        Icons.chevron_right,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    calendarBuilders: CalendarBuilders(
                                      defaultBuilder: (context, day, focusedDay) {
                                        final key = DateFormat('yyyy-MM-dd').format(day);
                                        final status = attendanceHistory[key];

                                        if (status != null) {
                                          return Container(
                                            margin: const EdgeInsets.all(4.0),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: _getMarkerColor(status),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              '${day.day}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          );
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              
                              // Stats Tab
                              SingleChildScrollView(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    _buildDetailCard(
                                      'Total Classes',
                                      '$classesHeld',
                                      Icons.school_outlined,
                                      isDark ? const Color(0xFF38BDF8) : const Color(0xFF0EA5E9),
                                      isDark,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildDetailCard(
                                      'Classes Attended',
                                      '$classesAttended',
                                      Icons.check_circle_outline,
                                      const Color(0xFF10B981),
                                      isDark,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildDetailCard(
                                      'Classes Missed',
                                      '$classesMissed',
                                      Icons.cancel_outlined,
                                      const Color(0xFFEF4444),
                                      isDark,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildDetailCard(
                                      'Success Rate',
                                      '${((classesAttended / (classesHeld > 0 ? classesHeld : 1)) * 100).toStringAsFixed(1)}%',
                                      Icons.trending_up,
                                      const Color(0xFF8B5CF6),
                                      isDark,
                                    ),
                                  ],
                                ),
                              ),
                              
                              // History Tab
                              ListView.builder(
                                padding: const EdgeInsets.all(20),
                                itemCount: attendanceHistory.length,
                                itemBuilder: (context, index) {
                                  final entries = attendanceHistory.entries.toList()
                                    ..sort((a, b) => b.key.compareTo(a.key));
                                  
                                  if (index >= entries.length) return const SizedBox();
                                  
                                  final entry = entries[index];
                                  final date = DateFormat('yyyy-MM-dd').parse(entry.key);
                                  final status = entry.value;
                                  final count = attendanceCountHistory[entry.key] ?? 1;
                                  
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: _getMarkerColor(status).withOpacity(0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: _getMarkerColor(status),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            _getStatusIcon(status),
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                DateFormat('MMM dd, yyyy').format(date),
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                status == 'attended' || status == 'missed'
                                                    ? '$count ${count > 1 ? 'classes' : 'class'} $status'
                                                    : status.toUpperCase(),
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
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getMarkerColor(status).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _getStatusLabel(status),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: _getMarkerColor(status),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'attended':
        return Icons.check_circle;
      case 'missed':
        return Icons.cancel;
      case 'holiday':
        return Icons.beach_access;
      case 'cancelled':
        return Icons.event_busy;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'attended':
        return 'PRESENT';
      case 'missed':
        return 'ABSENT';
      case 'holiday':
        return 'HOLIDAY';
      case 'cancelled':
        return 'CANCELLED';
      default:
        return 'UNKNOWN';
    }
  }
}