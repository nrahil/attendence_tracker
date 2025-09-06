import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendence_manager/widgets/course_card.dart';
import 'package:attendence_manager/screens/settings_screen.dart';
import 'package:attendence_manager/widgets/add_edit_course_dialog.dart';
import 'package:attendence_manager/screens/home/course_details_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _updateAttendance(BuildContext context, String courseId, bool attended) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final courseDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('courses')
        .doc(courseId);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
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
        });
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update attendance. Please try again.')),
        );
      }
    }
  }

  // Function to show the edit dialog
  void _showEditDialog(BuildContext context, String courseId, Map<String, dynamic> courseData) {
    showDialog(
      context: context,
      builder: (ctx) => AddEditCourseDialog(
        courseId: courseId,
        courseData: courseData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text('User not logged in.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('courses')
            .snapshots(),
        builder: (ctx, courseSnapshot) {
          if (courseSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!courseSnapshot.hasData || courseSnapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No courses added yet!'));
          }

          final courseDocs = courseSnapshot.data!.docs;
          double totalPercentage = 0;

          for (var doc in courseDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final percentageString = data['attendancePercentage'] as String;
            totalPercentage += double.parse(percentageString);
          }

          final overallAttendance = totalPercentage / courseDocs.length;
          final overallText = courseDocs.isNotEmpty
              ? 'Overall Attendance: ${overallAttendance.toStringAsFixed(2)}%'
              : 'Overall Attendance: 0.00%';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  overallText,
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Your Courses',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: courseDocs.length,
                    itemBuilder: (ctx, index) {
                      final courseDoc = courseDocs[index];
                      final courseId = courseDoc.id;
                      final courseData = courseDoc.data() as Map<String, dynamic>;
                      final courseName = courseData['courseName'] as String;
                      final attendancePercentage = double.parse(
                          courseData['attendancePercentage'] as String);

                      return CourseCard(
                        courseName: courseName,
                        currentAttendance: attendancePercentage.toInt(),
                        onAttended: () => _updateAttendance(context, courseId, true),
                        onMissed: () => _updateAttendance(context, courseId, false),
                        onDetails: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CourseDetailsScreen(
                                courseId: courseId,
                              ),
                            ),
                          );
                        },
                        // Connect the onEdit callback to the new function
                        onEdit: () => _showEditDialog(context, courseId, courseData),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (ctx) => const AddEditCourseDialog(),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}