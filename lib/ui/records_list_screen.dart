import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/triage_providers.dart';
import 'widgets/record_tile.dart';

class RecordsListScreen extends ConsumerWidget {
  const RecordsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(triageNotifierProvider);

    if (state.records.isEmpty) {
      return Center(
        child: Text('No triage records yet',
            style: TextStyle(color: Colors.grey.shade700)),
      );
    }

    return Column(
      children: [
        if (state.pendingCount > 0)
          Container(
            width: double.infinity,
            color: Colors.orange.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.cloud_queue, size: 18, color: Colors.orange.shade900),
                const SizedBox(width: 8),
                // Deep-orange-900 (not shade900 "orange") — checked against
                // the shade50 banner background this clears 4.5:1 AA for
                // normal-weight text; plain orange.shade900 only reaches ~3.5:1.
                Text('${state.pendingCount} record(s) awaiting sync',
                    style: TextStyle(color: Colors.deepOrange.shade900)),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () =>
                ref.read(syncEngineProvider).syncPending(),
            child: ListView.builder(
              itemCount: state.records.length,
              itemBuilder: (_, i) => RecordTile(state.records[i]),
            ),
          ),
        ),
      ],
    );
  }
}
