import 'package:flutter/material.dart';

import '../../domain/triage_record.dart';

class SyncStatusBadge extends StatelessWidget {
  final SyncStatus status;
  const SyncStatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    // `iconColor` is the brighter brand hue (fine for a non-text glyph, which
    // only needs 3:1 under WCAG 1.4.11). `textColor` is a darkened variant of
    // the same hue chosen to clear the 4.5:1 AA text-contrast threshold at
    // this label's 12px bold size — plain Colors.orange/blue/green/red read
    // as low as ~2.2:1 on a white card, which fails outright.
    final (IconData icon, Color iconColor, Color textColor, String label, bool spin) =
        switch (status) {
      SyncStatus.pending => (Icons.schedule, Colors.orange,
          const Color(0xFFBF360C), 'Pending sync', false),
      SyncStatus.syncing => (Icons.sync, Colors.blue, Colors.blue.shade900,
          'Syncing…', true),
      SyncStatus.synced => (Icons.cloud_done, Colors.green,
          Colors.green.shade900, 'Synced', false),
      SyncStatus.failed => (Icons.error_outline, Colors.red,
          Colors.red.shade900, 'Failed', false),
    };

    final iconWidget = spin
        ? const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(icon, size: 16, color: iconColor);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget,
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                color: textColor, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
