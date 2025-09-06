import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendence_manager/widgets/attendance_progress_bar.dart';

class CourseDetailsScreen extends StatefulWidget {
  final String courseId;
  final String courseName;

  const CourseDetailsScreen({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<CourseDetailsScreen> createState() => _CourseDetailsScreenState();
}

class _CourseDetailsScreenState extends State<CourseDetailsScreen> {
  final firestore = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _updateAttendance(bool attended) async {
    final courseDocRef = firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('courses')
        .doc(widget.courseId);

    return firestore.runTransaction((transaction) async {
      final docSnapshot = await transaction.get(courseDocRef);
      if (!docSnapshot.exists) {
        throw Exception("Course does not exist!");
      }

      final data = docSnapshot.data() as Map<String, dynamic>;
      int classesHeld = data['classesHeld'] as int;
      int classesMissed = data['classesMissed'] as int;
      
      classesHeld += 1;
      if (!attended) {
        classesMissed += 1;
      }
      
      final attendancePercentage = ((classesHeld - classesMissed) / classesHeld) * 100;

      transaction.update(courseDocRef, {
        'classesHeld': classesHeld,
        'classesMissed': classesMissed,
        'attendancePercentage': attendancePercentage.toStringAsFixed(2),
        'lastUpdated': Timestamp.now(),
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseName),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: firestore
            .collection('users')
            .doc(currentUser!.uid)
            .collection('courses')
            .doc(widget.courseId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Course not found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final attendancePercentage = double.parse(data['attendancePercentage'] as String);
          final classesHeld = data['classesHeld'] as int;
          final classesMissed = data['classesMissed'] as int;
          final classesAttended = classesHeld - classesMissed;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Text(
                  'Current Attendance: ${attendancePercentage.toStringAsFixed(2)}%',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                AttendanceProgressBar(attendancePercentage: attendancePercentage),
                const SizedBox(height: 20),
                Text(
                  'Attended: $classesAttended / $classesHeld',
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  'Missed: $classesMissed',
                  style: const TextStyle(fontSize: 16),
                ),
                const Divider(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton(
                      onPressed: () => _updateAttendance(true),
                      child: const Text('Attended'),
                    ),
                    ElevatedButton(
                      onPressed: () => _updateAttendance(false),
                      child: const Text('Missed'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}