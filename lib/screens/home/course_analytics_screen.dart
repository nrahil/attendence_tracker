import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:attendence_manager/widgets/attendance_progress_bar.dart';

class CourseAnalyticsScreen extends StatefulWidget {
  final String courseId;
  final String courseName;

  const CourseAnalyticsScreen({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  @override
  State<CourseAnalyticsScreen> createState() => _CourseAnalyticsScreenState();
}

class _CourseAnalyticsScreenState extends State<CourseAnalyticsScreen> {
  final firestore = FirebaseFirestore.instance;
  final currentUser = FirebaseAuth.instance.currentUser;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
    }
    _showUpdateAttendanceDialog(selectedDay);
  }

  Future<void> _showUpdateAttendanceDialog(DateTime date) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update for ${DateFormat('dd-MM-yyyy').format(date)}'),
        content: const Text('Choose attendance status:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('attended'),
            child: const Text('Attended'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('missed'),
            child: const Text('Missed'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('holiday'),
            child: const Text('Holiday'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('cancelled'),
            child: const Text('Cancelled'),
          ),
        ],
      ),
    );

    if (result != null) {
      if (result == 'attended' || result == 'missed') {
        _showNumberInputDialog(date, result);
      } else {
        await _updateAttendanceLog(date, result, 0);
      }
    }
  }
