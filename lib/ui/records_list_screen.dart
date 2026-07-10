import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/triage_providers.dart';
import 'theme/app_theme.dart';
import 'widgets/record_tile.dart';

class RecordsListScreen extends ConsumerWidget {
  const RecordsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(triageNotifierProvider);

    if (state.records.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.inbox_outlined, size: 40, color: AppTheme.inkMuted),
              const SizedBox(height: 12),
              Text('No triage records yet',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text('Submitted records will appear here.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        if (state.pendingCount > 0)
          Container(
            width: double.infinity,
            color: AppTheme.teal.withValues(alpha: 0.10),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.cloud_queue, size: 18, color: AppTheme.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${state.pendingCount} record(s) waiting to sync — '
                    'this happens automatically, no action needed.',
                    style: const TextStyle(
                        color: AppTheme.brown, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(syncEngineProvider).syncPending(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: state.records.length,
              itemBuilder: (_, i) => RecordTile(state.records[i]),
            ),
          ),
        ),
      ],
    );
  }
}
