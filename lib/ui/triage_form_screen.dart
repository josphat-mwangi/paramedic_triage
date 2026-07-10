import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/triage_record.dart';
import '../domain/triage_validator.dart';
import '../state/triage_providers.dart';
import 'theme/app_theme.dart';
import 'widgets/priority_selector.dart';

class TriageFormScreen extends ConsumerStatefulWidget {
  const TriageFormScreen({super.key});

  @override
  ConsumerState<TriageFormScreen> createState() => _TriageFormScreenState();
}

class _TriageFormScreenState extends ConsumerState<TriageFormScreen> {
  final _nameCtrl = TextEditingController();
  final _conditionCtrl = TextEditingController();
  int? _priority;
  TriageStatus _status = TriageStatus.pending;
  TriageValidationResult _errors = const TriageValidationResult();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _conditionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final result = TriageValidator.validate(
      patientName: _nameCtrl.text,
      conditionDescription: _conditionCtrl.text,
      priority: _priority,
    );
    setState(() => _errors = result);
    if (!result.isValid) return;

    await ref.read(triageNotifierProvider.notifier).submit(
          patientName: _nameCtrl.text,
          conditionDescription: _conditionCtrl.text,
          priority: _priority!,
          status: _status,
        );

    // Ask what's actually true right now rather than reciting the same line
    // regardless of connectivity — a record captured while online starts
    // uploading immediately, so telling the paramedic to wait for "online"
    // would be both wrong and needlessly worrying.
    final online = await ref.read(syncEngineProvider).isOnline;

    if (!mounted) return;
    _nameCtrl.clear();
    _conditionCtrl.clear();
    setState(() {
      _priority = null;
      _status = TriageStatus.pending;
      _errors = const TriageValidationResult();
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: Duration(seconds: online ? 3 : 5),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle, color: AppTheme.teal, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Triage record saved',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    online
                        ? 'Syncing to the server now.'
                        : "Safely stored on this device. It'll sync "
                            "automatically the moment you're back online — "
                            "nothing else to do.",
                    style: const TextStyle(fontSize: 12.5, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New triage record', style: textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Every field below saves to this device instantly.',
              style: textTheme.bodyMedium),
          const SizedBox(height: 24),
          Text('Patient name', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'e.g. Jane Doe',
              errorText: _errors.patientName,
            ),
          ),
          const SizedBox(height: 20),
          Text('Condition description', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _conditionCtrl,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'What do you see — mechanism, symptoms, vitals…',
              errorText: _errors.conditionDescription,
            ),
          ),
          const SizedBox(height: 24),
          PrioritySelector(
            selected: _priority,
            onChanged: (p) => setState(() => _priority = p),
            errorText: _errors.priority,
          ),
          const SizedBox(height: 24),
          Text('Status', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<TriageStatus>(
            segments: const [
              ButtonSegment(
                  value: TriageStatus.pending, label: Text('Pending')),
              ButtonSegment(
                  value: TriageStatus.inTransit, label: Text('In-Transit')),
            ],
            selected: {_status},
            onSelectionChanged: (s) => setState(() => _status = s.first),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
            ),
            child: const Text('Submit triage'),
          ),
        ],
      ),
    );
  }
}