final TextEditingController _preDefined = TextEditingController(text: "1");
  Future<void> _showNumberInputDialog(DateTime date, String status) async {
    int count = 1;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Number of classes $status:'),
        content: TextField(
          keyboardType: TextInputType.number,
          controller: _preDefined,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Enter number of classes'),
          onChanged: (value) {
            count = int.tryParse(value) ?? 1;
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _updateAttendanceLog(date, status, count);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateAttendanceLog(DateTime date, String status, int count) async {
    final docId = DateFormat('yyyy-MM-dd').format(date);
    final docRef = firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('courses')
        .doc(widget.courseId)
        .collection('attendance_log')
        .doc(docId);

    try {
      await docRef.set({
        'date': date,
        'status': status,
        'count': count,
      });

      await _recalculateAttendance(currentUser!.uid, widget.courseId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attendance for $docId updated to $status.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update attendance.')),
        );
      }
    }
  }

  Future<void> _recalculateAttendance(String userId, String courseId) async {
    final courseDocRef =
        firestore.collection('users').doc(userId).collection('courses').doc(courseId);
    final attendanceLogSnapshot =
        await courseDocRef.collection('attendance_log').get();

    int classesHeld = 0;
    int classesMissed = 0;

    for (var doc in attendanceLogSnapshot.docs) {
      final status = doc.data()['status'] as String;
      final count = doc.data()['count'] as int? ?? 1;

      if (status != 'holiday' && status != 'cancelled') {
        classesHeld += count;
        if (status == 'missed') {
          classesMissed += count;
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

  Color _getMarkerColor(String status) {
    switch (status) {
      case 'attended':
        return Colors.green;
      case 'missed':
        return Colors.red;
      case 'holiday':
        return Colors.orange;
      case 'cancelled':
        return Colors.blueGrey;
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.courseName),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: firestore
            .collection('users')
            .doc(currentUser!.uid)
            .collection('courses')
            .doc(widget.courseId)
            .snapshots(),
        builder: (context, courseSnapshot) {
          if (courseSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!courseSnapshot.hasData || !courseSnapshot.data!.exists) {
            return const Center(child: Text('Course data not found.'));
          }

          final courseData = courseSnapshot.data!.data() as Map<String, dynamic>;
          final attendancePercentage =
              double.tryParse(courseData['attendancePercentage'] as String? ?? '0') ??
                  0;
          final classesHeld = courseData['classesHeld'] as int? ?? 0;
          final classesMissed = courseData['classesMissed'] as int? ?? 0;
          final classesAttended = classesHeld - classesMissed;
          final instructorName = courseData['instructorName'] as String? ?? 'N/A';

          const double threshold = 75;

          double classesToAttend = 0;
          double classesToMiss = 0;

          if (attendancePercentage < threshold) {
            classesToAttend =
                (threshold * classesHeld - attendancePercentage * classesHeld) /
                    (100 - threshold);
          } else {
            classesToMiss =
                (100 * (classesHeld - classesMissed) - threshold * classesHeld) /
                    threshold;
          }

          return StreamBuilder<QuerySnapshot>(
            stream: firestore
                .collection('users')
                .doc(currentUser!.uid)
                .collection('courses')
                .doc(widget.courseId)
                .collection('attendance_log')
                .snapshots(),
            builder: (context, attendanceSnapshot) {
              if (attendanceSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              Map<String, String> attendanceHistory = {};
              Map<String, int> attendanceCountHistory = {};
              if (attendanceSnapshot.hasData) {
                for (var doc in attendanceSnapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final date = (data['date'] as Timestamp).toDate();
                  final key = DateFormat('yyyy-MM-dd').format(date);
                  attendanceHistory[key] = data['status'] as String;
                  attendanceCountHistory[key] = data['count'] as int? ?? 1;
                }
              }

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        instructorName != 'N/A'
                            ? 'Instructor: $instructorName'
                            : 'Instructor: N/A',
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Current Attendance: ${attendancePercentage.toStringAsFixed(2)}%',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      AttendanceProgressBar(
                          attendancePercentage: attendancePercentage),
                      const SizedBox(height: 24),
                      TableCalendar(
                        firstDay: DateTime.utc(2020, 1, 1),
                        lastDay: DateTime.now(),
                        focusedDay: _focusedDay,
                        calendarFormat: _calendarFormat,
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        onDaySelected: _onDaySelected,
                        onFormatChanged: (format) {
                          setState(() {
                            _calendarFormat = format;
                          });
                        },
                        onPageChanged: (focusedDay) {
                          _focusedDay = focusedDay;
                        },
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, focusedDay) {
                            final key = DateFormat('yyyy-MM-dd').format(day);
                            final status = attendanceHistory[key];

                            bool isWeekend = day.weekday == DateTime.saturday ||
                                day.weekday == DateTime.sunday;

                            if (status != null) {
                              return Container(
                                margin: const EdgeInsets.all(4.0),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _getMarkerColor(status),
                                  shape: BoxShape.circle,

                                ),
                                child: Text(
                                  '${day.day}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            } else if (isWeekend) {
                              return Center(
                                child: Text(
                                  '${day.day}',
                                  style: const TextStyle(
                                      color: Colors.blueGrey,
                                      fontStyle: FontStyle.italic),
                                ),
                              );
                            }
                            return null;
                          },
                          todayBuilder: (context, day, focusedDay) {
                            final key = DateFormat('yyyy-MM-dd').format(day);
                            final status = attendanceHistory[key];
                            final isSelected = isSameDay(day, _selectedDay);

                            if (status != null) {
                              return Container(
                                margin: const EdgeInsets.all(4.0),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _getMarkerColor(status),
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(
                                          color: Theme.of(context).primaryColor,
                                          width: 2)
                                      : null,
                                ),
                                child: Text(
                                  '${day.day}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              );
                            } else if (isSelected) {
                              return Center(
                                child: Text(
                                  '${day.day}',
                                  style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.bold),
                                ),
                              );
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Classes Attended: $classesAttended',
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Classes Missed: $classesMissed',
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total Classes Held: $classesHeld',
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 24),
                      if (attendancePercentage < threshold)
                        Text(
                          'You need to attend ${classesToAttend.ceil()} more classes to reach your target of ${threshold.toInt()}%!',
                          style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        )
                      else
                        Text(
                          'You can still miss ${classesToMiss.floor()} classes and stay above ${threshold.toInt()}%!',
                          style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}