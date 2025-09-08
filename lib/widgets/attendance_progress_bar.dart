import 'package:flutter/material.dart';

class AttendanceProgressBar extends StatelessWidget {
  final double attendancePercentage;

  const AttendanceProgressBar({super.key, required this.attendancePercentage});

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: attendancePercentage / 100,
      backgroundColor: Colors.grey[200],
      color: attendancePercentage >= 75 ? Colors.green : Colors.red,
    );
  }
}