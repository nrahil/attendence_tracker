import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddEditCourseDialog extends StatefulWidget {
  final String? courseId;
  final Map<String, dynamic>? courseData;

  const AddEditCourseDialog({
    super.key,
    this.courseId,
    this.courseData,
  });

  @override
  State<AddEditCourseDialog> createState() => _AddEditCourseDialogState();
}

class _AddEditCourseDialogState extends State<AddEditCourseDialog> {
  final _formKey = GlobalKey<FormState>();
  final firestore = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser;

  late String _courseName;
  late String _instructorName;


  @override
  void initState() {
    super.initState();
    _courseName = widget.courseData?['courseName'] as String? ?? '';
    _instructorName = widget.courseData?['instructorName'] as String? ?? '';
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.courseId == null ? 'Adding course...' : 'Updating course...')),
      );

      try {
        if (currentUser != null) {
          if (widget.courseId == null) {
            await firestore
                .collection('users')
                .doc(currentUser!.uid)
                .collection('courses')
                .add({
                  'courseName': _courseName,
                  'instructorName': _instructorName,
                  'attendancePercentage': '0.0', // Initial attendance is 0
                  'classesHeld': 0, // Initial classes are 0
                  'classesMissed': 0, // Initial classes are 0
                  'createdAt': Timestamp.now(),
                });
          } else {
            await firestore
                .collection('users')
                .doc(currentUser!.uid)
                .collection('courses')
                .doc(widget.courseId)
                .update({
                  'courseName': _courseName,
                  'instructorName': _instructorName,
                  'lastUpdated': Timestamp.now(),
                });
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.courseId == null ? 'Course added successfully!' : 'Course updated successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action failed. Please try again.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.courseId != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Course' : 'Add New Course'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: _courseName,
              decoration: const InputDecoration(labelText: 'Course Name'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a course name.';
                }
                return null;
              },
              onSaved: (value) => _courseName = value!,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _instructorName,
              decoration: const InputDecoration(labelText: 'Instructor Name'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter the instructor\'s name.';
                }
                return null;
              },
              onSaved: (value) => _instructorName = value!,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitForm,
          child: Text(isEditing ? 'Save Changes' : 'Add Course'),
        ),
      ],
    );
  }
}