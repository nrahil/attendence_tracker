import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/leave_request_model.dart';
import '../services/leave_service.dart';

class SubmitLeaveDialog extends StatefulWidget {
  final String studentId;
  final String studentName;
  final List<String> enrolledCourses;

  const SubmitLeaveDialog({
    super.key,
    required this.studentId,
    required this.studentName,
    this.enrolledCourses = const [
      'CS-301: Advanced Algorithms',
      'CS-302: Database Management',
      'CS-303: Operating Systems',
      'CS-304: Computer Networks',
    ],
  });

  @override
  State<SubmitLeaveDialog> createState() => _SubmitLeaveDialogState();
}

class _SubmitLeaveDialogState extends State<SubmitLeaveDialog> {
  final _formKey = GlobalKey<FormState>();
  final LeaveService _leaveService = LeaveService();
  final TextEditingController _reasonController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  String _selectedCourse = '';
  String _leaveType = 'Medical';
  bool _isSubmitting = false;

  final List<String> _leaveTypes = [
    'Medical',
    'Family Emergency',
    'Academic Event / Conference',
    'Sports / Extracurricular',
    'Personal',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.enrolledCourses.isNotEmpty) {
      _selectedCourse = widget.enrolledCourses.first;
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 60)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final req = LeaveRequest(
        id: '',
        studentId: widget.studentId,
        studentName: widget.studentName,
        courseId: _selectedCourse.split(':').first.trim(),
        courseName: _selectedCourse,
        startDate: _startDate,
        endDate: _endDate,
        reason: _reasonController.text.trim(),
        leaveType: _leaveType,
        status: LeaveStatus.pending,
        submittedAt: DateTime.now(),
      );

      await _leaveService.submitLeaveRequest(req);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Leave request submitted for teacher approval!'),
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
            content: Text('Failed to submit: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.note_alt_outlined, color: Color(0xFF6366F1)),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Apply for Student Leave', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('Approval updates attendance records', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Course selector
                DropdownButtonFormField<String>(
                  initialValue: _selectedCourse,
                  decoration: InputDecoration(
                    labelText: 'Course / Subject',
                    prefixIcon: const Icon(Icons.book_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: widget.enrolledCourses.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCourse = val);
                  },
                ),
                const SizedBox(height: 16),

                // Leave Type selector
                DropdownButtonFormField<String>(
                  initialValue: _leaveType,
                  decoration: InputDecoration(
                    labelText: 'Leave Category',
                    prefixIcon: const Icon(Icons.category_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _leaveTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _leaveType = val);
                  },
                ),
                const SizedBox(height: 16),

                // Date Range picker tile
                InkWell(
                  onTap: _pickDateRange,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.date_range, color: Color(0xFF6366F1)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Duration', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                              Text(
                                '${DateFormat('MMM dd, yyyy').format(_startDate)}  →  ${DateFormat('MMM dd, yyyy').format(_endDate)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_calendar, size: 20, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Reason input
                TextFormField(
                  controller: _reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Reason for Leave',
                    hintText: 'e.g. Prescribed bed rest due to seasonal viral fever',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().length < 5) {
                      return 'Please provide a clear reason (min 5 characters)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Submit Request', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
