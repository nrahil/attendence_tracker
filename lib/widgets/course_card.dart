import 'package:flutter/material.dart';
import 'package:attendence_manager/widgets/attendance_progress_bar.dart';

class CourseCard extends StatelessWidget {
  final String courseName;
  final int currentAttendance;
  final int totalClasses;
  final VoidCallback onTap;

  CourseCard({
    required this.courseName,
    required this.currentAttendance,
    required this.totalClasses,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(courseName, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text('Attendance: $currentAttendance%'),
            SizedBox(height: 4),
            AttendanceProgressBar(
              attendancePercentage: currentAttendance.toDouble(),
            ),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios),
        onTap: onTap, // Use the provided onTap callback
      ),
    );
  }
}