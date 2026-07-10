import 'package:flutter/material.dart';

import '../../domain/triage_record.dart';

class SyncStatusBadge extends StatelessWidget {
  final SyncStatus status;
  const SyncStatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String label, bool spin) =
        switch (status) {
      SyncStatus.pending => (Icons.schedule, Colors.orange, 'Pending sync', false),
      SyncStatus.syncing => (Icons.sync, Colors.blue, 'Syncing…', true),
      SyncStatus.synced => (Icons.cloud_done, Colors.green, 'Synced', false),
      SyncStatus.failed => (Icons.error_outline, Colors.red, 'Failed', false),
    };

    final iconWidget = spin
        ? const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon, size: 16, color: color);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget,
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
