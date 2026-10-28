enum RiskTier {
  critical,
  moderate,
  low;

  String get displayName {
    switch (this) {
      case RiskTier.critical:
        return 'Critical Risk (<65%)';
      case RiskTier.moderate:
        return 'Moderate Risk (65-74%)';
      case RiskTier.low:
        return 'On Track (≥75%)';
    }
  }
}

class PredictiveStudentProfile {
  final String studentId;
  final String studentName;
  final String courseName;
  final double currentPercentage;
  final double projectedPercentage;
  final RiskTier riskTier;
  final String trendDirection; // 'declining', 'stable', 'improving'
  final String recommendedAction;

  PredictiveStudentProfile({
    required this.studentId,
    required this.studentName,
    required this.courseName,
    required this.currentPercentage,
    required this.projectedPercentage,
    required this.riskTier,
    required this.trendDirection,
    required this.recommendedAction,
  });
}

class PredictiveAnalyticsService {
  /// Evaluates attendance trajectory using moving window velocity
  static PredictiveStudentProfile evaluateStudentRisk({
    required String studentId,
    required String studentName,
    required String courseName,
    required int totalClassesCompleted,
    required int totalClassesAttended,
    required int totalTermClasses, // e.g. 40 total classes in semester
    required List<bool> recent4WeekAttendance, // true = attended, false = missed
  }) {
    if (totalClassesCompleted <= 0) {
      return PredictiveStudentProfile(
        studentId: studentId,
        studentName: studentName,
        courseName: courseName,
        currentPercentage: 100.0,
        projectedPercentage: 100.0,
        riskTier: RiskTier.low,
        trendDirection: 'stable',
        recommendedAction: 'Maintain current cadence',
      );
    }

    final currentPct = (totalClassesAttended / totalClassesCompleted) * 100.0;

    // Calculate recent velocity (last 4 sessions)
    double recentVelocityRatio = 1.0;
    if (recent4WeekAttendance.isNotEmpty) {
      final recentAttended = recent4WeekAttendance.where((a) => a).length;
      recentVelocityRatio = recentAttended / recent4WeekAttendance.length;
    }

    final remainingClasses = totalTermClasses > totalClassesCompleted
        ? totalTermClasses - totalClassesCompleted
        : 0;

    // Projected attended = currentAttended + (remaining * recentVelocity)
    final projectedAttended = totalClassesAttended + (remainingClasses * recentVelocityRatio);
    final projectedPct = totalTermClasses > 0
        ? (projectedAttended / totalTermClasses) * 100.0
        : currentPct;

    RiskTier tier;
    String recommendation;

    if (projectedPct < 65.0) {
      tier = RiskTier.critical;
      recommendation = '🚨 Deploy Academic Counselor: Severe dropout or exam disqualification risk.';
    } else if (projectedPct < 75.0) {
      tier = RiskTier.moderate;
      recommendation = '⚠️ Trigger Automated Parent Alert & Schedule Academic Check-in.';
    } else {
      tier = RiskTier.low;
      recommendation = '✅ On track for institutional accreditation standard.';
    }

    String direction = 'stable';
    if (recentVelocityRatio < (currentPct / 100.0) - 0.05) {
      direction = 'declining';
    } else if (recentVelocityRatio > (currentPct / 100.0) + 0.05) {
      direction = 'improving';
    }

    return PredictiveStudentProfile(
      studentId: studentId,
      studentName: studentName,
      courseName: courseName,
      currentPercentage: double.parse(currentPct.toStringAsFixed(1)),
      projectedPercentage: double.parse(projectedPct.toStringAsFixed(1)),
      riskTier: tier,
      trendDirection: direction,
      recommendedAction: recommendation,
    );
  }

  /// Campus sample dataset for predictive admin visualization
  static List<PredictiveStudentProfile> getSampleAtRiskCohort() {
    return [
      evaluateStudentRisk(
        studentId: 'student_4',
        studentName: 'Devansh Patel',
        courseName: 'CS-301: Algorithms',
        totalClassesCompleted: 20,
        totalClassesAttended: 12,
        totalTermClasses: 36,
        recent4WeekAttendance: [false, false, true, false],
      ),
      evaluateStudentRisk(
        studentId: 'student_7',
        studentName: 'Rohan Sen',
        courseName: 'CS-303: Operating Systems',
        totalClassesCompleted: 22,
        totalClassesAttended: 15,
        totalTermClasses: 36,
        recent4WeekAttendance: [true, false, false, true],
      ),
      evaluateStudentRisk(
        studentId: 'student_5',
        studentName: 'Ishaan Gupta',
        courseName: 'CS-302: DBMS',
        totalClassesCompleted: 18,
        totalClassesAttended: 13,
        totalTermClasses: 36,
        recent4WeekAttendance: [true, true, false, true],
      ),
    ];
  }
}

