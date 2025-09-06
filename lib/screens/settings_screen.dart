import 'package:flutter/material.dart';
import 'package:attendence_manager/screens/auth/login_screen.dart';

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: ListView(
        children: [
          // Profile Management
          ListTile(
            leading: Icon(Icons.person),
            title: Text('Account'),
            subtitle: Text('Manage your profile and account details'),
            onTap: () {
              // TODO: Navigate to an Account Management screen
            },
          ),
          Divider(),

          // Notification Settings
          ListTile(
            leading: Icon(Icons.notifications),
            title: Text('Notifications'),
            subtitle: Text('Set reminders and attendance alerts'),
            onTap: () {
              // TODO: Navigate to a Notifications Settings screen
            },
          ),
          Divider(),

          // Holiday Management
          ListTile(
            leading: Icon(Icons.calendar_today),
            title: Text('Manage Holidays'),
            subtitle: Text('Add or view institutional holidays'),
            onTap: () {
              // TODO: Implement a screen to manage holidays
            },
          ),
          Divider(),

          // Attendance Threshold
          ListTile(
            leading: Icon(Icons.percent),
            title: Text('Attendance Threshold'),
            subtitle: Text('Set your target attendance percentage (e.g., 75%)'),
            onTap: () {
              // TODO: Implement a dialog or screen to set the threshold
            },
          ),
          Divider(),

          // Logout
          ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('Logout'),
            onTap: () {
              // Use pushAndRemoveUntil to clear the navigation stack
              // This prevents the user from going back to the dashboard after logging out
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => LoginScreen()),
                (Route<dynamic> route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}