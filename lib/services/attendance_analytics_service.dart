import '../models/attendance_model.dart';

class ShortageAnalysis {
  final double percentage;
  final bool isAtRisk;
  final double threshold;
  final int totalClasses;
  final int attendedClasses;
  final int lateCount;
  final int missedCount;
  final int excusedCount;
  final int classesNeededForThreshold;
  final int safeBunks;

  ShortageAnalysis({
    required this.percentage,
    required this.isAtRisk,
    required this.threshold,
    required this.totalClasses,
    required this.attendedClasses,
    required this.lateCount,
    required this.missedCount,
    required this.excusedCount,
    required this.classesNeededForThreshold,
    required this.safeBunks,
  });

  String get statusMessage {
    if (totalClasses == 0) return 'No attendance records yet.';
    if (isAtRisk) {
      if (classesNeededForThreshold == 1) {
        return 'Attendance shortage! Attend the next class to reach ${threshold.toInt()}%.';
      }
      return 'Attendance shortage! Attend next $classesNeededForThreshold classes to reach ${threshold.toInt()}%.';
    } else {
      if (safeBunks == 0) {
        return 'On the edge! Missing the next class will put you below ${threshold.toInt()}%.';
      } else if (safeBunks == 1) {
        return 'Good standing! You can safely miss 1 more class.';
      } else {
        return 'Great standing! You can safely miss up to $safeBunks classes.';
      }
    }
  }
}

class AttendanceAnalyticsService {
  static const double defaultThreshold = 75.0;

  /// Calculate shortage analysis from a list of AttendanceRecords
  static ShortageAnalysis calculateShortage({
    required List<AttendanceRecord> records,
    double threshold = defaultThreshold,
  }) {
    if (records.isEmpty) {
      return ShortageAnalysis(
        percentage: 100.0,
        isAtRisk: false,
        threshold: threshold,
        totalClasses: 0,
        attendedClasses: 0,
        lateCount: 0,
        missedCount: 0,
        excusedCount: 0,
        classesNeededForThreshold: 0,
        safeBunks: 0,
      );
    }

    int totalEffectiveClasses = 0;
    int attended = 0;
    int lateCount = 0;
    int missedCount = 0;
    int excusedCount = 0;

    for (final r in records) {
      switch (r.status) {
        case AttendanceStatus.present:
          attended++;
          totalEffectiveClasses++;
          break;
        case AttendanceStatus.late:
          // Late counts as attended with a tardy flag
          attended++;
          lateCount++;
          totalEffectiveClasses++;
          break;
        case AttendanceStatus.absent:
          missedCount++;
          totalEffectiveClasses++;
          break;
        case AttendanceStatus.excused:
          // Excused absences do not penalize the student's denominator
          excusedCount++;
          break;
      }
    }

    if (totalEffectiveClasses <= 0) {
      return ShortageAnalysis(
        percentage: 100.0,
        isAtRisk: false,
        threshold: threshold,
        totalClasses: records.length,
        attendedClasses: attended,
        lateCount: lateCount,
        missedCount: missedCount,
        excusedCount: excusedCount,
        classesNeededForThreshold: 0,
        safeBunks: 0,
      );
    }

    final percentage = (attended / totalEffectiveClasses) * 100.0;
    final isAtRisk = percentage < threshold;

    int needed = 0;
    int safeBunks = 0;

    final targetRatio = threshold / 100.0;

    if (isAtRisk) {
      // Equation: (attended + x) / (total + x) >= targetRatio
      // attended + x >= targetRatio * total + targetRatio * x
      // x * (1 - targetRatio) >= targetRatio * total - attended
      final numerator = (targetRatio * totalEffectiveClasses) - attended;
      final denominator = 1.0 - targetRatio;
      if (denominator > 0) {
        needed = (numerator / denominator).ceil();
        if (needed < 0) needed = 0;
      }
    } else {
      // Equation: attended / (total + y) >= targetRatio
      // attended >= targetRatio * (total + y)
      // attended / targetRatio >= total + y
      // y <= (attended / targetRatio) - total
      if (targetRatio > 0) {
        final maxTotalAllowed = attended / targetRatio;
        safeBunks = (maxTotalAllowed - totalEffectiveClasses).floor();
        if (safeBunks < 0) safeBunks = 0;
      }
    }

    return ShortageAnalysis(
      percentage: double.parse(percentage.toStringAsFixed(1)),
      isAtRisk: isAtRisk,
      threshold: threshold,
      totalClasses: totalEffectiveClasses,
      attendedClasses: attended,
      lateCount: lateCount,
      missedCount: missedCount,
      excusedCount: excusedCount,
      classesNeededForThreshold: needed,
      safeBunks: safeBunks,
    );
  }

  /// Calculates shortage directly from held & missed integers
  static ShortageAnalysis calculateFromCounts({
    required int classesHeld,
    required int classesMissed,
    double threshold = defaultThreshold,
  }) {
    if (classesHeld <= 0) {
      return ShortageAnalysis(
        percentage: 100.0,
        isAtRisk: false,
        threshold: threshold,
        totalClasses: 0,
        attendedClasses: 0,
        lateCount: 0,
        missedCount: 0,
        excusedCount: 0,
        classesNeededForThreshold: 0,
        safeBunks: 0,
      );
    }

    final attended = classesHeld - classesMissed;
    final percentage = (attended / classesHeld) * 100.0;
    final isAtRisk = percentage < threshold;
    final targetRatio = threshold / 100.0;

    int needed = 0;
    int safeBunks = 0;

    if (isAtRisk) {
      final numerator = (targetRatio * classesHeld) - attended;
      final denominator = 1.0 - targetRatio;
      if (denominator > 0) {
        needed = (numerator / denominator).ceil();
        if (needed < 0) needed = 0;
      }
    } else {
      if (targetRatio > 0) {
        final maxTotal = attended / targetRatio;
        safeBunks = (maxTotal - classesHeld).floor();
        if (safeBunks < 0) safeBunks = 0;
      }
    }

    return ShortageAnalysis(
      percentage: double.parse(percentage.toStringAsFixed(1)),
      isAtRisk: isAtRisk,
      threshold: threshold,
      totalClasses: classesHeld,
      attendedClasses: attended,
      lateCount: 0,
      missedCount: classesMissed,
      excusedCount: 0,
      classesNeededForThreshold: needed,
      safeBunks: safeBunks,
    );
  }
}

