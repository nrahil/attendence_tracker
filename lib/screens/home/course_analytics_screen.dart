import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendence_manager/widgets/attendance_progress_bar.dart';

class CourseAnalyticsScreen extends StatelessWidget {
  final String courseId;

  const CourseAnalyticsScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('User not logged in.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Course Analytics'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('courses')
            .doc(courseId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Course data not found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final courseName = data['courseName'] as String? ?? 'N/A';
          final instructorName = data['instructorName'] as String? ?? 'N/A';
          final attendancePercentage = double.tryParse(data['attendancePercentage'] as String? ?? '0') ?? 0;
          final classesHeld = data['classesHeld'] as int? ?? 0;
          final classesMissed = data['classesMissed'] as int? ?? 0;
          
          const double threshold = 75; 

          double classesToAttend = 0;
          double classesToMiss = 0;

          if (attendancePercentage < threshold) {
            classesToAttend = (threshold * classesHeld - attendancePercentage * classesHeld) / (100 - threshold);
          } else {
            classesToMiss = (100 * (classesHeld - classesMissed) - threshold * classesHeld) / threshold;
          }
          
          final classesAttended = classesHeld - classesMissed;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courseName,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Instructor: $instructorName',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 24),
                Text(
                  'Current Attendance: ${attendancePercentage.toStringAsFixed(2)}%',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                AttendanceProgressBar(attendancePercentage: attendancePercentage),
                const SizedBox(height: 24),
                Text(
                  'Classes Attended: $classesAttended',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Classes Missed: $classesMissed',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  'Total Classes Held: $classesHeld',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 24),
                if (attendancePercentage < threshold)
                  Text(
                    'You need to attend ${classesToAttend.ceil()} more classes to reach your target of ${threshold.toInt()}%!',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16),
                  )
                else
                  Text(
                    'You can still miss ${classesToMiss.floor()} classes and stay above ${threshold.toInt()}%!',
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}