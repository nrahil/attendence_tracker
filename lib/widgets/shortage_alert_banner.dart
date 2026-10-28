import 'package:flutter/material.dart';
import '../services/attendance_analytics_service.dart';

class ShortageAlertBanner extends StatelessWidget {
  final ShortageAnalysis analysis;
  final VoidCallback? onTapDetails;

  const ShortageAlertBanner({
    super.key,
    required this.analysis,
    this.onTapDetails,
  });

  @override
  Widget build(BuildContext context) {
    if (analysis.totalClasses == 0) {
      return const SizedBox.shrink();
    }

    final isAtRisk = analysis.isAtRisk;
    final primaryColor = isAtRisk ? const Color(0xFFEF4444) : const Color(0xFF10B981);
    final secondaryBg = isAtRisk ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5);
    final borderColor = isAtRisk ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: secondaryBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isAtRisk ? Icons.warning_amber_rounded : Icons.verified_user_outlined,
                  color: primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAtRisk ? 'Shortage Threshold Warning' : 'Attendance on Track',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Current: ${analysis.percentage}% • Required: ${analysis.threshold.toInt()}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTapDetails != null)
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 20),
                  color: primaryColor,
                  onPressed: onTapDetails,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Icon(
                  isAtRisk ? Icons.trending_up : Icons.shield_outlined,
                  size: 18,
                  color: primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    analysis.statusMessage,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isAtRisk ? const Color(0xFFB91C1C) : const Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

