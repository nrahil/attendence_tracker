import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/attendance_model.dart';
import '../../services/attendance_service.dart';
import '../../services/notification_alert_service.dart';

class MarkAttendanceScreen extends StatefulWidget {
  final String courseId;
  final String courseName;
  final List<Map<String, String>> enrolledStudents;

  const MarkAttendanceScreen({
    super.key,
    required this.courseId,
    required this.courseName,
    this.enrolledStudents = const [
      {'id': 'student_1', 'name': 'Aarav Sharma'},
      {'id': 'student_2', 'name': 'Aditi Rao'},
      {'id': 'student_3', 'name': 'Ananya Verma'},
      {'id': 'student_4', 'name': 'Devansh Patel'},
      {'id': 'student_5', 'name': 'Ishaan Gupta'},
      {'id': 'student_6', 'name': 'Kavya Nair'},
      {'id': 'student_7', 'name': 'Rohan Sen'},
      {'id': 'student_8', 'name': 'Sanya Kapoor'},
    ],
  });

  @override
  State<MarkAttendanceScreen> createState() => _MarkAttendanceScreenState();
}

class _MarkAttendanceScreenState extends State<MarkAttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  final AttendanceService _service = AttendanceService();
  final NotificationAlertService _alertService = NotificationAlertService();
  bool _isSaving = false;

  // Local state for the session
  final Map<String, AttendanceStatus> _statuses = {};
  final Map<String, int> _lateMinutes = {};
  final Map<String, AttendanceRecord?> _existingRecords = {};

  @override
  void initState() {
    super.initState();
    _initializeDefaults();
  }

  void _initializeDefaults() {
    for (final s in widget.enrolledStudents) {
      final sId = s['id'] ?? '';
      _statuses[sId] = AttendanceStatus.present;
      _lateMinutes[sId] = 0;
    }
  }

  void _markAll(AttendanceStatus status) {
    setState(() {
      for (final s in widget.enrolledStudents) {
        final sId = s['id'] ?? '';
        _statuses[sId] = status;
        if (status != AttendanceStatus.late) {
          _lateMinutes[sId] = 0;
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Marked all students as ${status.displayName}'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _setLateMinutes(String studentId, String studentName) async {
    int current = _lateMinutes[studentId] ?? 10;
    final controller = TextEditingController(text: current.toString());

    final minutes = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.access_time_rounded, color: Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            Text('Late Arrival: $studentName', style: const TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter how many minutes the student was late:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Minutes Late',
                suffixText: 'min',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text) ?? 5;
              Navigator.pop(ctx, val);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (minutes != null) {
      setState(() {
        _statuses[studentId] = AttendanceStatus.late;
        _lateMinutes[studentId] = minutes;
      });
    }
  }

  Future<void> _viewAuditTrail(AttendanceRecord record) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Text(
                    'Audit Trail — ${record.studentName}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (record.auditTrail.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No manual edit logs recorded yet.')),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: record.auditTrail.length,
                    separatorBuilder: (_, __) => const Divider(height: 16),
                    itemBuilder: (ctx, idx) {
                      final item = record.auditTrail[idx];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
                          child: Text('${idx + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(
                          '${item.previousStatus.displayName} → ${item.newStatus.displayName}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'By ${item.modifiedByName} on ${DateFormat('MMM dd, hh:mm a').format(item.timestamp)}\nReason: ${item.reason.isEmpty ? "No reason specified" : item.reason}',
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _commitSession() async {
    final user = FirebaseAuth.instance.currentUser;
    final actorId = user?.uid ?? 'teacher_demo';
    final actorName = user?.displayName ?? user?.email ?? 'Course Instructor';

    setState(() => _isSaving = true);

    try {
      final dateKey = '${_selectedDate.year}_${_selectedDate.month}_${_selectedDate.day}';

      for (final s in widget.enrolledStudents) {
        final sId = s['id'] ?? '';
        final sName = s['name'] ?? '';
        final docId = '${widget.courseId}_${sId}_$dateKey';
        final status = _statuses[sId] ?? AttendanceStatus.present;
        final minutes = _lateMinutes[sId] ?? 0;

        final existing = _existingRecords[sId];

        final record = AttendanceRecord(
          id: docId,
          studentId: sId,
          studentName: sName,
          courseId: widget.courseId,
          courseName: widget.courseName,
          date: DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
          status: status,
          lateMinutes: minutes,
          markedBy: actorId,
          markedByName: actorName,
          auditTrail: existing?.auditTrail ?? [],
          createdAt: existing?.createdAt ?? DateTime.now(),
        );

        await _service.markAttendance(
          record: record,
          actorId: actorId,
          actorName: actorName,
          reason: existing != null ? 'Teacher session update' : 'Class session attendance',
        );

        // Real-Time Automated Alert Dispatch (Phase 2)
        if (status == AttendanceStatus.absent) {
          await _alertService.triggerAbsenceAlert(
            studentId: sId,
            studentName: sName,
            courseName: widget.courseName,
            date: _selectedDate,
          );
        } else if (status == AttendanceStatus.late && minutes > 0) {
          await _alertService.triggerTardyAlert(
            studentId: sId,
            studentName: sName,
            courseName: widget.courseName,
            lateMinutes: minutes,
            date: _selectedDate,
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Attendance successfully logged with audit verification!'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int presentCount = _statuses.values.where((s) => s == AttendanceStatus.present).length;
    int lateCount = _statuses.values.where((s) => s == AttendanceStatus.late).length;
    int absentCount = _statuses.values.where((s) => s == AttendanceStatus.absent).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.courseName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Digital Roll Call & Verification',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Change Date',
            icon: const Icon(Icons.calendar_month_outlined),
            onPressed: _pickDate,
          ),
        ],
      ),
      body: StreamBuilder<List<AttendanceRecord>>(
        stream: _service.streamCourseDateRecords(widget.courseId, _selectedDate),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            for (final r in snapshot.data!) {
              _existingRecords[r.studentId] = r;
              // Only load if not modified in current session
              if (!_statuses.containsKey(r.studentId) || _statuses[r.studentId] == null) {
                _statuses[r.studentId] = r.status;
                _lateMinutes[r.studentId] = r.lateMinutes;
              }
            }
          }

          return Column(
            children: [
              // Date & Bulk Action Strip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: Colors.white,
                child: Row(
                  children: [
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.event_available, color: Color(0xFF6366F1), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              DateFormat('EEE, MMM dd').format(_selectedDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.done_all, size: 16),
                      label: const Text('All Present'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF10B981),
                        side: const BorderSide(color: Color(0xFF10B981)),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _markAll(AttendanceStatus.present),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('All Absent'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFEF4444),
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => _markAll(AttendanceStatus.absent),
                    ),
                  ],
                ),
              ),

              // Live Counter Metrics
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetric('Total', '${widget.enrolledStudents.length}', const Color(0xFF64748B)),
                    _buildMetric('Present', '$presentCount', const Color(0xFF10B981)),
                    _buildMetric('Late', '$lateCount', const Color(0xFFF59E0B)),
                    _buildMetric('Absent', '$absentCount', const Color(0xFFEF4444)),
                  ],
                ),
              ),

              // Student List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: widget.enrolledStudents.length,
                  itemBuilder: (ctx, idx) {
                    final student = widget.enrolledStudents[idx];
                    final sId = student['id'] ?? '';
                    final sName = student['name'] ?? '';
                    final currentStatus = _statuses[sId] ?? AttendanceStatus.present;
                    final lateMin = _lateMinutes[sId] ?? 0;
                    final existingRecord = _existingRecords[sId];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: _getStatusColor(currentStatus).withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: _getStatusColor(currentStatus).withValues(alpha: 0.15),
                              foregroundColor: _getStatusColor(currentStatus),
                              child: Text(
                                sName.isNotEmpty ? sName[0] : 'S',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    sName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        'ID: $sId',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                      ),
                                      if (currentStatus == AttendanceStatus.late && lateMin > 0) ...[
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => _setLateMinutes(sId, sName),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '+$lateMin min',
                                              style: const TextStyle(
                                                color: Color(0xFFD97706),
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      if (existingRecord != null && existingRecord.auditTrail.isNotEmpty) ...[
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: () => _viewAuditTrail(existingRecord),
                                          child: const Icon(Icons.history, size: 16, color: Color(0xFF6366F1)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // 3-State Toggle: Present, Late, Absent
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildStatusOption(
                                  studentId: sId,
                                  studentName: sName,
                                  status: AttendanceStatus.present,
                                  currentStatus: currentStatus,
                                  label: 'P',
                                  color: const Color(0xFF10B981),
                                ),
                                const SizedBox(width: 4),
                                _buildStatusOption(
                                  studentId: sId,
                                  studentName: sName,
                                  status: AttendanceStatus.late,
                                  currentStatus: currentStatus,
                                  label: 'L',
                                  color: const Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 4),
                                _buildStatusOption(
                                  studentId: sId,
                                  studentName: sName,
                                  status: AttendanceStatus.absent,
                                  currentStatus: currentStatus,
                                  label: 'A',
                                  color: const Color(0xFFEF4444),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Save Bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _commitSession,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save_rounded, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Save & Verify Attendance',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusOption({
    required String studentId,
    required String studentName,
    required AttendanceStatus status,
    required AttendanceStatus currentStatus,
    required String label,
    required Color color,
  }) {
    final isSelected = currentStatus == status;

    return GestureDetector(
      onTap: () {
        if (status == AttendanceStatus.late) {
          _setLateMinutes(studentId, studentName);
        } else {
          setState(() {
            _statuses[studentId] = status;
            _lateMinutes[studentId] = 0;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return const Color(0xFF10B981);
      case AttendanceStatus.late:
        return const Color(0xFFF59E0B);
      case AttendanceStatus.absent:
        return const Color(0xFFEF4444);
      case AttendanceStatus.excused:
        return const Color(0xFF0EA5E9);
    }
  }
}

