import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddCourseDialog extends StatefulWidget {
  const AddCourseDialog({super.key});

  @override
  State<AddCourseDialog> createState() => _AddCourseDialogState();
}

class _AddCourseDialogState extends State<AddCourseDialog> {
  final _formKey = GlobalKey<FormState>();
  final firestore = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser;

  String _courseName = '';
  int _classesHeld = 0;
  int _classesMissed = 0;
  bool _isSaving = false;

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      double attendancePercentage = 0.0;
      if (_classesHeld > 0) {
        attendancePercentage = ((_classesHeld - _classesMissed) / _classesHeld) * 100;
      }
      
      setState(() {
        _isSaving = true;
      });

      try {
        if (currentUser != null) {
          // Store the data in Firestore under a user-specific collection
          await firestore
              .collection('users')
              .doc(currentUser!.uid)
              .collection('courses')
              .add({
                'courseName': _courseName,
                'attendancePercentage': attendancePercentage.toStringAsFixed(2),
                'classesHeld': _classesHeld,
                'classesMissed': _classesMissed,
                'createdAt': Timestamp.now(), // Helps with sorting
              });
        }
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Course added successfully!')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to add course. Please try again.')),
          );
        }
      } finally {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add New Course'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              decoration: const InputDecoration(labelText: 'Course Name'),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a course name.';
                }
                return null;
              },
              onSaved: (value) {
                _courseName = value!;
              },
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Total classes held'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || int.tryParse(value) == null || int.tryParse(value)! < 0) {
                  return 'Please enter a valid number.';
                }
                return null;
              },
              onSaved: (value) {
                _classesHeld = int.parse(value!);
              },
            ),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Number of classes missed'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || int.tryParse(value) == null || int.tryParse(value)! < 0) {
                  return 'Please enter a valid number.';
                }
                return null;
              },
              onSaved: (value) {
                _classesMissed = int.parse(value!);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        _isSaving
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _submitForm,
                child: const Text('Add Course'),
              ),
      ],
    );
  }
}