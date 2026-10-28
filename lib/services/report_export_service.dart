import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/attendance_model.dart';

class AttendanceReportData {
  final String institutionName;
  final String courseName;
  final String academicTerm;
  final List<Map<String, dynamic>> studentStats;
  final List<AuditEntry> auditLogs;
  final double averagePercentage;
  final int totalClasses;

  AttendanceReportData({
    required this.institutionName,
    required this.courseName,
    required this.academicTerm,
    required this.studentStats,
    required this.auditLogs,
    required this.averagePercentage,
    required this.totalClasses,
  });
}

class ReportExportService {
  static final ReportExportService _instance = ReportExportService._internal();
  factory ReportExportService() => _instance;
  ReportExportService._internal();

  /// Generates a standardized accreditation & compliance audit report
  String generateComplianceReport(AttendanceReportData data) {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    final buffer = StringBuffer();
    buffer.writeln('========================================================================');
    buffer.writeln('             INSTITUTIONAL ATTENDANCE & COMPLIANCE AUDIT REPORT         ');
    buffer.writeln('========================================================================');
    buffer.writeln('Institution  : ${data.institutionName}');
    buffer.writeln('Course       : ${data.courseName}');
    buffer.writeln('Academic Term: ${data.academicTerm}');
    buffer.writeln('Report Date  : $now');
    buffer.writeln('Compliance   : FERPA & Institutional Audit Standard Ready');
    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('EXECUTIVE SUMMARY:');
    buffer.writeln('  Total Classes Held      : ${data.totalClasses}');
    buffer.writeln('  Average Attendance Rate : ${data.averagePercentage.toStringAsFixed(1)}%');
    buffer.writeln('  Enrolled Students       : ${data.studentStats.length}');
    buffer.writeln('  Audit Adjustments Count : ${data.auditLogs.length}');
    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('STUDENT ATTENDANCE ROSTER:');
    buffer.writeln(sprintfHeader());
    buffer.writeln('------------------------------------------------------------------------');

    for (final s in data.studentStats) {
      final id = (s['id'] ?? '').toString().padRight(12);
      final name = (s['name'] ?? '').toString().padRight(20);
      final held = (s['held'] ?? 0).toString().padRight(8);
      final attended = (s['attended'] ?? 0).toString().padRight(10);
      final pct = '${(s['percentage'] ?? 0.0).toStringAsFixed(1)}%'.padRight(8);
      final status = (s['status'] ?? 'Good').toString();

      buffer.writeln('$id $name $held $attended $pct $status');
    }

    buffer.writeln('------------------------------------------------------------------------');
    buffer.writeln('IMMUTABLE AUDIT ADJUSTMENTS LOG:');
    if (data.auditLogs.isEmpty) {
      buffer.writeln('  No manual adjustments recorded for this reporting period.');
    } else {
      for (int i = 0; i < data.auditLogs.length; i++) {
        final a = data.auditLogs[i];
        final timeStr = DateFormat('MMM dd, hh:mm a').format(a.timestamp);
        buffer.writeln('  [${i + 1}] $timeStr - Modified by ${a.modifiedByName}: ${a.previousStatus.displayName} -> ${a.newStatus.displayName}');
        buffer.writeln('      Reason: "${a.reason}"');
      }
    }
    buffer.writeln('========================================================================');
    buffer.writeln('                    END OF COMPLIANCE REPORT                            ');
    buffer.writeln('========================================================================');

    return buffer.toString();
  }

  /// Generates CSV format for spreadsheet analysis
  String generateCSV(AttendanceReportData data) {
    final buffer = StringBuffer();
    buffer.writeln('Student ID,Student Name,Classes Held,Attended,Percentage,Status');
    for (final s in data.studentStats) {
      buffer.writeln('${s['id']},"${s['name']}",${s['held']},${s['attended']},${s['percentage']},${s['status']}');
    }
    return buffer.toString();
  }

  /// Triggers device share sheet for compliance export
  Future<void> exportAndShareReport(AttendanceReportData data) async {
    final reportText = generateComplianceReport(data);
    await Share.share(
      reportText,
      subject: 'Attendance Compliance Audit Report — ${data.courseName}',
    );
  }

  static String sprintfHeader() {
    return 'ID           Name                 Classes  Attended   Rate     Status   ';
  }
}
