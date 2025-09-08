import 'package:flutter/material.dart';
import 'package:attendence_manager/widgets/attendance_progress_bar.dart';

class CourseCard extends StatelessWidget {
  final String courseName;
  final int currentAttendance;
  final VoidCallback onAttended;
  final VoidCallback onMissed;
  final VoidCallback onDetails;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CourseCard({
    super.key,
    required this.courseName,
    required this.currentAttendance,
    required this.onAttended,
    required this.onMissed,
    required this.onDetails,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        title: Text(
          courseName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Attendance: $currentAttendance%'),
            const SizedBox(height: 4),
            AttendanceProgressBar(
              attendancePercentage: currentAttendance.toDouble(),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle, color: Colors.green),
              onPressed: onAttended,
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red),
              onPressed: onMissed,
            ),
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.blue),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: onDelete,
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: onDetails,
            ),
          ],
        ),
      ),
    );
  }
}