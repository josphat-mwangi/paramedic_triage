import 'package:flutter/material.dart';

import '../../domain/triage_record.dart';
import '../theme/app_theme.dart';
import '../theme/hazard_colors.dart';
import 'sync_status_badge.dart';

class RecordTile extends StatelessWidget {
  final TriageRecord record;
  const RecordTile(this.record, {super.key});

  @override
  Widget build(BuildContext context) {
    final critical = HazardColors.isCritical(record.priority);
    final hazard = HazardColors.background(record.priority);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: critical
            ? BorderSide(color: hazard, width: 2)
            : const BorderSide(color: AppTheme.hairline),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Severity strip — lets the queue be scanned by color alone.
            Container(width: 6, color: hazard),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: hazard,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            HazardColors.label(record.priority),
                            style: TextStyle(
                              color: HazardColors.onBackground(record.priority),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.hairline),
                          ),
                          child: Text(
                            record.status.label,
                            style: const TextStyle(
                              color: AppTheme.inkMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(record.patientName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.ink)),
                    const SizedBox(height: 2),
                    Text(record.conditionDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppTheme.inkMuted)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        SyncStatusBadge(record.syncStatus),
                        const Spacer(),
                        if (record.retryCount > 0)
                          Text('retry ${record.retryCount}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.inkMuted)),
                      ],
                    ),
                    if (record.syncStatus == SyncStatus.failed &&
                        record.lastError != null &&
                        record.lastError!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                size: 16, color: Colors.red.shade800),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                record.lastError!,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.red.shade900),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
