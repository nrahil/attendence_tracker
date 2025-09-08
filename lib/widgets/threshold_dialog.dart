import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ThresholdDialog extends StatefulWidget {
  const ThresholdDialog({super.key});

  @override
  State<ThresholdDialog> createState() => _ThresholdDialogState();
}

class _ThresholdDialogState extends State<ThresholdDialog> {
  final _formKey = GlobalKey<FormState>();
  int _threshold = 75;

  final firestore = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentThreshold();
  }

  void _loadCurrentThreshold() async {
    if (currentUser != null) {
      final userDoc = await firestore.collection('users').doc(currentUser!.uid).get();
      if (userDoc.exists && userDoc.data()!.containsKey('attendanceThreshold')) {
        setState(() {
          _threshold = userDoc.data()!['attendanceThreshold'] as int;
        });
      }
    }
  }

  void _saveThreshold() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      Navigator.of(context).pop();

      try {
        if (currentUser != null) {
          await firestore.collection('users').doc(currentUser!.uid).set(
            {'attendanceThreshold': _threshold},
            SetOptions(merge: true),
          );
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Threshold saved successfully!')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to save threshold.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Set Attendance Threshold'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: _threshold.toString(),
              decoration: const InputDecoration(labelText: 'Threshold (%)'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || int.tryParse(value) == null || int.tryParse(value)! < 0 || int.tryParse(value)! > 100) {
                  return 'Enter a number between 0 and 100.';
                }
                return null;
              },
              onSaved: (value) => _threshold = int.parse(value!),
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
          onPressed: _saveThreshold,
          child: const Text('Save'),
        ),
      ],
    );
  }
}