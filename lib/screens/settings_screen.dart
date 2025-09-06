import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:attendence_manager/screens/auth/login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _deleteAccount(BuildContext context) async {
    // Show a confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Are you sure you want to delete your account? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          // 1. Delete user's data from Firestore
          final userCourses = FirebaseFirestore.instance.collection('users').doc(currentUser.uid).collection('courses');
          final batch = FirebaseFirestore.instance.batch();
          final snapshots = await userCourses.get();
          for (var doc in snapshots.docs) {
            batch.delete(doc.reference);
          }
          await batch.commit();
          
          // 2. Delete the user's document
          await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).delete();
          
          // 3. Delete the user from Firebase Authentication
          await currentUser.delete();

          // Navigate back to login screen after successful deletion
          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (ctx) => LoginScreen()),
              (Route<dynamic> route) => false,
            );
          }
          
        }
      } on FirebaseAuthException catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.message}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('An unexpected error occurred.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.person, color: Colors.grey),
            title: const Text('Profile'),
            subtitle: const Text('Manage your profile and account details'),
            onTap: () {
              // TODO: Implement a dedicated Profile screen
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications, color: Colors.grey),
            title: const Text('Notifications'),
            subtitle: const Text('Set attendance reminders'),
            onTap: () {
              // TODO: Implement a Notifications settings screen
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.calendar_today, color: Colors.blue),
            title: const Text('Manage Holidays'),
            subtitle: const Text('Add or view institutional holidays'),
            onTap: () {
              // TODO: Implement a screen to manage holidays
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.percent, color: Colors.blue),
            title: const Text('Attendance Threshold'),
            subtitle: const Text('Set your target attendance percentage (e.g., 75%)'),
            onTap: () {
              // TODO: Implement a dialog or screen to set the threshold
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline, color: Colors.blue),
            title: const Text('About'),
            subtitle: const Text('Learn more about this app'),
            onTap: () {
              // TODO: Navigate to an About Us page
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.blue),
            title: const Text('Logout'),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Account'),
            onTap: () => _deleteAccount(context),
          ),
          const Divider(),
        ],
      ),
    );
  }
}