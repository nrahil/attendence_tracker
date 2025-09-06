import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendence_manager/widgets/course_card.dart';
import 'package:attendence_manager/screens/settings_screen.dart';
import 'package:attendence_manager/widgets/add_course_dialog.dart';
import 'package:attendence_manager/screens/home/course_details_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      // Handle the case where the user is not logged in.
      // This should ideally not happen if the app's routing is correct.
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
                MaterialPageRoute(builder: (context) => SettingsScreen()),
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
                      final courseData =
                          courseDoc.data() as Map<String, dynamic>;
                      final courseName = courseData['courseName'] as String;
                      final attendancePercentage = double.parse(
                          courseData['attendancePercentage'] as String);

                      return CourseCard(
                        courseName: courseName,
                        currentAttendance: attendancePercentage.toInt(),
                        onTap: () {
        // Navigate to the CourseDetailsScreen, passing the course ID and name
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseDetailsScreen(
              courseId: courseId,
              courseName: courseName,
            ),
          ),
        );
      },
                        onEdit: () {
                          // Pass the course ID and data to the dialog for editing
                          showDialog(
                            context: context,
                            builder: (ctx) => AddEditCourseDialog(
                              courseId: courseId,
                              courseData: courseData,
                            ),
                          );
                        },
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
          // Call the same dialog without any parameters for adding
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
