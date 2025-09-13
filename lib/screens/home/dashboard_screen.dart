import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:attendence_manager/widgets/course_card.dart';
import 'package:attendence_manager/screens/settings_screen.dart';
import 'package:attendence_manager/widgets/add_edit_course_dialog.dart';
import 'package:attendence_manager/screens/home/course_analytics_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _updateAttendance(BuildContext context, String courseId, bool attended) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    
    final attendanceRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('courses')
        .doc(courseId)
        .collection('attendance_log');

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final docId = today.toString().substring(0, 10); // Use YYYY-MM-DD as document ID

    try {
      await attendanceRef.doc(docId).set({
        'date': today,
        'status': attended ? 'attended' : 'missed',
      });
      
      await _recalculateAttendance(currentUser.uid, courseId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attendance marked as ${attended ? 'attended' : 'missed'}!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update attendance. Please try again.')),
        );
      }
    }
  }

  Future<void> _recalculateAttendance(String userId, String courseId) async {
    final courseDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('courses')
        .doc(courseId);

    final attendanceLogSnapshot = await courseDocRef.collection('attendance_log').get();
    
    int classesHeld = 0;
    int classesMissed = 0;

    for (var doc in attendanceLogSnapshot.docs) {
      final status = doc.data()['status'] as String;
      if (status != 'holiday' && status != 'cancelled') {
        classesHeld++;
        if (status == 'missed') {
          classesMissed++;
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

  void _showEditDialog(BuildContext context, String courseId, Map<String, dynamic> courseData) {
    showDialog(
      context: context,
      builder: (ctx) => AddEditCourseDialog(
        courseId: courseId,
        courseData: courseData,
      ),
    );
  }

  Future<void> _deleteCourse(BuildContext context, String courseId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Course'),
        content: const Text('Are you sure you want to delete this course?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('courses')
            .doc(courseId)
            .delete();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Course deleted successfully!')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete course.')),
          );
        }
      }
    }
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
            final percentageString = data['attendancePercentage'] as String? ?? '0';
            totalPercentage += double.parse(percentageString);
          }

          final overallAttendance = courseDocs.isNotEmpty ? totalPercentage / courseDocs.length : 0;
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
                      final attendancePercentage = double.tryParse(courseData['attendancePercentage'] as String? ?? '0') ?? 0;

                      return CourseCard(
                        courseName: courseName,
                        currentAttendance: attendancePercentage.toInt(),
                        onAttended: () => _updateAttendance(context, courseId, true),
                        onMissed: () => _updateAttendance(context, courseId, false),
                        onDetails: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CourseAnalyticsScreen(
                                courseId: courseId,
                                courseName: courseName, // Pass course name to analytics screen
                              ),
                            ),
                          );
                        },
                        onEdit: () => _showEditDialog(context, courseId, courseData),
                        onDelete: () => _deleteCourse(context, courseId),
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