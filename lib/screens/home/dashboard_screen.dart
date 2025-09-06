import 'package:flutter/material.dart';
import 'package:attendence_manager/widgets/course_card.dart';
import 'package:attendence_manager/screens/settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Attendance'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overall Attendance: 80%', // Replace with dynamic data
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'Your Courses',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: [
                  CourseCard(
                    courseName: 'Data Structures',
                    currentAttendance: 85,
                    totalClasses: 40,
                    onTap: () {
                      // TODO: Navigate to Course Details screen with data
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (context) => CourseDetailsScreen(courseId: 'DS101'),
                      //   ),
                      // );
                    },
                  ),
                  CourseCard(
                    courseName: 'Operating Systems',
                    currentAttendance: 72,
                    totalClasses: 35,
                    onTap: () {},
                  ),
                  CourseCard(
                    courseName: 'Software Engineering',
                    currentAttendance: 90,
                    totalClasses: 30,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Add a new course
        },
        child: Icon(Icons.add),
      ),
    );
  }
}