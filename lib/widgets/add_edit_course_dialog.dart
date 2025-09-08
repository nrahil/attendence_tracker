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
  late int _classesHeld;
  late int _classesMissed;

  @override
  void initState() {
    super.initState();
    _courseName = widget.courseData?['courseName'] as String? ?? '';
    _instructorName = widget.courseData?['instructorName'] as String? ?? '';
    _classesHeld = widget.courseData?['classesHeld'] as int? ?? 0;
    _classesMissed = widget.courseData?['classesMissed'] as int? ?? 0;
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      double attendancePercentage = 0.0;
      if (_classesHeld > 0) {
        attendancePercentage = ((_classesHeld - _classesMissed) / _classesHeld) * 100;
      }
      
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
                  'attendancePercentage': attendancePercentage.toStringAsFixed(2),
                  'classesHeld': _classesHeld,
                  'classesMissed': _classesMissed,
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
                  'attendancePercentage': attendancePercentage.toStringAsFixed(2),
                  'classesHeld': _classesHeld,
                  'classesMissed': _classesMissed,
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
            const SizedBox(height: 16), 
            TextFormField(
              initialValue: _classesHeld.toString(),
              decoration: const InputDecoration(labelText: 'Total classes held'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || int.tryParse(value) == null || int.tryParse(value)! < 0) {
                  return 'Please enter a valid number.';
                }
                return null;
              },
              onSaved: (value) => _classesHeld = int.parse(value!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _classesMissed.toString(),
              decoration: const InputDecoration(labelText: 'Number of classes missed'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || int.tryParse(value) == null || int.tryParse(value)! < 0) {
                  return 'Please enter a valid number.';
                }
                return null;
              },
              onSaved: (value) => _classesMissed = int.parse(value!),
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